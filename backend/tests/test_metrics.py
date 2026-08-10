from __future__ import annotations

import unittest

from ttop_backend.metrics import MetricsCollector
from ttop_backend.protocol import PROTOCOL_VERSION


class StubSampler:
    def snapshot(self) -> list[dict[str, object]]:
        return [{"pid": 7, "name": "worker"}]


class MetricsTests(unittest.TestCase):
    def test_snapshot_has_stable_top_level_shape(self) -> None:
        snapshot = MetricsCollector(StubSampler()).snapshot(timestamp=1720000000.0)
        self.assertEqual(snapshot["version"], PROTOCOL_VERSION)
        self.assertEqual(snapshot["timestamp"], 1720000000.0)
        self.assertEqual(snapshot["processes"], [{"pid": 7, "name": "worker"}])
        self.assertIsNone(snapshot["gpu"])


if __name__ == "__main__":
    unittest.main()

