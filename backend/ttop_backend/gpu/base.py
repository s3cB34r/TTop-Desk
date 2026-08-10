"""Provider-neutral GPU metric normalization helpers."""

from __future__ import annotations

import math
from abc import ABC, abstractmethod
from numbers import Real
from typing import Any


class GpuProvider(ABC):
    """Read-only interface implemented by optional vendor providers."""

    @abstractmethod
    def snapshot(self) -> list[dict[str, Any]]:
        """Return normalized devices without raising availability failures."""

    def shutdown(self) -> None:
        """Release provider resources. Providers without resources may ignore it."""


def finite_number(value: object) -> float | None:
    if isinstance(value, bool) or not isinstance(value, Real):
        return None
    number = float(value)
    return number if math.isfinite(number) else None


def percentage(value: object) -> float | None:
    number = finite_number(value)
    if number is None or number < 0 or number > 100:
        return None
    return number


def temperature_celsius(value: object) -> float | None:
    number = finite_number(value)
    if number is None or number < -20 or number > 150:
        return None
    return number


def memory_values(used: object, total: object) -> dict[str, int | float] | None:
    used_number = finite_number(used)
    total_number = finite_number(total)
    if (
        used_number is None
        or total_number is None
        or used_number < 0
        or total_number <= 0
        or used_number > total_number
    ):
        return None
    used_bytes = int(used_number)
    total_bytes = int(total_number)
    if total_bytes <= 0 or used_bytes < 0 or used_bytes > total_bytes:
        return None
    percent = max(0.0, min(100.0, used_bytes * 100.0 / total_bytes))
    return {
        "memoryUsedBytes": used_bytes,
        "memoryTotalBytes": total_bytes,
        "memoryPercent": percent,
    }
