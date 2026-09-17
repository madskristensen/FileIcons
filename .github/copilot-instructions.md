---
description: Guidelines for maintaining the File Icons VSIX
applyTo: '**/*.cs, **/*.vsct, **/*.imagemanifest, **/*.pkgdef, **/*.json, **/*.xaml, **/*.ps1'
---

# File Icons maintenance guidelines

- Treat `catalog.json` as the source of truth; do not hand-edit `src/icons.pkgdef`, `src/Monikers.imagemanifest`, or `FileExtensions.md`.
- Prefer a public Visual Studio `KnownMonikers` value when it accurately represents the file type. Add custom artwork only when no suitable public moniker exists.
- Prefer size-neutral WPF XAML converted from an official SVG. Use PNG only when the source cannot be represented faithfully as WPF geometry or the authoritative artwork is raster-only.
- Prefer file icons from [vscode-icons](https://github.com/vscode-icons/vscode-icons) when no better `KnownMonikers` match exists. Do not use its folder icons.
- Pin every `vscode-icons` source URL to the repository commit used by the existing catalog entries. Record `MIT; see THIRD-PARTY-NOTICES.txt` as the license and set `provenance` to `verified`.
- Convert supported `file_type_*.svg` assets with `tools/Convert-SvgToXaml.ps1`. The converter intentionally rejects unsupported SVG features; do not accept an approximate or lossy conversion.
- Custom icon XAML must have a renderable `Viewbox` or `Canvas` root, preserve the SVG `viewBox`, remain size-neutral, and avoid standalone `DrawingImage` roots.
- After changing `catalog.json` or icon resources, run `pwsh -NoProfile -File .\tools\Generate-Catalog.ps1` and validate with `pwsh -NoProfile -File .\tools\Generate-Catalog.ps1 -Check`.
- Custom moniker GUID and ID pairs must be globally unique.
- Do not override a Visual Studio core association without documenting the reason.
- Record the source and license for every custom image.
- Keep changes to icon associations deterministic and update generated documentation.
- Switch to the UI thread before Visual Studio COM or shell operations.
- Do not block asynchronous code with `.Result` or `.Wait()`.
