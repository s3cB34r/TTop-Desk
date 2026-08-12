# TTop Desk release bundle

This bundle installs TTop Desk @VERSION@ for the current user on KDE Plasma 5.27.
It never writes to system directories and does not require administrator
privileges.

## Install or upgrade

```bash
./install.sh
```

The installer verifies checksums and required commands, installs or upgrades
the Plasma widget, places the Python backend below
`~/.local/share/ttop-desk/backend`, installs the German catalog, and enables
the `ttop-desk-backend.service` user unit. Running it repeatedly is safe and
preserves existing widget configuration.

Required runtime packages on Ubuntu-family systems provide KDE Plasma 5,
`kpackagetool5`, Python 3, the Python `psutil` module, and a working systemd
user session. Package names vary by distribution, so the installer reports
missing dependencies without attempting to install operating-system packages.

NVIDIA’s `libnvidia-ml.so.1` is optional. Without it, installation and Top
Processes still work and the GPU section reports that GPU data is unavailable.
CPU, RAM, temperature, network, disk-I/O, and filesystem metrics remain
Plasma-native even if the backend is stopped.

After installation, add **TTop Desk** from Plasma’s widget selector. An
already-running instance may need to be reopened or removed and added again
after a native runtime upgrade. The installer does not restart Plasma.

## Backend status and logs

```bash
systemctl --user status ttop-desk-backend
journalctl --user -u ttop-desk-backend -f
```

## Uninstall

Run the uninstaller from the extracted release bundle:

```bash
./uninstall.sh
```

It disables and removes only the TTop Desk user service, backend, translation
catalog, and widget package. Plasma’s stored widget configuration is preserved.
To remove settings completely, first remove every TTop Desk instance through
Plasma’s desktop editing interface; edit Plasma configuration files manually
only while Plasma is stopped and only if you understand their shared format.

See `RELEASE-NOTES.md`, `CHANGELOG.md`, and `LICENSE` for release details.
