"""Optional GPU provider selection."""

from __future__ import annotations

from .base import GpuProvider
from .nvidia import NvidiaNvmlProvider


def create_gpu_provider() -> GpuProvider:
    """Return the first supported provider; NVIDIA is the only provider today."""
    return NvidiaNvmlProvider()


__all__ = ["GpuProvider", "NvidiaNvmlProvider", "create_gpu_provider"]
