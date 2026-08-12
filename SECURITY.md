# Security policy

## Supported release

Security fixes are currently evaluated for the latest published TTop Desk
0.9.x beta. Plasma 6 is not supported by this release line.

## Security model

TTop Desk installs entirely for the current user and requires neither `sudo`
nor root privileges. Plasma-native metrics are read through KDE APIs. The
optional Python backend provides read-only process and NVIDIA GPU monitoring,
runs as a `systemd --user` service, and communicates only through
`$XDG_RUNTIME_DIR/ttop-desk.sock`.

The service restricts itself to Unix sockets, creates the socket with mode
`0600`, verifies same-user peers where the platform supports `SO_PEERCRED`, and
does not open a TCP listener. Process responses contain PID, process name, CPU,
RSS memory, and username; the widget discards username and never requests full
command lines, environments, open files, or network connections.

## Reporting a vulnerability

Please use **GitHub Security Advisories → Report a vulnerability** in this
repository so maintainers can investigate before public disclosure. If private
reporting is unavailable, open a minimal issue that asks maintainers to enable
or review private vulnerability reporting; do not include exploit details,
private logs, tokens, full process command lines, or other sensitive data in a
public issue.

Include the affected TTop Desk version, distribution, Plasma and Qt versions,
whether the backend was active, a concise impact description, and safe
reproduction steps. Maintainers will acknowledge and triage reports as project
availability permits; no fixed response-time guarantee is currently offered.
