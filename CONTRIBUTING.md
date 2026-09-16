# Contributing

## File associations

`catalog.json` is the source of truth for file associations and custom images. Do not edit `src\icons.pkgdef`, `src\Monikers.imagemanifest`, or `FileExtensions.md` directly.

1. Check the current Visual Studio Image Catalog and shipped `ShellFileAssociations`.
2. Prefer a public `KnownMonikers.*` value when it accurately represents the format.
3. Add or update the association in `catalog.json`.
4. Run `pwsh -NoProfile -File .\tools\Generate-Catalog.ps1`.
5. Build `FileIcons.slnx`.

The generator rejects duplicate extensions, duplicate custom moniker IDs, invalid KnownMonikers, missing or unreferenced assets, and stale generated files.

## Custom artwork

Only add custom artwork when the Visual Studio Image Catalog has no suitable image. Prefer a size-neutral XAML image converted from an official SVG over a raster image. New custom image records must contain:

- a unique name and numeric ID
- the XAML or PNG file name
- a source URL
- an SPDX license identifier or concise redistribution terms
- `provenance` set to `verified`

Logos can also be protected by trademarks even when their source repository has an open-source license. Use official artwork without altering the brand, and do not add an asset when redistribution rights are unclear.

For SVG artwork, preserve the SVG `viewBox` and translate paths into WPF geometry inside XAML with a renderable `Viewbox` or `Canvas` root. A standalone `DrawingImage` can be loaded by WPF but is not rendered by the Visual Studio image service. Flatten CSS classes and transforms first. SVG filters, scripts, text, external resources, masks, and unsupported paint servers must not be copied into the XAML. Do not add raster dimensions to XAML catalog entries; this lets the Visual Studio image service scale the vector source. Validate the result in Image Library Viewer under light, dark, high-contrast, and multiple-DPI settings.

Use PNG only when the source cannot be represented faithfully as WPF geometry or when the authoritative artwork is raster-only.

Legacy images are marked `legacy-unverified` and should be audited incrementally.

## Pull requests

Keep association changes focused. Include a screenshot from Solution Explorer and identify related issues. The build validates that all generated artifacts are current.
