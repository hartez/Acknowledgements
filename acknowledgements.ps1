if($args.length -lt 3)
{
	Write-Host "Usage: acknowledgements [path to packages.config] [path to template] [output path]"
	exit
}

$packagesConfigFile = $args[0]
$templateFile = $args[1]
$outputFile = $args[2]

function getNugetData ($package) {
		
	Write-Host ("Retrieving data for package '{0}'" -f $package.id)
	
	$packageUrl = ("http://nuget.org/api/v2/Packages(Id='{0}',Version='{1}')" -f $package.id, $package.version)
	
	$request = [System.Net.WebRequest]::Create($packageUrl)
	
	try {
		$response = $request.GetResponse()
		$reqstream = $response.GetResponseStream()
		$sr = new-object System.IO.StreamReader $reqstream
		$result = $sr.ReadToEnd()
		
		[xml]$packageData = $result
		
		$result = New-Object -TypeName PSObject
		
		# LicenseUrl, ProjectUrl, Description, and Author are not required, so we want empty strings (instead of XmlElement) if they aren't available
		$licenseUrl = if ($packageData.entry.properties.LicenseUrl.null -eq $true) {""} else {$packageData.entry.properties.LicenseUrl}
		$projectUrl = if ($packageData.entry.properties.ProjectUrl.null -eq $true) {""} else {$packageData.entry.properties.ProjectUrl}
		$description = if ($packageData.entry.properties.Description.null -eq $true) {""} else {$packageData.entry.properties.Description}
		$author = if ($packageData.entry.author.name.null -eq $true) {""} else {$packageData.entry.author.name}
		
		$result | 
			Add-Member -MemberType NoteProperty -Name LicenseUrl -Value $licenseUrl -PassThru |
			Add-Member -MemberType NoteProperty -Name ProjectUrl -Value $projectUrl -PassThru |
			Add-Member -MemberType NoteProperty -Name Id -Value $package.id -PassThru |
			Add-Member -MemberType NoteProperty -Name Version -Value $package.version -PassThru |
			Add-Member -MemberType NoteProperty -Name Description -Value $description -PassThru |
			Add-Member -MemberType NoteProperty -Name Author -Value $author -PassThru
		}
	catch [System.Exception]{
		Write-Host $_.Exception.Message 
		Write-Host "You may have to handle this package manually."
	}
}

function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

function Get-FrameworkDirectory()
{
    $([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
}

[xml]$packagesConfig = (Get-Content $packagesConfigFile)

$packages = @($packagesConfig.packages.package | % {getNugetData $_})

$razorAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
                ? { $_.FullName -match "^System.Web.Razor" }
    
If ($razorAssembly -eq $null) {
	
	$razorSearchPath = Join-Path `
		-Path (Get-ScriptDirectory) `
		-ChildPath packages\Microsoft.AspNet.Razor.*\lib\net40\System.Web.Razor.dll
		
	$razorPath = Get-ChildItem -Path $razorSearchPath |
		Select-Object -First 1 -ExpandProperty FullName
	
	If ($razorPath -eq $null) {
		
		# Attempt to get the Razor libraries from nuget
		$packageDestination = ([string](Get-ScriptDirectory) + "\packages")
		if(!(Test-Path $packageDestination))
		{
			mkdir $packageDestination
		}
		
		nuget install Microsoft.AspNet.Razor /OutputDirectory $packageDestination
	}
	
	If ($razorPath -ne $null) {
		Add-Type -Path $razorPath
	} Else {            
		throw "The System.Web.Razor assembly must be loaded."
	}
}

$templateClassName = "t{0}" -f 
            ([System.IO.Path]::GetRandomFileName() -replace "\.", "")
$templateBaseClassName = "t{0}" -f 
            ([System.IO.Path]::GetRandomFileName() -replace "\.", "")
			
$language = New-Object `
     -TypeName System.Web.Razor.CSharpRazorCodeLanguage
$engineHost = New-Object `
    -TypeName System.Web.Razor.RazorEngineHost `
    -ArgumentList $language `
    -Property @{
        DefaultBaseClass = $templateBaseClassName;
        DefaultClassName = $templateClassName;
        DefaultNamespace = "Templates";
    }
$engine = New-Object `
    -TypeName System.Web.Razor.RazorTemplateEngine `
    -ArgumentList $engineHost
	
[string]$template = Get-Content $templateFile

$templateReader = New-Object `
    -TypeName System.IO.StringReader `
    -ArgumentList $template

$code = $engine.GenerateCode($templateReader)

$codeWriter = New-Object -TypeName System.IO.StringWriter
$compiler = New-Object `
    -TypeName Microsoft.CSharp.CSharpCodeProvider
$compiler.GenerateCodeFromCompileUnit(
    $code.GeneratedCode, $codeWriter, $null
)
$templateCode = $codeWriter.ToString()

$templateBaseCode = @"
using System;
using System.Text;
using Microsoft.CSharp;
using Microsoft.CSharp.RuntimeBinder;

namespace Templates 
{{
	public abstract class {0} 
	{{
		protected dynamic Model;
        private StringBuilder _sb = new StringBuilder();
        public abstract void Execute();
        public virtual void Write(object value)
        {{
            WriteLiteral(value);
        }}
        public virtual void WriteLiteral(object value)
        {{
            _sb.Append(value);
        }}
        public string Render (dynamic model)
        {{
            Model = model;
            Execute();
            return _sb.ToString();
        }}
		
		public virtual void WriteAttribute(string name, Tuple<string, int> startTag, Tuple<string, int> endTag, params object[] values)
		{{
			StringBuilder sb = new StringBuilder();
		 
			sb.Append(startTag.Item1);
		 
			Type[] types = new[] {{ typeof(object), typeof(string), typeof(decimal), typeof(bool), typeof(char), typeof(byte), typeof(sbyte), typeof(short), typeof(int), typeof(long), typeof(ushort), typeof(uint), typeof(ulong), typeof(float), typeof(double) }};
		 
			// All values must be of type:
			// Tuple<Tuple<string, int>, Tuple<______, int>, bool>
			//       ----- TupleA -----  ----- TupleB -----  bool
		 
			Type genTuple = typeof(Tuple<,>);
			Type genTriple = typeof(Tuple<,,>);
		 
			Type tupleA = genTuple.MakeGenericType(typeof(string), typeof(int));
		 
			foreach (var value in values)
			{{
				// Find the type of this value
				foreach (Type type in types)
				{{
					Type tupleB = genTuple.MakeGenericType(type, typeof(int));
					Type nonGen = genTriple.MakeGenericType(tupleA, tupleB, typeof(bool));
		 
					// Check if value is this type
					if (!nonGen.IsInstanceOfType(value)) 
						continue;
		 
					// Found
					// Convert it to this
					dynamic typedObject = Convert.ChangeType(value, nonGen);
		 
					if (typedObject == null) 
						continue;
		 
					sb.Append(WriteAttribute(typedObject));
					break;
				}}
			}}
		 
			sb.Append(endTag.Item1);
		 
			_sb.Append(sb);
		}}
		
		private static string WriteAttribute<P>(Tuple<Tuple<string, int>, Tuple<P, int>, bool> value)
		{{
			if (value == null)
				return string.Empty;
		 
			StringBuilder sb = new StringBuilder();
		 
			sb.Append(value.Item1.Item1);
			sb.Append(value.Item2.Item1);
		 
			return sb.ToString();
		}}
	}}
}}
"@ -f $templateBaseClassName

$allCode = $templateBaseCode + "`n" + $templateCode

Add-Type -TypeDefinition $allCode -ReferencedAssemblies Microsoft.CSharp.dll

$templateInstance = new-object -typename ("{0}.{1}" -f "Templates", $templateClassName)

Set-Content ($outputFile) $templateinstance.Render($packages)