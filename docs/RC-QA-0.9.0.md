# TTop Desk 0.9.0 release-candidate QA

This document records the Milestone 1.17 candidate strategy. Final results are
filled from the candidate rebuilt during the same validation pass.

## Strategy and isolation

The complete Linux bundle is extracted below a temporary directory. Release
commands are run from that extracted directory, and archive/runtime scans do
not use backend modules or installers from the repository. A temporary HOME
and XDG directory set provides a fresh widget/configuration profile for
first-launch and default checks. The real logged-in Plasma 5.27 user session is
used separately for the `systemd --user` lifecycle and visible desktop widget,
because a second fully independent login or VM is not available.

This is a clean-profile approximation, not a clean operating-system VM. System
Plasma, Qt, Python, psutil, NVML, and systemd packages are shared with the host.
The primary Plasma configuration is not deleted or rewritten for isolation.

## Candidate results

Candidate artifact: `ttop-desk-0.9.0-linux.tar.gz`

- Fresh temporary HOME/XDG profile: passed; no previous widget, service,
  socket, or configuration keys were present.
- Isolated nested `systemd --user` manager: install, enable/start, mode-0600
  socket, bounded process request, NVIDIA GPU request, second install, stop,
  start, restart, uninstall, and reinstall passed.
- First launch under German host locale: source-English default and all enabled
  sections passed; native metrics, backend process/GPU data, and full-card
  containment were visible.
- Backend failure/recovery: process and GPU sections showed `Backend
  unavailable`; native metrics remained live; both backend sections recovered
  automatically after starting the service.
- Settings persistence: a separate temporary real-desktop widget retained
  title, German language, section visibility, process count/sort, graph
  visibility, opacity, and compact graph settings across a Plasma Shell reload.
  The user's original widget was not modified, and the temporary widget was
  removed afterward.
- Automated layout/language coverage: English/German, all/mostly-disabled
  sections, dynamic card sizing, and settings pages passed existing probes.
- Compact graphs: CPU, memory, GPU, and network selections passed without
  changing panel height. RC inspection found and fixed insufficient preferred
  width for the default compact CPU/RAM percentages.
- Synthetic scale 1.0, 1.5, and 2.0 captures passed for full and compact views.
- Dark integration passed in the clean artifact widget. Breeze Light was
  validated through plasmoidviewer's non-persistent `--theme breeze-light`
  path; the user's desktop theme was not changed.
- No-NVML behavior passed unit coverage and the deterministic unavailable-GPU
  visual scenario. The host's real NVIDIA/NVML path also passed.
- Checksums and recursive archive/installed-file portability scans passed.

## Limitations of this pass

- The clean profile shares the host operating-system packages, kernel, GPU,
  driver, and display server; it is not a fresh VM or separate login account.
- Plasmoidviewer emits containment-size warnings that do not occur in the real
  desktop widget. Application-specific QML errors were not observed.
- Visual baselines are still optional; candidate screenshots were inspected
  manually where no committed baseline exists.

No release blocker remained after the compact-width correction. Final issue
classification is recorded in the Milestone 1.17 report.
