from __future__ import annotations

import unittest

from ttop_backend.gpu.base import memory_values, percentage, temperature_celsius
from ttop_backend.gpu.nvidia import NVML_LIBRARY, NvidiaNvmlProvider


class FakeFunction:
    def __init__(self, implementation):
        self.implementation = implementation
        self.calls = 0
        self.argtypes = None
        self.restype = None

    def __call__(self, *arguments):
        self.calls += 1
        return self.implementation(*arguments)


class FakeNvmlLibrary:
    def __init__(
        self,
        devices: list[dict[str, object]],
        *,
        initialization_result: int = 0,
    ) -> None:
        self.devices = devices
        self.nvmlInit_v2 = FakeFunction(lambda: initialization_result)
        self.nvmlShutdown = FakeFunction(lambda: 0)
        self.nvmlDeviceGetCount_v2 = FakeFunction(self._count)
        self.nvmlDeviceGetHandleByIndex_v2 = FakeFunction(self._handle)
        self.nvmlDeviceGetName = FakeFunction(self._name)
        self.nvmlDeviceGetUtilizationRates = FakeFunction(self._utilization)
        self.nvmlDeviceGetMemoryInfo = FakeFunction(self._memory)
        self.nvmlDeviceGetTemperature = FakeFunction(self._temperature)

    def _device(self, handle):
        return self.devices[int(handle.value) - 1]

    def _count(self, count_pointer):
        count_pointer._obj.value = len(self.devices)
        return 0

    def _handle(self, index, handle_pointer):
        handle_pointer._obj.value = int(index.value) + 1
        return 0

    def _name(self, handle, buffer, _length):
        name = self._device(handle).get("name")
        if name is None:
            return 1
        buffer.value = str(name).encode("utf-8")
        return 0

    def _utilization(self, handle, values_pointer):
        value = self._device(handle).get("utilization")
        if value is None:
            return 1
        values_pointer._obj.gpu = int(value)
        return 0

    def _memory(self, handle, values_pointer):
        value = self._device(handle).get("memory")
        if value is None:
            return 1
        used, total = value
        values_pointer._obj.used = int(used)
        values_pointer._obj.total = int(total)
        values_pointer._obj.free = max(0, int(total) - int(used))
        return 0

    def _temperature(self, handle, _sensor, value_pointer):
        value = self._device(handle).get("temperature")
        if value is None:
            return 1
        value_pointer._obj.value = int(value)
        return 0


class NvidiaProviderTests(unittest.TestCase):
    def test_library_unavailable_is_graceful(self) -> None:
        requested: list[str] = []

        def unavailable(name: str):
            requested.append(name)
            raise OSError("missing")

        provider = NvidiaNvmlProvider(library_loader=unavailable)
        self.assertEqual(requested, [NVML_LIBRARY])
        self.assertFalse(provider.available)
        self.assertEqual(provider.snapshot(), [])

    def test_initialization_failure_is_graceful(self) -> None:
        library = FakeNvmlLibrary([], initialization_result=9)
        provider = NvidiaNvmlProvider(library_loader=lambda _name: library)
        self.assertFalse(provider.available)
        self.assertEqual(provider.failure_reason, "initialization_failed")
        self.assertEqual(provider.snapshot(), [])
        provider.shutdown()
        self.assertEqual(library.nvmlShutdown.calls, 0)

    def test_zero_devices_returns_empty_list(self) -> None:
        provider = NvidiaNvmlProvider(
            library_loader=lambda _name: FakeNvmlLibrary([])
        )
        self.assertTrue(provider.available)
        self.assertEqual(provider.snapshot(), [])

    def test_one_device_is_fully_normalized(self) -> None:
        gibibyte = 1024**3
        library = FakeNvmlLibrary(
            [{
                "name": "  NVIDIA GeForce Test  ",
                "utilization": 12,
                "memory": (2 * gibibyte, 8 * gibibyte),
                "temperature": 47,
            }]
        )
        provider = NvidiaNvmlProvider(library_loader=lambda _name: library)
        self.assertEqual(
            provider.snapshot(),
            [{
                "index": 0,
                "name": "NVIDIA GeForce Test",
                "utilizationPercent": 12.0,
                "memoryUsedBytes": 2 * gibibyte,
                "memoryTotalBytes": 8 * gibibyte,
                "memoryPercent": 25.0,
                "temperatureCelsius": 47.0,
            }],
        )
        provider.shutdown()
        provider.shutdown()
        self.assertEqual(library.nvmlShutdown.calls, 1)

    def test_multiple_devices_preserve_indices(self) -> None:
        library = FakeNvmlLibrary([
            {"name": "GPU A", "utilization": 1},
            {"name": "GPU B", "utilization": 2},
        ])
        provider = NvidiaNvmlProvider(library_loader=lambda _name: library)
        devices = provider.snapshot()
        self.assertEqual([device["index"] for device in devices], [0, 1])
        self.assertEqual([device["name"] for device in devices], ["GPU A", "GPU B"])

    def test_partial_and_malformed_metrics_are_omitted(self) -> None:
        library = FakeNvmlLibrary([{
            "name": None,
            "utilization": 101,
            "memory": (900, 100),
            "temperature": 200,
        }])
        provider = NvidiaNvmlProvider(library_loader=lambda _name: library)
        self.assertEqual(provider.snapshot(), [{"index": 0, "name": "NVIDIA GPU"}])

    def test_missing_optional_symbol_keeps_other_metrics(self) -> None:
        library = FakeNvmlLibrary([{
            "name": "Partial GPU", "utilization": 5, "temperature": 40,
        }])
        del library.nvmlDeviceGetMemoryInfo
        provider = NvidiaNvmlProvider(library_loader=lambda _name: library)
        self.assertEqual(
            provider.snapshot(),
            [{
                "index": 0,
                "name": "Partial GPU",
                "utilizationPercent": 5.0,
                "temperatureCelsius": 40.0,
            }],
        )


class NormalizationTests(unittest.TestCase):
    def test_percentage_validation(self) -> None:
        self.assertEqual(percentage(0), 0.0)
        self.assertEqual(percentage(100), 100.0)
        self.assertIsNone(percentage(-1))
        self.assertIsNone(percentage(101))
        self.assertIsNone(percentage(float("nan")))

    def test_memory_calculation_and_validation(self) -> None:
        self.assertEqual(memory_values(25, 100)["memoryPercent"], 25.0)
        self.assertIsNone(memory_values(1, 0))
        self.assertIsNone(memory_values(101, 100))
        self.assertIsNone(memory_values("1", 100))

    def test_temperature_validation(self) -> None:
        self.assertEqual(temperature_celsius(47), 47.0)
        self.assertEqual(temperature_celsius(-20), -20.0)
        self.assertIsNone(temperature_celsius(-21))
        self.assertIsNone(temperature_celsius(151))


if __name__ == "__main__":
    unittest.main()
