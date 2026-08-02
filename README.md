# TTop Desk

TTop Desk is a native KDE Plasma system-monitor widget. It is intended to
provide a compact graphical companion to the wider TTop ecosystem while
remaining independent from the existing TTop CLI project.

Milestone 1.1 provides live total CPU utilization and physical memory usage on
KDE Plasma 5.27. The dark system-monitor card refreshes approximately once per
second and shows memory usage as both a percentage and binary used/total sizes.
It prefers Plasma's `systemmonitor` DataEngine and falls back to Plasma 5's
native `ksystemstats` sensor API when a distribution ships the legacy
DataEngine without its former backend. There is no Python backend or external
runtime dependency.

Network, temperature, GPU, disk, and process metrics remain future milestones,
as does integration with a shared TTop Core backend.

## Prerequisites

The primary target is KDE Plasma 5.27.12 on Linux Mint based on Ubuntu 24.04.
For direct development and installation, the system needs:

- KDE Plasma 5 and the Plasma Framework runtime
- `plasmoidviewer` from the Plasma SDK (`plasma-sdk` on Ubuntu-family systems)
- `kpackagetool5` from the Plasma Framework tools
- CMake and `extra-cmake-modules` only when using the CMake installation path
- Plasma 5 development files (commonly `libkf5plasma-dev`) only for CMake setup

Package names can vary between distributions. This repository does not install
or modify system packages.

## Test locally

Run the widget directly from the repository:

```bash
./scripts/test.sh
```

The equivalent direct command is:

```bash
plasmoidviewer -a "$(pwd)/package"
```

### Metric discovery debugging

Plasma 5 system-monitor sensor names can differ between releases and
installations. TTop Desk checks several known CPU and physical-memory source
names, uses the first source that returns valid data, and displays
`Unavailable` when no compatible source responds.

To inspect discovery, temporarily set `debugMetrics` to `true` near the top of
`package/contents/ui/main.qml`, then launch the widget. Startup logging includes
all advertised system-monitor sources, selected CPU and memory sources, and the
reason an incompatible candidate was rejected. Return the property to `false`
after troubleshooting to keep normal Plasma logs quiet.

Follow relevant Plasma and QML messages with:

```bash
journalctl --user -f | grep -Ei "plasmashell|plasmoid|qml|ttop"
```

## Install, upgrade, and uninstall

Install the current local package for the current user:

```bash
./scripts/install.sh
```

Upgrade an existing installation after making changes:

```bash
./scripts/upgrade.sh
```

Remove the widget:

```bash
./scripts/uninstall.sh
```

No command above requires `sudo`. After installation, add **TTop Desk** from
Plasma's widget browser.

## Optional CMake installation

The package can also be staged through the standard Plasma 5 CMake workflow:

```bash
cmake -S . -B build
cmake --build build
cmake --install build
```

The shell scripts remain the quickest development path.

## Architecture

`MetricsProvider.qml` isolates DataEngine discovery, the native Plasma 5 sensor
fallback, defensive value parsing, normalization, and byte formatting from the
presentation. `MetricRow.qml` provides the reusable metric display, while
`main.qml` only composes the card. This boundary leaves room for a later shared
TTop Core adapter without coupling system data collection to the Plasma-specific
visual components.

Legacy `mem/physical/*` values without unit metadata are assumed to be KiB,
matching Plasma 5's KSysGuard sensor convention. Explicit unit metadata always
takes precedence. Bare percentage values are treated as 0–100 unless their
payload metadata identifies a 0–1 ratio.

## License

TTop Desk is licensed under the GNU General Public License, version 3 or later.
See [LICENSE](LICENSE).
