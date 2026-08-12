# TTop Desk 0.9.0

TTop Desk 0.9.0 is the first public beta release candidate. It targets KDE
Plasma 5.27 with Qt 5.15, primarily on Linux Mint based on Ubuntu 24.04.

## Installation

Download and extract `ttop-desk-0.9.0-linux.tar.gz`, then run `./install.sh`
inside the extracted directory. Installation is entirely user-level, requires
no repository clone or `sudo`, validates the bundled checksums, installs or
upgrades the widget, and enables the backend user service. Existing widget
configuration is preserved. Run the bundled `./uninstall.sh` to remove runtime
files while retaining Plasma's stored widget configuration.

The widget provides Plasma-native CPU, RAM, CPU/package temperature, network
RX/TX, disk-I/O, and filesystem-capacity monitoring. A private user-level
backend adds a bounded Top Processes list and NVIDIA GPU utilization, VRAM,
and temperature through NVML. The backend uses only a mode-0600 Unix socket and
does not require root access.

The backend is required only for Top Processes and NVIDIA GPU data. CPU, RAM,
temperature, network, disk-I/O, and filesystem monitoring remain available
when it is stopped. Missing NVML does not fail installation; the GPU section
reports unavailable while process monitoring continues.

The beta also includes compact and full representations, configurable
sections and refresh intervals, theme-aware appearance controls, live history
sparklines, accessibility and HiDPI hardening, and per-widget English, German,
or system-default language selection.

## Known limitations

- Plasma 6 is not supported yet.
- GPU metrics currently support NVIDIA/NVML only. AMD and Intel providers are
  planned as future work.
- Top Processes and NVIDIA GPU metrics require the user backend; native Plasma
  metrics remain available when it is stopped.
- NVIDIA metrics require the proprietary driver NVML library. Its absence does
  not prevent installation or process monitoring.
- KDE Store publication has not been performed.
- After upgrading native widget code, an existing instance may need to be
  reopened or removed and added again. The Plasma desktop is not restarted by
  the installer.
