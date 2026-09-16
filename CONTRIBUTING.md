# Contributing

## File associations

`catalog.json` is the source of truth for file associations and custom images. Do not edit `src\icons.pkgdef`, `src\Icons\Monikers.imagemanifest`, or `FileExtensions.md` directly.

1. Check the current Visual Studio Image Catalog and shipped `ShellFileAssociations`.
2. Prefer a public `KnownMonikers.*` value when it accurately represents the format.
3. Add or update the association in `catalog.json`.
4. Run `pwsh -NoProfile -File .\tools\Generate-Catalog.ps1`.
5. Build `FileIcons.slnx`.

The generator rejects duplicate extensions, duplicate custom moniker IDs, invalid KnownMonikers, missing or unreferenced assets, and stale generated files.

## Custom artwork

Only add custom artwork when the Visual Studio Image Catalog has no suitable image. New custom image records must contain:

- a unique name and numeric ID
- the PNG file name
- a source URL
- an SPDX license identifier or concise redistribution terms
- `provenance` set to `verified`

Logos can also be protected by trademarks even when their source repository has an open-source license. Use official artwork without altering the brand, and do not add an asset when redistribution rights are unclear.

Legacy images are marked `legacy-unverified` and should be audited incrementally.

## Pull requests

Keep association changes focused. Include a screenshot from Solution Explorer and identify related issues. The build validates that all generated artifacts are current.
