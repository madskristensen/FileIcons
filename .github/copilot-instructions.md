---
description: Guidelines for maintaining the File Icons VSIX
applyTo: '**/*.cs, **/*.vsct, **/*.imagemanifest, **/*.pkgdef, **/*.json'
---

# File Icons maintenance guidelines

- Treat `catalog.json` as the source of truth once present; do not hand-edit generated catalog artifacts.
- Prefer public Visual Studio `KnownMonikers` over bundled images.
- Custom moniker GUID and ID pairs must be globally unique.
- Do not override a Visual Studio core association without documenting the reason.
- Record the source and license for every custom image.
- Keep changes to icon associations deterministic and update generated documentation.
- Switch to the UI thread before Visual Studio COM or shell operations.
- Do not block asynchronous code with `.Result` or `.Wait()`.
