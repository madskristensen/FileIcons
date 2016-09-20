# File Icons

[![Build status](https://ci.appveyor.com/api/projects/status/3duxejqo9w72ynpw?svg=true)](https://ci.appveyor.com/project/madskristensen/fileicons)

Download this extension from the [VS Gallery](https://visualstudiogallery.msdn.microsoft.com/5e1762e8-a88b-417c-8467-6a65d771cc4e)
or get the [CI build](http://vsixgallery.com/extension/3a7b4930-a5fb-46ec-a9b8-9610c8f953b8/).

---------------------------------------

Adds icons for files that are not recognized by Solution Explorer

See the [change log](CHANGELOG.md) for changes and road map.

## Solution Explorer
This extensions adds file icons to Solution Explorer for files that
Visual Studio doesn't provide icons for.

![Before and After](art/before-after.png)

Check out the
[full list of file icons](https://github.com/madskristensen/FileIcons/blob/master/src/icons.pkgdef)
supported by this extension.

## Suggest new icons
Though this extension helps to provide missing icons for known file
types, there are still plenty that are missing. To make it super easy
to suggest new icons, there is now a button for that.

![Report missing icon](art/context-menu.png)

Clicking that button will open a GitHub issue so an icon can be added
for that particular file type.

## Language support
For additional language support in Visual Studio, give [Syntax Highlighting Pack](https://visualstudiogallery.msdn.microsoft.com/d92fd742-bab3-4314-b866-50b871d679ee) a try. It adds over 40 new languages to Visual Studio.

## Credit
Some icons comes from the brilliant
[vscode-icons](https://github.com/robertohuertasm/vscode-icons)
extension for Visual Studio Code.

## Contribute
Check out the [contribution guidelines](.github/CONTRIBUTING.md)
if you want to contribute to this project.

For cloning and building this project yourself, make sure
to install the
[Extensibility Tools 2015](https://visualstudiogallery.msdn.microsoft.com/ab39a092-1343-46e2-b0f1-6a3f91155aa6)
extension for Visual Studio which enables some features
used by this project.

## License
[Apache 2.0](LICENSE)