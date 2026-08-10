"""Minimal read-only ctypes binding for NVIDIA's NVML shared library."""

from __future__ import annotations

import ctypes
from collections.abc import Callable
from typing import Any

from .base import GpuProvider, memory_values, percentage, temperature_celsius

NVML_LIBRARY = "libnvidia-ml.so.1"
NVML_SUCCESS = 0
NVML_TEMPERATURE_GPU = 0
NVML_DEVICE_NAME_BUFFER_SIZE = 96


class NvmlUtilization(ctypes.Structure):
    _fields_ = [("gpu", ctypes.c_uint), ("memory", ctypes.c_uint)]


class NvmlMemory(ctypes.Structure):
    _fields_ = [
        ("total", ctypes.c_ulonglong),
        ("free", ctypes.c_ulonglong),
        ("used", ctypes.c_ulonglong),
    ]


class NvidiaNvmlProvider(GpuProvider):
    """Discover NVIDIA GPUs once-initialized and sample supported metrics."""

    def __init__(
        self,
        *,
        library_loader: Callable[[str], Any] = ctypes.CDLL,
    ) -> None:
        self.library_name = NVML_LIBRARY
        self.available = False
        self.failure_reason = "library_unavailable"
        self._library: Any | None = None
        self._initialized = False
        self._shutdown_function: Any | None = None
        self._count_function: Any | None = None
        self._handle_function: Any | None = None
        self._name_function: Any | None = None
        self._utilization_function: Any | None = None
        self._memory_function: Any | None = None
        self._temperature_function: Any | None = None

        try:
            library = library_loader(NVML_LIBRARY)
        except (OSError, AttributeError):
            return
        self._library = library

        try:
            initialize = self._bind(
                ("nvmlInit_v2", "nvmlInit"),
                [],
            )
            self._shutdown_function = self._bind(("nvmlShutdown",), [])
            self._count_function = self._bind(
                ("nvmlDeviceGetCount_v2", "nvmlDeviceGetCount"),
                [ctypes.POINTER(ctypes.c_uint)],
            )
            self._handle_function = self._bind(
                ("nvmlDeviceGetHandleByIndex_v2", "nvmlDeviceGetHandleByIndex"),
                [ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p)],
            )
        except AttributeError:
            self.failure_reason = "required_symbol_unavailable"
            return

        self._name_function = self._optional_bind(
            ("nvmlDeviceGetName",),
            [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char), ctypes.c_uint],
        )
        self._utilization_function = self._optional_bind(
            ("nvmlDeviceGetUtilizationRates",),
            [ctypes.c_void_p, ctypes.POINTER(NvmlUtilization)],
        )
        self._memory_function = self._optional_bind(
            ("nvmlDeviceGetMemoryInfo",),
            [ctypes.c_void_p, ctypes.POINTER(NvmlMemory)],
        )
        self._temperature_function = self._optional_bind(
            ("nvmlDeviceGetTemperature",),
            [ctypes.c_void_p, ctypes.c_uint, ctypes.POINTER(ctypes.c_uint)],
        )

        try:
            result = initialize()
        except Exception:
            self.failure_reason = "initialization_failed"
            return
        if result != NVML_SUCCESS:
            self.failure_reason = "initialization_failed"
            return
        self._initialized = True
        self.available = True
        self.failure_reason = ""

    def _bind(self, names: tuple[str, ...], argument_types: list[Any]) -> Any:
        if self._library is None:
            raise AttributeError(names[0])
        for name in names:
            function = getattr(self._library, name, None)
            if function is not None:
                function.argtypes = argument_types
                function.restype = ctypes.c_int
                return function
        raise AttributeError(names[0])

    def _optional_bind(self, names: tuple[str, ...], argument_types: list[Any]) -> Any | None:
        try:
            return self._bind(names, argument_types)
        except AttributeError:
            return None

    def _device_count(self) -> int | None:
        if not self._initialized or self._count_function is None:
            return None
        count = ctypes.c_uint()
        try:
            result = self._count_function(ctypes.byref(count))
        except Exception:
            return None
        return int(count.value) if result == NVML_SUCCESS else None

    def _device_handle(self, index: int) -> ctypes.c_void_p | None:
        if self._handle_function is None:
            return None
        handle = ctypes.c_void_p()
        try:
            result = self._handle_function(ctypes.c_uint(index), ctypes.byref(handle))
        except Exception:
            return None
        if result != NVML_SUCCESS or not handle.value:
            return None
        return handle

    def _device_name(self, handle: ctypes.c_void_p) -> str:
        if self._name_function is None:
            return "NVIDIA GPU"
        buffer = ctypes.create_string_buffer(NVML_DEVICE_NAME_BUFFER_SIZE)
        try:
            result = self._name_function(
                handle,
                buffer,
                ctypes.c_uint(len(buffer)),
            )
        except Exception:
            return "NVIDIA GPU"
        if result != NVML_SUCCESS:
            return "NVIDIA GPU"
        name = buffer.value.decode("utf-8", errors="replace").strip()
        return name or "NVIDIA GPU"

    def _utilization(self, handle: ctypes.c_void_p) -> float | None:
        if self._utilization_function is None:
            return None
        values = NvmlUtilization()
        try:
            result = self._utilization_function(handle, ctypes.byref(values))
        except Exception:
            return None
        return percentage(values.gpu) if result == NVML_SUCCESS else None

    def _memory(self, handle: ctypes.c_void_p) -> dict[str, int | float] | None:
        if self._memory_function is None:
            return None
        values = NvmlMemory()
        try:
            result = self._memory_function(handle, ctypes.byref(values))
        except Exception:
            return None
        if result != NVML_SUCCESS:
            return None
        return memory_values(values.used, values.total)

    def _temperature(self, handle: ctypes.c_void_p) -> float | None:
        if self._temperature_function is None:
            return None
        value = ctypes.c_uint()
        try:
            result = self._temperature_function(
                handle,
                ctypes.c_uint(NVML_TEMPERATURE_GPU),
                ctypes.byref(value),
            )
        except Exception:
            return None
        return temperature_celsius(value.value) if result == NVML_SUCCESS else None

    def snapshot(self) -> list[dict[str, Any]]:
        count = self._device_count()
        if count is None or count <= 0:
            return []
        devices: list[dict[str, Any]] = []
        for index in range(count):
            handle = self._device_handle(index)
            if handle is None:
                continue
            entry: dict[str, Any] = {
                "index": index,
                "name": self._device_name(handle),
            }
            utilization = self._utilization(handle)
            if utilization is not None:
                entry["utilizationPercent"] = utilization
            memory = self._memory(handle)
            if memory is not None:
                entry.update(memory)
            temperature = self._temperature(handle)
            if temperature is not None:
                entry["temperatureCelsius"] = temperature
            devices.append(entry)
        return devices

    def shutdown(self) -> None:
        if not self._initialized or self._shutdown_function is None:
            return
        try:
            self._shutdown_function()
        except Exception:
            pass
        finally:
            self._initialized = False
            self.available = False
