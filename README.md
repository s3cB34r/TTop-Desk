# TTop Desk

TTop Desk is a native KDE Plasma system-monitor widget. It is intended to
provide a compact graphical companion to the wider TTop ecosystem while
remaining independent from the existing TTop CLI project.

Milestone 1.0 is a static widget skeleton for KDE Plasma 5.27. It presents a
dark system-monitor card with placeholder rows for CPU, RAM, network activity,
and temperature. Live metrics and integration with a future shared TTop Core
backend are planned for later milestones; this release has no Python backend or
external runtime dependencies.

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

The QML presentation currently owns a small static metric model. A later
milestone can replace that model with an adapter for a shared TTop Core backend,
keeping data collection separate from the Plasma-specific user interface.

## License

TTop Desk is licensed under the GNU General Public License, version 3 or later.
See [LICENSE](LICENSE).
