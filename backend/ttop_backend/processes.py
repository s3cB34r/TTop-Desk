"""Privacy-conscious process sampling and normalization."""

from __future__ import annotations

import math
import os
import time
from dataclasses import dataclass
from typing import Any, Protocol

import psutil

DEFAULT_PROCESS_LIMIT = 512
MAX_PROCESS_LIMIT = 512
MAX_TRACKED_PROCESSES = 4096


class Clock(Protocol):
    def __call__(self) -> float: ...


@dataclass(frozen=True)
class CpuSample:
    create_time: float
    sampled_at: float
    cpu_time: float


def _finite_nonnegative(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(number) or number < 0:
        return None
    return number


def normalize_process(
    process: Any,
    *,
    cpu_percent: float | None = None,
) -> dict[str, Any] | None:
    """Build the public process shape without querying private attributes."""
    info = getattr(process, "info", {}) or {}
    try:
        pid = int(info.get("pid", process.pid))
    except (AttributeError, TypeError, ValueError):
        return None
    if pid <= 0:
        return None

    entry: dict[str, Any] = {"pid": pid}

    name = info.get("name")
    if isinstance(name, str):
        name = name.strip()
        if name and "\x00" not in name and len(name) <= 256:
            # A provider returning a path is reduced to a basename. The backend
            # never requests exe(), cmdline(), cwd(), environ(), or open files.
            entry["name"] = os.path.basename(name.replace("\\", "/"))

    username = info.get("username")
    if isinstance(username, str):
        username = username.strip()
        if username and "\x00" not in username and len(username) <= 256:
            entry["username"] = username

    try:
        rss = _finite_nonnegative(process.memory_info().rss)
    except (psutil.Error, AttributeError, OSError):
        rss = None
    if rss is not None:
        entry["memoryBytes"] = int(rss)

    normalized_cpu = _finite_nonnegative(cpu_percent)
    if normalized_cpu is not None:
        entry["cpuPercent"] = normalized_cpu

    return entry


def sort_process_entries(
    entries: list[dict[str, Any]],
    sort_by: str,
) -> list[dict[str, Any]]:
    """Return a deterministic metric-descending copy of normalized entries."""
    metric = "cpuPercent" if sort_by == "cpu" else "memoryBytes"
    return sorted(
        entries,
        key=lambda entry: (
            -float(entry.get(metric, -1.0)),
            str(entry.get("name", "")),
            int(entry["pid"]),
        ),
    )


class ProcessSampler:
    """Maintain bounded CPU delta state between snapshot requests."""

    def __init__(
        self,
        *,
        limit: int = DEFAULT_PROCESS_LIMIT,
        psutil_module: Any = psutil,
        clock: Clock = time.monotonic,
    ) -> None:
        self.limit = max(1, min(int(limit), MAX_PROCESS_LIMIT))
        self._psutil = psutil_module
        self._clock = clock
        self._previous: dict[int, CpuSample] = {}

    @staticmethod
    def _process_cpu_time(process: Any) -> float | None:
        try:
            times = process.cpu_times()
            user = _finite_nonnegative(times.user)
            system = _finite_nonnegative(times.system)
        except (psutil.Error, AttributeError, OSError):
            return None
        if user is None or system is None:
            return None
        return user + system

    @staticmethod
    def _creation_time(process: Any) -> float | None:
        info = getattr(process, "info", {}) or {}
        value = _finite_nonnegative(info.get("create_time"))
        return value

    def snapshot(self, *, sort_by: str | None = None) -> list[dict[str, Any]]:
        sampled_at = self._clock()
        next_state: dict[int, CpuSample] = {}
        entries: list[dict[str, Any]] = []

        attributes = ["pid", "name", "username", "create_time"]
        for index, process in enumerate(self._psutil.process_iter(attrs=attributes)):
            if index >= MAX_TRACKED_PROCESSES:
                break

            info = getattr(process, "info", {}) or {}
            try:
                pid = int(info.get("pid", process.pid))
            except (AttributeError, TypeError, ValueError):
                continue
            create_time = self._creation_time(process)
            cpu_time = self._process_cpu_time(process)
            cpu_percent: float | None = None

            if create_time is not None and cpu_time is not None:
                previous = self._previous.get(pid)
                if previous is not None and previous.create_time == create_time:
                    elapsed = sampled_at - previous.sampled_at
                    cpu_delta = cpu_time - previous.cpu_time
                    if elapsed > 0 and cpu_delta >= 0:
                        cpu_percent = (cpu_delta / elapsed) * 100.0
                next_state[pid] = CpuSample(create_time, sampled_at, cpu_time)

            try:
                entry = normalize_process(process, cpu_percent=cpu_percent)
            except (self._psutil.NoSuchProcess, self._psutil.AccessDenied, self._psutil.ZombieProcess):
                continue
            if entry is not None:
                entries.append(entry)

        self._previous = next_state
        if sort_by is None:
            # Preserve the original protocol-v1 snapshot ordering.
            entries.sort(
                key=lambda entry: (
                    -float(entry.get("cpuPercent", -1.0)),
                    -int(entry.get("memoryBytes", -1)),
                    int(entry["pid"]),
                )
            )
        else:
            entries = sort_process_entries(entries, sort_by)
        return entries[: self.limit]
