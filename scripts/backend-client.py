#!/usr/bin/env python3
"""Development-only client for the local TTop Desk backend."""

from __future__ import annotations

import argparse
import json
import os
import socket
from pathlib import Path
from typing import Any

MAX_RESPONSE_BYTES = 4 * 1024 * 1024


def default_socket_path() -> Path:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "").strip()
    if runtime_dir:
        return Path(runtime_dir) / "ttop-desk.sock"
    return Path.home() / ".cache" / "ttop-desk" / "ttop-desk.sock"


def request(socket_path: Path, command: str) -> dict[str, Any]:
    payload = json.dumps({"command": command}, separators=(",", ":")).encode("utf-8") + b"\n"
    response = bytearray()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5.0)
        client.connect(str(socket_path))
        client.sendall(payload)
        while len(response) <= MAX_RESPONSE_BYTES:
            chunk = client.recv(min(65536, MAX_RESPONSE_BYTES + 1 - len(response)))
            if not chunk:
                break
            response.extend(chunk)
            newline = response.find(b"\n")
            if newline >= 0:
                response = response[:newline]
                break
    if len(response) > MAX_RESPONSE_BYTES:
        raise RuntimeError("backend response exceeded safety limit")
    decoded = json.loads(response.decode("utf-8"))
    if not isinstance(decoded, dict):
        raise RuntimeError("backend returned an invalid response")
    return decoded


def main() -> int:
    parser = argparse.ArgumentParser(description="Query the local TTop Desk backend")
    parser.add_argument("--socket", metavar="PATH", help="override the Unix socket path")
    arguments = parser.parse_args()
    socket_path = Path(arguments.socket).expanduser() if arguments.socket else default_socket_path()

    for command in ("ping", "snapshot"):
        print(f"{command}:")
        print(json.dumps(request(socket_path, command), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

