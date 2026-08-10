"""Versioned newline-delimited JSON protocol helpers."""

from __future__ import annotations

import json
from collections.abc import Callable, Mapping
from typing import Any

PROTOCOL_VERSION = 1
MAX_REQUEST_BYTES = 4096
SUPPORTED_COMMANDS = frozenset({"ping", "snapshot"})


class ProtocolError(ValueError):
    """A client-safe protocol failure identified by a stable error code."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def error_response(code: str) -> dict[str, Any]:
    return {"status": "error", "version": PROTOCOL_VERSION, "error": code}


def parse_request(raw_request: bytes) -> str:
    """Validate one JSON request and return its explicit command."""
    if len(raw_request) > MAX_REQUEST_BYTES:
        raise ProtocolError("request_too_large")

    try:
        text = raw_request.decode("utf-8").strip()
    except UnicodeDecodeError as error:
        raise ProtocolError("invalid_encoding") from error

    if not text:
        raise ProtocolError("empty_request")

    try:
        request = json.loads(text)
    except json.JSONDecodeError as error:
        raise ProtocolError("malformed_json") from error

    if not isinstance(request, dict):
        raise ProtocolError("invalid_request")
    if set(request) != {"command"} or not isinstance(request["command"], str):
        raise ProtocolError("invalid_request")

    command = request["command"]
    if command not in SUPPORTED_COMMANDS:
        raise ProtocolError("unsupported_command")
    return command


def handle_request(
    raw_request: bytes,
    snapshot_factory: Callable[[], Mapping[str, Any]],
) -> dict[str, Any]:
    """Dispatch a validated request without dynamic attribute lookup."""
    try:
        command = parse_request(raw_request)
        if command == "ping":
            return {"status": "ok", "version": PROTOCOL_VERSION}
        if command == "snapshot":
            response = dict(snapshot_factory())
            response["version"] = PROTOCOL_VERSION
            return response
    except ProtocolError as error:
        return error_response(error.code)
    except Exception:
        # Internal details are intentionally never returned to a client.
        return error_response("internal_error")

    return error_response("unsupported_command")


def encode_response(response: Mapping[str, Any]) -> bytes:
    """Encode one compact NDJSON response."""
    return (json.dumps(response, separators=(",", ":"), allow_nan=False) + "\n").encode(
        "utf-8"
    )

