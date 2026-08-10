# TTop Desk

TTop Desk is a native KDE Plasma system-monitor widget. It is intended to
provide a compact graphical companion to the wider TTop ecosystem while
remaining independent from the existing TTop CLI project.

Milestone 1.8 adds a minimal local backend foundation for advanced metrics
that Plasma 5 cannot provide. It is backend-only and is not connected to the
visible widget yet; all existing metrics and layouts remain Plasma-native.

Milestone 1.7a added a development-only process sensor capability probe and a
defensive normalization provider. There is no visible process UI yet, and the
existing widget layout is unchanged. Process availability depends entirely on
what the Plasma 5 system-monitor sensors expose on the host; no external
commands or backend are used. Milestone 1.7b will proceed only if this probe
confirms usable per-process data.

Milestone 1.6 provides separate compact and full
representations, persistent Plasma settings, per-section visibility controls,
safe refresh interval controls, theme-aware styling, and a configurable
filesystem row limit. All live metrics from Milestone 1.5 remain available:
total CPU utilization, physical memory usage, network receive/transmit
throughput, CPU temperature, filesystem capacity, and disk read/write
throughput on KDE Plasma 5.27.

By default, CPU, memory, network, temperature, and disk I/O refresh once per
second. Filesystem capacity refreshes every 15 seconds. Memory and filesystems
use binary sizes; network and disk rates use B/s, KiB/s, MiB/s, or GiB/s;
temperature is formatted in degrees Celsius.

TTop Desk prefers Plasma's `systemmonitor` DataEngine and falls back to Plasma
5's native `ksystemstats` sensor API when a distribution ships the legacy
DataEngine without its former backend. These current production metrics remain
Plasma-native and do not depend on the optional local backend foundation.

SMART data, GPU monitoring, disk temperatures, and visible process metrics
remain future milestones, as does integration with a shared TTop Core backend.

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

## Widget settings and representations

Open the settings by right-clicking TTop Desk and choosing **Configure TTop
Desk…**. Changes apply to the running widget and are stored by Plasma; no Plasma
restart is required.

The settings page can independently show or hide CPU, memory, network,
temperature, filesystems, and disk I/O in the detailed view. It can also toggle
the full-view header and metric icons. The normal refresh interval can be set
to 500 ms, 1 second, 2 seconds, or 5 seconds. The filesystem interval accepts
safe values from 5 to 60 seconds, and the maximum number of filesystem rows can
be set from 1 to 10. **Show network and temperature details** adds those values
to the compact representation when their sections are enabled.

In a panel, the compact representation prioritizes CPU and RAM percentages.
It lays values out in a row for horizontal panels and stacks them for vertical
panels where practical. Filesystem rows and detailed disk I/O are deliberately
omitted from this small view. Click the compact widget to open the full view.

On the desktop, resize the widget beyond its compact threshold to use the full
card. Its preferred height follows the enabled sections, so hidden sections do
not leave large gaps. Filesystem rows are ordered by mount priority and bounded
by the configured entry limit.

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
names and discovers network interfaces, temperature sensors, and filesystem
capacity sources from the runtime sensor tree. Each metric displays
`Unavailable` when no compatible source responds.

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

For disk I/O, TTop Desk discovers complete read/write pairs and chooses one
mutually exclusive strategy. Recognizable whole physical block devices are
aggregated per device when available; otherwise a complete `disk/all` pair is
preferred over partitions, device-mapper aliases, RAID aliases, or opaque
volume identifiers. Aggregate and per-device values are never mixed. When a
whole-device pair exists, corresponding partition pairs are ignored. Common
virtual devices such as `loop`, `ram`, `zram`, optical `sr`, and floppy `fd`
devices are filtered.

Direct byte-rate sensors are preferred and cumulative byte counters are
converted from consecutive samples. Sector or block counters are accepted only
when Plasma exposes an explicit, plausible size sensor for the same device;
ambiguous counters are rejected. Counter resets, stale intervals, negative
deltas, and first samples are handled without manufacturing throughput values.

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

For filesystem capacity, TTop Desk discovers mount-specific `used`, `free` or
`available`, `total`, and percentage sensors. It prefers calculating percentage
from used and total bytes; total minus available is used when a direct used
value is absent, and a direct percentage is the final fallback. Values are
formatted in KiB, MiB, GiB, or TiB. Up to the configured number of unique
mounts are displayed (three by default), ordered as `/`, `/home`, `/data`, then
other meaningful persistent mounts.

Mounts are deduplicated by normalized mount path. When several source groups
describe the same mount, the group with the most complete used/total data wins.
Aggregate disk entries are never mixed with mount-specific entries. Known
virtual and transient filesystem types and paths—such as proc, sysfs, tmpfs,
overlay, `/run`, and `/snap`—are ignored. Unknown entries are included only
when Plasma exposes enough metadata to infer a meaningful mount path. Some
Plasma 5 installations expose filesystem labels instead of paths; the provider
maps explicit `root`, `home`, and `data` labels (plus common OS-volume labels)
to their conventional mount paths rather than guessing arbitrary locations.

To inspect discovery, temporarily set `debugMetrics` to `true` near the top of
`package/contents/ui/main.qml`, then launch the widget. Startup logging includes
advertised system-monitor sources, discovered network candidates, ignored
interfaces and reasons, selected CPU and memory sources, selected network RX/TX
pairs, temperature candidates and rejection reasons, filesystem candidates and
ignored entries, disk-I/O candidates and device classifications, duplicate
filtering decisions, selected mounts and capacity sources, selected disk-I/O
strategy and sources, the selected temperature category, and whether rate
sources are direct values or cumulative counters.
Return the property to `false` after troubleshooting to keep normal Plasma logs
quiet.

### Process sensor capability probe

Milestone 1.7a includes `ProcessProvider.qml` without instantiating it in the
production widget. Run its development-only Plasma harness with:

```bash
plasmoidviewer -a "$(pwd)/tests/process-probe"
```

The probe discovers process-related `systemmonitor` sources, inspects aggregate
arrays or maps and per-process sensor families, and prints high-level structure
information plus at most five normalized examples. It does not read `/proc`,
run process-list commands, or expose command-line arguments. CPU normalization
is provisional when source metadata does not define whether values are
system-wide percentages, per-core percentages, or another raw scale; finite
non-negative values are preserved without clamping to 100%. Resident/RSS
memory is emitted only when byte units can be determined safely.

On the primary Plasma 5.27.12 validation host, neither the legacy
`systemmonitor` DataEngine nor the native KSysGuard sensor tree advertised a
process-related source. Consequently there was no runtime process payload
structure or field set to normalize, CPU and resident-memory process values
were unavailable, and the provider cleanly reported `unavailable`. On this
host, Milestone 1.7b is not viable using Plasma system-monitor sensors alone.

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

For manual filesystem comparison and mount diagnostics, users may run:

```bash
findmnt
df -hT
```

These commands are also never invoked by the widget.

For manual disk-I/O sensor comparison, users may run:

```bash
lsblk
iostat
cat /proc/diskstats
```

These commands are not invoked by TTop Desk. `iostat` may not be installed on
every system and is not required by the widget.

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

`main.qml` owns the single `MetricsProvider` instance, validates configuration
values, and wires it into `CompactRepresentation.qml` and
`FullRepresentation.qml`. `MetricsProvider.qml` isolates DataEngine discovery, network-interface
selection and aggregation, temperature preference and core averaging,
filesystem discovery and deduplication, physical-disk selection, disk-I/O
aggregation, counter-to-rate conversion, the native Plasma 5 sensor fallback,
defensive value parsing, normalization, and formatting from the presentation.
`MetricRow.qml` provides percentage metric displays, `NetworkRow.qml` presents
throughput without a fake progress scale, `TemperatureRow.qml` presents the
selected thermal value, `FilesystemRow.qml` presents mount capacity with a real
percentage scale, `DiskIoRow.qml` presents disk throughput without a fake
percentage. `SectionHeader.qml` provides consistent theme-aware section titles,
status text, and optional semantic icons. This boundary leaves room for a later
shared TTop Core adapter without coupling system data collection to the
Plasma-specific visual components.

`ProcessProvider.qml` is a separate, currently uninstantiated capability layer
for Milestone 1.7a. It performs bounded startup/recovery discovery, defensive
array/map/nested-map normalization, PID deduplication, and stale per-process
record expiry. The development probe lives under `tests/` and is not installed
with the widget package.

Milestone 1.8 introduces a minimal local, read-only TTop backend foundation for
advanced metrics that Plasma 5 cannot provide. Process monitoring is its first
data source; future advanced sensors can extend the versioned protocol without
replacing working Plasma-native metrics. It communicates only through a
restrictive per-user Unix-domain socket, opens no network ports, needs no
elevated permissions, and is not yet integrated into production QML. Backend
architecture, protocol, manual commands, and privacy details are documented in
[`backend/README.md`](backend/README.md).

Legacy `mem/physical/*` values without unit metadata are assumed to be KiB,
matching Plasma 5's KSysGuard sensor convention. Explicit unit metadata always
takes precedence. Bare percentage values are treated as 0–100 unless their
payload metadata identifies a 0–1 ratio.
Filesystem capacity values without explicit units are assumed to be bytes,
matching Plasma 5's native disk sensors; recognized binary and decimal unit
suffixes override that assumption.
Modern `disk/*/read` and `disk/*/write` values without unit metadata are assumed
to be direct bytes-per-second rates, matching Plasma 5's native disk plugin.

## License

TTop Desk is licensed under the GNU General Public License, version 3 or later.
See [LICENSE](LICENSE).
