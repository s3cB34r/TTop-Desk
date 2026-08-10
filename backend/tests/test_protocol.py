from __future__ import annotations

import json
import unittest

from ttop_backend.protocol import (
    MAX_REQUEST_BYTES,
    PROTOCOL_VERSION,
    encode_response,
    handle_request,
    parse_request,
)


class ProtocolTests(unittest.TestCase):
    def test_parses_supported_command(self) -> None:
        self.assertEqual(parse_request(b'{"command":"ping"}').command, "ping")

    def test_ping_is_versioned(self) -> None:
        response = handle_request(b'{"command":"ping"}', lambda: {})
        self.assertEqual(response, {"status": "ok", "version": PROTOCOL_VERSION})

    def test_snapshot_is_versioned(self) -> None:
        response = handle_request(
            b'{"command":"snapshot"}',
            lambda: {"timestamp": 1.0, "processes": [], "gpu": None},
        )
        self.assertEqual(response["version"], PROTOCOL_VERSION)

    def test_processes_uses_default_sort_and_limit(self) -> None:
        received: list[tuple[str, int]] = []

        def processes(sort_by: str, limit: int):
            received.append((sort_by, limit))
            return {"status": "ok", "processes": []}

        response = handle_request(
            b'{"command":"processes"}', lambda: {}, processes
        )
        self.assertEqual(received, [("cpu", 5)])
        self.assertEqual(response["version"], PROTOCOL_VERSION)

    def test_processes_accepts_explicit_and_maximum_limit(self) -> None:
        request = parse_request(
            b'{"command":"processes","sort":"memory","limit":20}'
        )
        self.assertEqual((request.sort, request.limit), ("memory", 20))

    def test_processes_rejects_invalid_limits(self) -> None:
        for value in (0, 21, -1, 5.0, True, "5", None):
            raw = json.dumps({"command": "processes", "limit": value}).encode()
            with self.subTest(value=value):
                response = handle_request(raw, lambda: {}, lambda _sort, _limit: {})
                self.assertEqual(response["error"], "invalid_limit")
                self.assertEqual(response["version"], PROTOCOL_VERSION)

    def test_processes_rejects_unsupported_sort(self) -> None:
        response = handle_request(
            b'{"command":"processes","sort":"pid"}',
            lambda: {},
            lambda _sort, _limit: {},
        )
        self.assertEqual(response["error"], "invalid_sort")

    def test_processes_rejects_unknown_properties(self) -> None:
        response = handle_request(
            b'{"command":"processes","limit":5,"action":"kill"}',
            lambda: {},
            lambda _sort, _limit: {},
        )
        self.assertEqual(response["error"], "invalid_request")

    def test_gpu_command_is_versioned(self) -> None:
        response = handle_request(
            b'{"command":"gpu"}',
            lambda: {},
            None,
            lambda: {"status": "ok", "gpus": [{"index": 0}]},
        )
        self.assertEqual(response["status"], "ok")
        self.assertEqual(response["version"], PROTOCOL_VERSION)
        self.assertEqual(response["gpus"], [{"index": 0}])

    def test_gpu_rejects_extra_properties(self) -> None:
        response = handle_request(
            b'{"command":"gpu","index":0}', lambda: {}, None, lambda: {}
        )
        self.assertEqual(response["error"], "invalid_request")

    def test_malformed_json_is_safe(self) -> None:
        response = handle_request(b"{broken", lambda: {})
        self.assertEqual(response["status"], "error")
        self.assertEqual(response["error"], "malformed_json")
        self.assertNotIn("traceback", json.dumps(response).lower())

    def test_unknown_command_is_rejected(self) -> None:
        response = handle_request(b'{"command":"delete"}', lambda: {})
        self.assertEqual(response["error"], "unsupported_command")
        self.assertEqual(response["version"], PROTOCOL_VERSION)

    def test_extra_properties_are_rejected(self) -> None:
        response = handle_request(b'{"command":"ping","value":1}', lambda: {})
        self.assertEqual(response["error"], "invalid_request")

    def test_oversized_request_is_rejected(self) -> None:
        response = handle_request(b"x" * (MAX_REQUEST_BYTES + 1), lambda: {})
        self.assertEqual(response["error"], "request_too_large")

    def test_response_is_newline_delimited_json(self) -> None:
        encoded = encode_response({"status": "ok", "version": PROTOCOL_VERSION})
        self.assertTrue(encoded.endswith(b"\n"))
        self.assertEqual(json.loads(encoded), {"status": "ok", "version": 1})


if __name__ == "__main__":
    unittest.main()
