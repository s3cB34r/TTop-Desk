"""Top-level backend metric snapshot composition."""

from __future__ import annotations

import time
from typing import Any

from .gpu import GpuProvider, create_gpu_provider
from .processes import ProcessSampler, sort_process_entries
from .protocol import PROTOCOL_VERSION


class MetricsCollector:
    def __init__(
        self,
        process_sampler: ProcessSampler | None = None,
        gpu_provider: GpuProvider | None = None,
    ) -> None:
        self.process_sampler = process_sampler or ProcessSampler()
        self.gpu_provider = gpu_provider if gpu_provider is not None else create_gpu_provider()

    def snapshot(self, *, timestamp: float | None = None) -> dict[str, Any]:
        return {
            "version": PROTOCOL_VERSION,
            "timestamp": time.time() if timestamp is None else float(timestamp),
            "processes": self.process_sampler.snapshot(),
            "gpu": None,
        }

    def processes(
        self,
        sort_by: str,
        limit: int,
        *,
        timestamp: float | None = None,
    ) -> dict[str, Any]:
        sampled_entries = self.process_sampler.snapshot(sort_by=sort_by)
        entries = sort_process_entries(sampled_entries, sort_by)
        return {
            "status": "ok",
            "version": PROTOCOL_VERSION,
            "timestamp": time.time() if timestamp is None else float(timestamp),
            "sort": sort_by,
            "limit": limit,
            "processes": entries[:limit],
        }

    def gpu(self, *, timestamp: float | None = None) -> dict[str, Any]:
        try:
            entries = self.gpu_provider.snapshot()
        except Exception:
            entries = []
        return {
            "status": "ok",
            "version": PROTOCOL_VERSION,
            "timestamp": time.time() if timestamp is None else float(timestamp),
            "gpus": entries,
        }

    def close(self) -> None:
        try:
            self.gpu_provider.shutdown()
        except Exception:
            pass
