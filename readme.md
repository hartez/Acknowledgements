# Acknowledgements

Acknowledgements is a PowerShell script that uses your NuGet configuration to generate an acknowledgements page for third-party libraries you use in your project. I created this partly to fulfill license requirements (some packages require that you display their license if you use them for a website, for example), but mostly because I wanted to help promote package authors who'd made my life easier. Keeping track of all the projects you're using (and manually maintaining an acknowledgements page) can be a pain, so I decided to make it simpler.

The script is designed to be run as a (pre- or post-) build event. You just point it at your packages.config file, feed it a [Razor template](http://en.wikipedia.org/wiki/Microsoft_ASP.NET_Razor_view_engine), and tell it where to put the output file. 

Acknowledgements will retrieve information about each package from Nuget.org and populate your template accordingly. 

## Usage

    acknowledgements [path to packages.config] [path to template] [output path]

## Template
	
Acknowledgements has a default template (default.cshtml), but it can populate any Razor template. Here's an example of a (very) basic template:
	
    <table>
    	<tbody>
    	@foreach(var m in Model) {
    		<tr>
    			<td>@m.Id</td>
    			<td>@m.Author</td>
    			<td>@m.Version</td>
    			<td><a href="@m.ProjectUrl">@m.ProjectUrl</a></td>
    			<td><a href="@m.LicenseUrl">@m.LicenseUrl</a></td>
    			<td>@m.Description</td>
    		</tr>
    	}
    	</tbody>
    </table>

## Package Properties

Acknowledgements currently supports Id (the name of the package), version, author, project URL, license URL, and description. 

## Alternate Feeds

At the moment there's no support for alternate feeds (e.g., if you run a local NuGet feed from TeamCity). Packages that aren't available on NuGet.org are just ignored. I might be adding support for local feeds in the future.

## Dependencies

Acknowledgements requires PowerShell 3 and .NET 4.0 or higher. The first time it's run, it will attempt to grab the latest version of the Microsoft.AspNet.Razor package from NuGet and install it to the /packages folder under the script's folder. You can also oput the Razor libraries in that folder manually (say, if you don't have nuget.exe available).

## Disclaimer

This is the first draft of this project. It works on my machine. YMMV. If you try it and run into problems, please create an issue; I'll do what I can to fix it. 

