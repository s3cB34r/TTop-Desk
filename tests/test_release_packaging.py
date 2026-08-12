from __future__ import annotations

import json
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class ReleasePackagingTests(unittest.TestCase):
    def test_central_version_matches_metadata(self) -> None:
        version = (REPOSITORY_ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")
        metadata = json.loads(
            (REPOSITORY_ROOT / "package/metadata.json").read_text(encoding="utf-8")
        )
        self.assertEqual(metadata["KPlugin"]["Version"], version)

    def test_release_scripts_are_repository_independent(self) -> None:
        for relative_name in ("release/install.sh", "release/uninstall.sh"):
            script = (REPOSITORY_ROOT / relative_name).read_text(encoding="utf-8")
            with self.subTest(script=relative_name):
                self.assertNotIn("/data/Projects/TTop-Desk", script)
                self.assertNotRegex(script, r"(^|[;&|]\s*)sudo(?:\s|$)")
                self.assertIn("set -euo pipefail", script)

    def test_installer_defaults_to_user_locations(self) -> None:
        script = (REPOSITORY_ROOT / "release/install.sh").read_text(encoding="utf-8")
        self.assertIn('${HOME}/.local/share', script)
        self.assertIn('${HOME}/.config', script)
        self.assertIn('${DATA_HOME}/ttop-desk', script)
        self.assertIn('${CONFIG_HOME}/systemd/user', script)
        self.assertIn('kpackagetool5 --type Plasma/Applet --upgrade', script)
        self.assertIn('systemctl --user enable "${UNIT_NAME}"', script)
        self.assertIn('systemctl --user restart "${UNIT_NAME}"', script)

    def test_uninstaller_preserves_plasma_configuration(self) -> None:
        script = (REPOSITORY_ROOT / "release/uninstall.sh").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("plasma-org.kde.plasma.desktop-appletsrc", script)
        self.assertIn('kpackagetool5 --type Plasma/Applet --remove "${PLUGIN_ID}"', script)
        self.assertIn('systemctl --user disable --now "${UNIT_NAME}"', script)


if __name__ == "__main__":
    unittest.main()
