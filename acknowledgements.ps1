# need to set the Model for the template
# need to return pack info under one object so it can be set as the model

if($args.length -lt 2)
{
	Write-Host "Usage: acknowledgements [path to packages.config] [path to template]"
	exit
}

$packagesConfigFile = $args[0]
$templateFile = $args[1]

function getNugetData ($package) {
		
	Write-Host ("Retrieving data for package '{0}'" -f $package.id)
	
	$packageUrl = ("http://nuget.org/api/v2/Packages(Id='{0}',Version='{1}')" -f $package.id, $package.version)
	
	$request = [System.Net.WebRequest]::Create($packageUrl)
	$response = $request.GetResponse()
	$reqstream = $response.GetResponseStream()
	$sr = new-object System.IO.StreamReader $reqstream
	$result = $sr.ReadToEnd()
	
	[xml]$packageData = $result
	
	@{LicenseUrl = $packageData.entry.properties.LicenseUrl; `
	ProjectUrl = $packageData.entry.properties.ProjectUrl; `
	Id = $package.id; `
	Version = $package.version}
}

function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

[xml]$packagesConfig = (Get-Content $packagesConfigFile)

# $packages = @($packagesConfig.packages.package | select-object -index 0,2) | % {getNugetData $_} 

# $packages[1]

 $razorAssembly = 
            [AppDomain]::CurrentDomain.GetAssemblies() |
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

$allcode = @"
using System;

namespace Templates {

	public abstract class TemplateBase {
		public abstract void Execute();
		public virtual void WriteLiteral(object value) {
			Console.Write(value);
		}
	}
}
"@ + "`n" + $templateCode

Write-Host $allCode

Add-Type -typedefinition $allcode

$templateinstance = new-object -typename Templates.Template
$templateinstance.execute()