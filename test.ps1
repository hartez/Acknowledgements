function Write-Passed
{
	Write-Host -ForegroundColor green -NoNewLine “.”;
}

function assert 
( 
	[bool] $condition = $(Please specify a condition),
	[string] $message = “Test failed.” 
)
{
	if(-not $condition)
	{
		Write-Error “FAIL. $message”
	}
	else
	{
		Write-Passed
	}
}

function assertEquals
( 
	$expected = $(Please specify the expected object),
	$actual = $(Please specify the actual object),
	[string] $message = “Test failed.” 
)
{
	if(-not ($expected -eq $actual))
	{
		Write-Error “FAIL.  Expected: $expected.  Actual: $actual.  $message.”
	}
	else
	{
		Write-Passed
	}
}

if(Test-Path acknowledgements_test.html)
{
	del acknowledgements_test.html 
}

# Running as script without profile via with powershell.exe (similar to running from VS post-build event)
# Assumes nuget.exe is in path
powershell -NoProfile -file acknowledgements.ps1 sample_packages.config default.cshtml acknowledgements_test.html 

assertEquals 0 $LastExitCode "Exit code should be 0"
assert (Test-Path .\acknowledgements_test.html) "Output file acknowledgements_test.html should have been created"
assert ((Select-String "This application makes use of the following libraries" .\acknowledgements_test.html) -ne $null)

Write-Host "Finished."

if(Test-Path acknowledgements_test.html)
{
	del acknowledgements_test.html 
}

# As if running directly from the command line in PowerShell
# Assumes nuget.exe is in path
.\acknowledgements.ps1 sample_packages.config default.cshtml acknowledgements_test.html 

assertEquals 0 $LastExitCode "Exit code should be 0"
assert (Test-Path .\acknowledgements_test.html) "Output file acknowledgements_test.html should have been created"
assert ((Select-String "This application makes use of the following libraries" .\acknowledgements_test.html) -ne $null)