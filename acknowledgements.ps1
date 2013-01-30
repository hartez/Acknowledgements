#Needs to force recompile of the template each time (otherwise the type stays in the appdomain
#and changes to the template don't show up in the output)
# Need to figure out how to have multiple package sources or ignore non-public packages
# Need to get rid of the little [string] at the beginning
# Need to make the default template cooler

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
	$response = $request.GetResponse()
	$reqstream = $response.GetResponseStream()
	$sr = new-object System.IO.StreamReader $reqstream
	$result = $sr.ReadToEnd()
	
	[xml]$packageData = $result
	
	$result = New-Object -TypeName PSObject
	
	$result | 
		Add-Member -MemberType NoteProperty -Name LicenseUrl -Value $packageData.entry.properties.LicenseUrl -PassThru |
		Add-Member -MemberType NoteProperty -Name ProjectUrl -Value $packageData.entry.properties.ProjectUrl -PassThru |
		Add-Member -MemberType NoteProperty -Name Id -Value $package.id -PassThru |
		Add-Member -MemberType NoteProperty -Name Version -Value $package.version -PassThru
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
		-Path $PWD `
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
		
$language = New-Object `
     -TypeName System.Web.Razor.CSharpRazorCodeLanguage
$engineHost = New-Object `
    -TypeName System.Web.Razor.RazorEngineHost `
    -ArgumentList $language `
    -Property @{
        DefaultBaseClass = "TemplateBase";
        DefaultClassName = "Template";
        DefaultNamespace = "Templates";
    }
$engine = New-Object `
    -TypeName System.Web.Razor.RazorTemplateEngine `
    -ArgumentList $engineHost
	
$template = (Get-Content $templateFile)
$templateReader = New-Object `
    -TypeName System.IO.StringReader `
    -ArgumentList [string]$template
$code = $engine.GenerateCode($templateReader)

$codeWriter = New-Object -TypeName System.IO.StringWriter
$compiler = New-Object `
    -TypeName Microsoft.CSharp.CSharpCodeProvider
$compiler.GenerateCodeFromCompileUnit(
    $code.GeneratedCode, $codeWriter, $null
)
$templateCode = $codeWriter.ToString()

$allCode = @"
using System;
using System.Text;
using Microsoft.CSharp;
using Microsoft.CSharp.RuntimeBinder;

namespace Templates {

	public abstract class TemplateBase {
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
            var res = _sb.ToString();
            _sb.Clear();
            return res;
        }}
	}
}
"@ + "`n" + $templateCode

Add-Type -TypeDefinition $allCode -ReferencedAssemblies Microsoft.CSharp.dll

$templateInstance = new-object -typename Templates.Template

Set-Content ($outputFile) $templateinstance.Render($packages)