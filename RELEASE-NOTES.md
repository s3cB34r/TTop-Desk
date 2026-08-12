# TTop Desk 0.9.0

TTop Desk 0.9.0 is the first public beta release candidate. It targets KDE
Plasma 5.27 with Qt 5.15, primarily on Linux Mint based on Ubuntu 24.04.

The widget provides Plasma-native CPU, RAM, CPU/package temperature, network
RX/TX, disk-I/O, and filesystem-capacity monitoring. A private user-level
backend adds a bounded Top Processes list and NVIDIA GPU utilization, VRAM,
and temperature through NVML. The backend uses only a mode-0600 Unix socket and
does not require root access.

The beta also includes compact and full representations, configurable
sections and refresh intervals, theme-aware appearance controls, live history
sparklines, accessibility and HiDPI hardening, and per-widget English, German,
or system-default language selection.

## Known limitations

- Plasma 6 is not supported yet.
- AMD and Intel GPU providers are not implemented.
- Top Processes and NVIDIA GPU metrics require the user backend; native Plasma
  metrics remain available when it is stopped.
- NVIDIA metrics require the proprietary driver NVML library. Its absence does
  not prevent installation or process monitoring.
- KDE Store publication has not been performed.
- After upgrading native widget code, an existing instance may need to be
  reopened or removed and added again. The Plasma desktop is not restarted by
  the installer.
