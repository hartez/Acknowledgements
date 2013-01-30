# Need to search for razor dll
# need to call nuget to install razor dll if it's not there
# need to read in template from a file
# need a default file
# need to set the Model for the template
# need to return pack info under one object so it can be set as the model

function getNugetData ($package) {
		
	Write-Host ("Retrieving data for package '{0}'" -f $package.id)
	
	$packageUrl = ("http://nuget.org/api/v2/Packages(Id='{0}',Version='{1}')" -f $package.id, $package.version)
	
	$request = [System.Net.WebRequest]::Create($packageUrl)
	$response = $request.GetResponse()
	$reqstream = $response.GetResponseStream()
	$sr = new-object System.IO.StreamReader $reqstream
	$result = $sr.ReadToEnd()
	
	Write-Host $result
	
	[xml]$packageData = $result
	
	@{LicenseUrl = $packageData.entry.properties.LicenseUrl; `
	ProjectUrl = $packageData.entry.properties.ProjectUrl; `
	Id = $package.id; `
	Version = $package.version}
}

# $packagesconfigfile = "c:\users\hartez\documents\traceur\lhp\beadmin\lhptadminconsole\packages.config"
# [xml]$packagesconfig = (get-content $packagesconfigfile)

# $data = getnugetdata ($packagesconfig.packages.package | select-object -index 0)

# Add-Type -Path .\Microsoft.AspNet.Razor.2.0.20715.0\lib\net40\System.Web.Razor.dll

# $language = New-Object `
    # -TypeName System.Web.Razor.CSharpRazorCodeLanguage
# $engineHost = New-Object `
    # -TypeName System.Web.Razor.RazorEngineHost `
    # -ArgumentList $language `
    # -Property @{
        # DefaultBaseClass = "TemplateBase";
        # DefaultClassName = "Template";
        # DefaultNamespace = "Templates";
    # }
# $engine = New-Object `
    # -TypeName System.Web.Razor.RazorTemplateEngine `
    # -ArgumentList $engineHost
	
# $template = "Hello World!"
# $templateReader = New-Object `
    # -TypeName System.IO.StringReader `
    # -ArgumentList $template
# $code = $engine.GenerateCode($templateReader)

# $codeWriter = New-Object -TypeName System.IO.StringWriter
# $compiler = New-Object `
    # -TypeName Microsoft.CSharp.CSharpCodeProvider
# $compiler.GenerateCodeFromCompileUnit(
    # $code.GeneratedCode, $codeWriter, $null
# )
# $templateCode = $codeWriter.ToString()

# $allcode = @"
# using System;

# namespace Templates {

	# public abstract class TemplateBase {
		# public abstract void Execute();
		# public virtual void WriteLiteral(object value) {
			# Console.Write(value);
		# }
	# }
# }
# "@ + "`n" + $templateCode

# Write-Host $allCode

# Add-Type -typedefinition $allcode

# $templateinstance = new-object -typename Templates.Template
# $templateinstance.execute()