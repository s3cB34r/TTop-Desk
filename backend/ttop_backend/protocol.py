"""Versioned newline-delimited JSON protocol helpers."""

from __future__ import annotations

import json
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import Any

PROTOCOL_VERSION = 1
MAX_REQUEST_BYTES = 4096
SUPPORTED_COMMANDS = frozenset({"ping", "snapshot", "processes"})
PROCESS_SORT_VALUES = frozenset({"cpu", "memory"})
DEFAULT_PROCESS_SORT = "cpu"
DEFAULT_PROCESS_LIMIT = 5
MIN_PROCESS_LIMIT = 1
MAX_PROCESS_LIMIT = 20


@dataclass(frozen=True)
class Request:
    command: str
    sort: str = DEFAULT_PROCESS_SORT
    limit: int = DEFAULT_PROCESS_LIMIT


class ProtocolError(ValueError):
    """A client-safe protocol failure identified by a stable error code."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def error_response(code: str) -> dict[str, Any]:
    return {"status": "error", "version": PROTOCOL_VERSION, "error": code}


def parse_request(raw_request: bytes) -> Request:
    """Validate one JSON request and return its bounded command parameters."""
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
    if not isinstance(request.get("command"), str):
        raise ProtocolError("invalid_request")

    command = request["command"]
    if command not in SUPPORTED_COMMANDS:
        raise ProtocolError("unsupported_command")
    if command in {"ping", "snapshot"}:
        if set(request) != {"command"}:
            raise ProtocolError("invalid_request")
        return Request(command)

    if not set(request).issubset({"command", "sort", "limit"}):
        raise ProtocolError("invalid_request")
    sort_value = request.get("sort", DEFAULT_PROCESS_SORT)
    if not isinstance(sort_value, str) or sort_value not in PROCESS_SORT_VALUES:
        raise ProtocolError("invalid_sort")
    limit = request.get("limit", DEFAULT_PROCESS_LIMIT)
    if (
        isinstance(limit, bool)
        or not isinstance(limit, int)
        or limit < MIN_PROCESS_LIMIT
        or limit > MAX_PROCESS_LIMIT
    ):
        raise ProtocolError("invalid_limit")
    return Request(command, sort_value, limit)


def handle_request(
    raw_request: bytes,
    snapshot_factory: Callable[[], Mapping[str, Any]],
    processes_factory: Callable[[str, int], Mapping[str, Any]] | None = None,
) -> dict[str, Any]:
    """Dispatch a validated request without dynamic attribute lookup."""
    try:
        request = parse_request(raw_request)
        if request.command == "ping":
            return {"status": "ok", "version": PROTOCOL_VERSION}
        if request.command == "snapshot":
            response = dict(snapshot_factory())
            response["version"] = PROTOCOL_VERSION
            return response
        if request.command == "processes":
            if processes_factory is None:
                return error_response("unsupported_command")
            response = dict(processes_factory(request.sort, request.limit))
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
