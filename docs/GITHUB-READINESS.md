# GitHub repository readiness

This file records recommended repository metadata and release presentation. It
does not publish or modify GitHub settings.

## Repository metadata

**Description**

> A lightweight KDE Plasma system monitor widget with live metrics, GPU monitoring, process view, graphs and deep customization.

**Topics**

`kde`, `plasma`, `plasmoid`, `linux`, `system-monitor`, `qml`, `python`,
`nvidia`, `monitoring`

## First beta release

- Proposed tag: `v0.9.0`
- Release title: `TTop Desk 0.9.0 – First public beta`
- Use `RELEASE-NOTES.md` as the release-description source.
- Mark the GitHub release as a pre-release while 0.9.0 remains beta.

Attach these files from `dist/`:

1. `ttop-desk-0.9.0-linux.tar.gz` — recommended end-user download containing
   the complete user installer, widget, backend, translations, documentation,
   license, and internal checksums.
2. `ttop-desk-0.9.0.plasmoid` — useful for users who want only native metrics
   or already manage backend installation separately.
3. `ttop-desk-backend-0.9.0.tar.gz` — useful for inspection and downstream
   user-level packaging; redundant for ordinary full-bundle installation.
4. `SHA256SUMS` — integrity manifest for every public artifact and companion
   release file.

Do not upload repository build directories, visual candidates, developer
service units, or locally installed files.
