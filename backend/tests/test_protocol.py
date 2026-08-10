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
        self.assertEqual(parse_request(b'{"command":"ping"}'), "ping")

    def test_ping_is_versioned(self) -> None:
        response = handle_request(b'{"command":"ping"}', lambda: {})
        self.assertEqual(response, {"status": "ok", "version": PROTOCOL_VERSION})

    def test_snapshot_is_versioned(self) -> None:
        response = handle_request(
            b'{"command":"snapshot"}',
            lambda: {"timestamp": 1.0, "processes": [], "gpu": None},
        )
        self.assertEqual(response["version"], PROTOCOL_VERSION)

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

