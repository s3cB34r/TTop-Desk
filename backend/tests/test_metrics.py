from __future__ import annotations

import unittest

from ttop_backend.metrics import MetricsCollector
from ttop_backend.protocol import PROTOCOL_VERSION


class StubSampler:
    def snapshot(self, *, sort_by: str | None = None) -> list[dict[str, object]]:
        del sort_by
        return [{"pid": 7, "name": "worker"}]


class SortSampler:
    def snapshot(self, *, sort_by: str | None = None) -> list[dict[str, object]]:
        del sort_by
        return [
            {"pid": 8, "name": "zeta", "cpuPercent": 2.0, "memoryBytes": 500},
            {"pid": 5, "name": "alpha", "cpuPercent": 10.0, "memoryBytes": 100},
            {"pid": 2, "name": "alpha", "cpuPercent": 10.0, "memoryBytes": 200},
            {"pid": 3, "name": "beta", "cpuPercent": 1.0, "memoryBytes": 900},
        ]


class MetricsTests(unittest.TestCase):
    def test_snapshot_has_stable_top_level_shape(self) -> None:
        snapshot = MetricsCollector(StubSampler()).snapshot(timestamp=1720000000.0)
        self.assertEqual(snapshot["version"], PROTOCOL_VERSION)
        self.assertEqual(snapshot["timestamp"], 1720000000.0)
        self.assertEqual(snapshot["processes"], [{"pid": 7, "name": "worker"}])
        self.assertIsNone(snapshot["gpu"])

    def test_cpu_process_response_is_bounded_and_deterministic(self) -> None:
        response = MetricsCollector(SortSampler()).processes(
            "cpu", 3, timestamp=1720000000.0
        )
        self.assertEqual(response["status"], "ok")
        self.assertEqual(response["version"], PROTOCOL_VERSION)
        self.assertEqual(response["sort"], "cpu")
        self.assertEqual(response["limit"], 3)
        self.assertEqual([entry["pid"] for entry in response["processes"]], [2, 5, 8])

    def test_memory_process_response_is_sorted_descending(self) -> None:
        response = MetricsCollector(SortSampler()).processes(
            "memory", 2, timestamp=1720000000.0
        )
        self.assertEqual([entry["pid"] for entry in response["processes"]], [3, 8])


if __name__ == "__main__":
    unittest.main()
