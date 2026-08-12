# Changelog

All notable user-visible changes to TTop Desk are documented here.

## 0.9.0 - First public beta

### Added

- Plasma-native CPU, RAM, temperature, network, disk-I/O, and filesystem monitoring.
- Read-only Top Processes through a private per-user Unix-socket backend.
- NVIDIA GPU utilization, VRAM, and temperature monitoring through NVML.
- Full and compact representations, configurable sections, appearance controls, and live sparklines.
- Per-widget English, German, and system-default language selection.
- Accessibility, HiDPI, localization, visual-regression, and release-QA coverage.
- User-level release installer, backend service, safe uninstaller, and reproducible release artifacts.
- Clean-profile release-candidate validation and public GitHub documentation.

### Fixed

- Compact CPU/RAM percentages no longer elide at the representation's preferred width.

### Known limitations

- KDE Plasma 6 is not supported yet.
- AMD and Intel GPU providers are not implemented.
- Top Processes and NVIDIA GPU metrics require the optional local backend service.
