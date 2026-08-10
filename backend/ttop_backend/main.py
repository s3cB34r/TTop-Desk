"""Unix-domain socket server for the local TTop Desk backend."""

from __future__ import annotations

import argparse
import errno
import logging
import os
import signal
import socket
import stat
import struct
import threading
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .metrics import MetricsCollector
from .protocol import MAX_REQUEST_BYTES, encode_response, error_response, handle_request

LOGGER = logging.getLogger("ttop_backend")


def default_socket_path(
    environment: Mapping[str, str] | None = None,
    *,
    home: Path | None = None,
) -> Path:
    env = os.environ if environment is None else environment
    runtime_dir = env.get("XDG_RUNTIME_DIR", "").strip()
    if runtime_dir:
        return Path(runtime_dir) / "ttop-desk.sock"
    home_dir = home if home is not None else Path.home()
    return home_dir / ".cache" / "ttop-desk" / "ttop-desk.sock"


def resolve_socket_path(explicit_path: str | None) -> Path:
    if explicit_path:
        return Path(explicit_path).expanduser()
    return default_socket_path()


def prepare_socket_parent(path: Path) -> None:
    parent = path.parent
    parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not parent.is_dir():
        raise RuntimeError("socket parent is not a directory")


def remove_stale_socket(path: Path) -> None:
    try:
        details = path.lstat()
    except FileNotFoundError:
        return
    if not stat.S_ISSOCK(details.st_mode):
        raise RuntimeError("refusing to replace a non-socket path")
    if details.st_uid != os.getuid():
        raise RuntimeError("refusing to remove a socket owned by another user")

    probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    probe.settimeout(0.25)
    try:
        probe.connect(str(path))
    except OSError as error:
        if error.errno not in {errno.ECONNREFUSED, errno.ENOENT}:
            raise RuntimeError("refusing to replace a socket whose state is uncertain") from error
    else:
        raise RuntimeError("backend socket is already active")
    finally:
        probe.close()
    path.unlink()


def remove_owned_socket(path: Path) -> None:
    try:
        details = path.lstat()
    except FileNotFoundError:
        return
    if stat.S_ISSOCK(details.st_mode) and details.st_uid == os.getuid():
        path.unlink()


class BackendServer:
    def __init__(self, socket_path: Path, *, debug: bool = False) -> None:
        self.socket_path = socket_path
        self.debug = debug
        self.collector = MetricsCollector()
        self._stop_event = threading.Event()
        self._socket: socket.socket | None = None

    @staticmethod
    def _peer_is_current_user(connection: socket.socket) -> bool:
        if not hasattr(socket, "SO_PEERCRED"):
            return True
        credentials = connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
        _pid, uid, _gid = struct.unpack("3i", credentials)
        return uid == os.getuid()

    @staticmethod
    def _read_request(connection: socket.socket) -> bytes:
        request = bytearray()
        while len(request) <= MAX_REQUEST_BYTES:
            try:
                chunk = connection.recv(min(1024, MAX_REQUEST_BYTES + 1 - len(request)))
            except socket.timeout:
                return bytes(request)
            if not chunk:
                break
            request.extend(chunk)
            newline = request.find(b"\n")
            if newline >= 0:
                return bytes(request[:newline])
        return bytes(request)

    def stop(self) -> None:
        self._stop_event.set()

    def _serve_client(self, connection: socket.socket) -> None:
        connection.settimeout(5.0)
        if not self._peer_is_current_user(connection):
            LOGGER.warning("Rejected connection from a different local user")
            connection.sendall(encode_response(error_response("permission_denied")))
            return

        LOGGER.debug("Client connected")
        request = self._read_request(connection)
        command_for_log = "invalid"
        if len(request) <= MAX_REQUEST_BYTES:
            if b'"ping"' in request:
                command_for_log = "ping"
            elif b'"snapshot"' in request:
                command_for_log = "snapshot"
            elif b'"processes"' in request:
                command_for_log = "processes"
            elif b'"gpu"' in request:
                command_for_log = "gpu"
        LOGGER.debug("Command received: %s", command_for_log)
        response = handle_request(
            request,
            self.collector.snapshot,
            self.collector.processes,
            self.collector.gpu,
        )
        if response.get("error") == "internal_error":
            LOGGER.error("Backend request failed internally")
        if response.get("processes") is not None:
            LOGGER.debug("Normalized process count: %d", len(response["processes"]))
        if response.get("gpus") is not None:
            LOGGER.debug("Normalized GPU count: %d", len(response["gpus"]))
        connection.sendall(encode_response(response))

    def serve_forever(self) -> None:
        prepare_socket_parent(self.socket_path)
        remove_stale_socket(self.socket_path)
        server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._socket = server_socket
        try:
            server_socket.bind(str(self.socket_path))
            os.chmod(self.socket_path, 0o600)
            server_socket.listen(8)
            server_socket.settimeout(0.5)
            LOGGER.debug("Backend started")
            LOGGER.debug("Socket path: %s", self.socket_path)

            while not self._stop_event.is_set():
                try:
                    connection, _address = server_socket.accept()
                except socket.timeout:
                    continue
                except OSError:
                    if self._stop_event.is_set():
                        break
                    raise
                with connection:
                    try:
                        self._serve_client(connection)
                    except (BrokenPipeError, ConnectionError, TimeoutError, OSError):
                        LOGGER.warning("Client connection ended before completion")
        finally:
            server_socket.close()
            self._socket = None
            self.collector.close()
            remove_owned_socket(self.socket_path)
            LOGGER.debug("Backend stopped")


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run the local TTop Desk metrics backend")
    parser.add_argument("--debug", action="store_true", help="enable development logging")
    parser.add_argument("--socket", metavar="PATH", help="override the Unix socket path")
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = build_argument_parser().parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if arguments.debug else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
    )
    server = BackendServer(resolve_socket_path(arguments.socket), debug=arguments.debug)

    def request_shutdown(_signum: int, _frame: Any) -> None:
        server.stop()

    signal.signal(signal.SIGINT, request_shutdown)
    signal.signal(signal.SIGTERM, request_shutdown)
    try:
        server.serve_forever()
    except RuntimeError as error:
        LOGGER.error("%s", error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
