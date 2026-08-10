"""Top-level backend metric snapshot composition."""

from __future__ import annotations

import time
from typing import Any

from .processes import ProcessSampler
from .protocol import PROTOCOL_VERSION


class MetricsCollector:
    def __init__(self, process_sampler: ProcessSampler | None = None) -> None:
        self.process_sampler = process_sampler or ProcessSampler()

    def snapshot(self, *, timestamp: float | None = None) -> dict[str, Any]:
        return {
            "version": PROTOCOL_VERSION,
            "timestamp": time.time() if timestamp is None else float(timestamp),
            "processes": self.process_sampler.snapshot(),
            "gpu": None,
        }

