from __future__ import annotations

import re
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class ServiceFileTests(unittest.TestCase):
    def test_user_unit_is_local_only_and_restart_bounded(self) -> None:
        unit = (REPOSITORY_ROOT / "systemd/ttop-desk-backend.service").read_text(
            encoding="utf-8"
        )
        self.assertIn("ExecStart=\"@PYTHON_EXECUTABLE@\" -m ttop_backend.main", unit)
        self.assertIn("WorkingDirectory=@REPOSITORY_ROOT@/backend", unit)
        self.assertIn("Restart=on-failure", unit)
        self.assertIn("RestartSec=2", unit)
        self.assertIn("StartLimitBurst=5", unit)
        self.assertIn("RestrictAddressFamilies=AF_UNIX", unit)
        self.assertNotIn("PrivateTmp=true", unit)
        self.assertNotRegex(unit, r"(?m)^User=")
        self.assertNotIn("/data/Projects/TTop-Desk", unit)
        self.assertNotIn("AF_INET", unit)

    def test_service_scripts_use_only_user_systemd(self) -> None:
        for name in (
            "install-backend-service.sh",
            "uninstall-backend-service.sh",
            "backend-status.sh",
        ):
            script = (REPOSITORY_ROOT / "scripts" / name).read_text(encoding="utf-8")
            with self.subTest(script=name):
                self.assertIn("set -euo pipefail", script)
                self.assertNotIn("sudo", script)
                for match in re.finditer(r"systemctl\s+([^\n]+)", script):
                    self.assertIn("--user", match.group(1))

    def test_installer_updates_and_restarts_service_idempotently(self) -> None:
        script = (
            REPOSITORY_ROOT / "scripts/install-backend-service.sh"
        ).read_text(encoding="utf-8")
        self.assertIn('systemctl --user daemon-reload', script)
        self.assertIn('systemctl --user enable "${UNIT_NAME}"', script)
        self.assertIn('systemctl --user restart "${UNIT_NAME}"', script)
        self.assertIn('systemctl --user is-enabled --quiet "${UNIT_NAME}"', script)
        self.assertIn('systemctl --user is-active --quiet "${UNIT_NAME}"', script)

    def test_uninstaller_targets_only_managed_unit(self) -> None:
        script = (
            REPOSITORY_ROOT / "scripts/uninstall-backend-service.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("MANAGED_MARKER", script)
        self.assertIn('rm -f -- "${INSTALLED_UNIT}"', script)
        self.assertNotIn("rm -rf", script)


if __name__ == "__main__":
    unittest.main()
