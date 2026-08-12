# TTop Desk backend @VERSION@

This archive contains the read-only Python backend used by TTop Desk for Top
Processes and NVIDIA GPU metrics. End users should install it through the full
Linux release bundle's `install.sh`; the archive is also provided separately
for content inspection and downstream user-level packaging.

The service runs as the current user from
`${XDG_DATA_HOME:-$HOME/.local/share}/ttop-desk/backend`, communicates only
through `$XDG_RUNTIME_DIR/ttop-desk.sock`, restricts the socket to mode `0600`,
and opens no TCP listener. The service unit is installed below
`${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user`.

Python 3 and `psutil` are required. NVIDIA's `libnvidia-ml.so.1` is optional;
without it, process monitoring remains available and GPU requests return an
empty device list. No external process or GPU polling command is executed.

The packaged `ttop-desk-backend.service.in` is a release-installer template.
Its placeholders must be replaced with absolute user-owned backend and Python
paths before systemd loads it.
