# TTop Desk

TTop Desk is a native KDE Plasma system-monitor widget. It is intended to
provide a compact graphical companion to the wider TTop ecosystem while
remaining independent from the existing TTop CLI project.

Milestone 1.3 provides live total CPU utilization, physical memory usage,
network receive/transmit throughput, and CPU temperature on KDE Plasma 5.27.
The compact dark card refreshes approximately once per second. Memory is shown
as a percentage and binary used/total sizes; network rates automatically use
B/s, KiB/s, MiB/s, or GiB/s; temperature is formatted in degrees Celsius.

TTop Desk prefers Plasma's `systemmonitor` DataEngine and falls back to Plasma
5's native `ksystemstats` sensor API when a distribution ships the legacy
DataEngine without its former backend. There is no Python backend or external
runtime dependency.

GPU and disk temperatures and process metrics remain future milestones, as
does integration with a shared TTop Core backend.

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
names and discovers network interfaces and temperature sensors from the runtime
sensor tree. Each metric displays `Unavailable` when no compatible source
responds.

For network throughput, TTop Desk prefers complete per-interface receive and
transmit rate pairs. It aggregates all eligible pairs, supporting simultaneous
Ethernet and Wi-Fi without adding a separate all-network sensor and thereby
double-counting traffic. A reliable aggregate pair is used alone only when no
eligible per-interface pair exists. Direct byte-rate sensors are preferred;
cumulative counters are converted to rates from consecutive samples when
necessary.

Loopback and common virtual, bridge, and tunnel prefixes such as `docker`,
`veth`, `virbr`, `vmnet`, `br-`, `tun`, `tap`, and `wg` are ignored. VPN and
unfamiliar virtual-interface handling is intentionally conservative: unknown
interfaces are not rejected merely because their names are unfamiliar.

For CPU temperature, TTop Desk selects one representation rather than mixing
package and core sensors. Its preference order is: CPU package, AMD Tctl/Tdie,
x86 package, CPU aggregate, average of distinct valid CPU cores, then a single
core. Values outside -20–150 °C are rejected rather than clamped. Direct Celsius
and millidegree-Celsius payloads are supported. If a package-level source is
unavailable but several core sensors remain valid, their average is displayed.
Synthetic CPU temperature entries that report both a zero value and a zero
maximum are treated as unavailable placeholders until a valid sample arrives.

Temperature availability depends on kernel hardware-monitor drivers and the
lm-sensors data exposed to Plasma. Missing support is handled gracefully and
does not affect CPU, memory, or network metrics. GPU and disk temperatures are
intentionally excluded from this milestone.

To inspect discovery, temporarily set `debugMetrics` to `true` near the top of
`package/contents/ui/main.qml`, then launch the widget. Startup logging includes
advertised system-monitor sources, discovered network candidates, ignored
interfaces and reasons, selected CPU and memory sources, selected network RX/TX
pairs, temperature candidates and rejection reasons, the selected temperature
category, and whether network values are direct rates or cumulative counters.
Return the property to `false` after troubleshooting to keep normal Plasma logs
quiet.

Follow relevant Plasma and QML messages with:

```bash
journalctl --user -f | grep -Ei "plasmashell|plasmoid|qml|ttop"
```

For manual hardware-sensor diagnosis, users may also run:

```bash
sensors
ls /sys/class/hwmon
```

These commands are not run by TTop Desk.

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

`MetricsProvider.qml` isolates DataEngine discovery, network-interface
selection and aggregation, temperature preference and core averaging,
counter-to-rate conversion, the native Plasma 5 sensor fallback, defensive
value parsing, normalization, and formatting from the presentation.
`MetricRow.qml` provides percentage metric displays, `NetworkRow.qml` presents
throughput without a fake progress scale, `TemperatureRow.qml` presents the
selected thermal value, and `main.qml` only composes the card. This boundary
leaves room for a later shared TTop Core adapter without coupling system data
collection to the Plasma-specific visual components.

Legacy `mem/physical/*` values without unit metadata are assumed to be KiB,
matching Plasma 5's KSysGuard sensor convention. Explicit unit metadata always
takes precedence. Bare percentage values are treated as 0–100 unless their
payload metadata identifies a 0–1 ratio.

## License

TTop Desk is licensed under the GNU General Public License, version 3 or later.
See [LICENSE](LICENSE).
