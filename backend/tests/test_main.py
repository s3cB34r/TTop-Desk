from __future__ import annotations

import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from ttop_backend.main import default_socket_path, remove_stale_socket


class SocketPathTests(unittest.TestCase):
    def test_runtime_directory_is_preferred(self) -> None:
        path = default_socket_path({"XDG_RUNTIME_DIR": "/run/user/123"}, home=Path("/home/x"))
        self.assertEqual(path, Path("/run/user/123/ttop-desk.sock"))

    def test_cache_fallback_is_used_without_runtime_directory(self) -> None:
        path = default_socket_path({}, home=Path("/home/x"))
        self.assertEqual(path, Path("/home/x/.cache/ttop-desk/ttop-desk.sock"))

    def test_regular_file_is_never_removed_as_stale_socket(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ttop-desk.sock"
            path.write_text("keep", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "non-socket"):
                remove_stale_socket(path)
            self.assertTrue(path.exists())

    def test_owned_socket_can_be_removed(self) -> None:
        path = Path("/tmp/owned-ttop-desk.sock")
        details = mock.Mock(st_mode=stat.S_IFSOCK | 0o600, st_uid=os.getuid())
        with mock.patch.object(Path, "lstat", return_value=details), mock.patch.object(
            Path, "unlink"
        ) as unlink, mock.patch("os.getuid", return_value=os.getuid()):
            remove_stale_socket(path)
        unlink.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
