# File Icons

[![Build](https://github.com/madskristensen/FileIcons/actions/workflows/build.yaml/badge.svg)](https://github.com/madskristensen/FileIcons/actions/workflows/build.yaml)

Adds icons for file types that Visual Studio does not recognize in Solution Explorer.

Download the extension from the [Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=MadsKristensen.FileIcons) or get the latest CI build from [Open VSIX](https://www.vsixgallery.com/extension/3a7b4930-a5fb-46ec-a9b8-9610c8f953b8/).

## Solution Explorer

File Icons adds distinctive icons for file types that would otherwise use a generic or misleading icon.

![Before and after](art/before-after.png)

See the [complete list of supported extensions](FileExtensions.md).

## Suggest an icon

Before opening a request, check whether the extension is already listed and whether the latest Visual Studio release supplies an icon. Then use the repository's [icon request form](https://github.com/madskristensen/FileIcons/issues/new?template=icon_request.yml).

The extension also provides a **Report missing icon** command in Solution Explorer when it detects an unregistered file extension.

![Report missing icon](art/context-menu.png)

## Contributing

Read the [contribution guidelines](CONTRIBUTING.md) before changing associations or artwork. Contributions should prefer a public Visual Studio `KnownMoniker` when one accurately represents the file type. Custom artwork must include its source and redistribution license.

Build the solution with Visual Studio 2022 or later. The SDK-style project restores all required VSSDK packages automatically.

The icon catalog is generated from `catalog.json`. After changing it, run:

```powershell
pwsh -NoProfile -File .\tools\Generate-Catalog.ps1
```

Maintainers can rank coverage gaps from an aggregate telemetry export without adding the export to the repository:

```powershell
pwsh -NoProfile -File .\tools\Get-TelemetryCoverage.ps1 -CsvPath <path-to-csv>
```

## Credits

Some original artwork came from the [vscode-icons](https://github.com/vscode-icons-team/vscode-icons) project.

## License

[Apache 2.0](LICENSE)
