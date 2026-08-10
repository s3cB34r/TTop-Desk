from __future__ import annotations

import types
import unittest

from ttop_backend.processes import ProcessSampler, normalize_process


class FakeProcess:
    def __init__(
        self,
        pid: int,
        *,
        name: str = "worker",
        username: str = "tester",
        create_time: float = 10.0,
        cpu_time: float = 1.0,
        rss: int = 4096,
    ) -> None:
        self.pid = pid
        self.info = {
            "pid": pid,
            "name": name,
            "username": username,
            "create_time": create_time,
        }
        self.cpu_time = cpu_time
        self.rss = rss
        self.cmdline_calls = 0

    def cpu_times(self) -> types.SimpleNamespace:
        return types.SimpleNamespace(user=self.cpu_time, system=0.0)

    def memory_info(self) -> types.SimpleNamespace:
        return types.SimpleNamespace(rss=self.rss)

    def cmdline(self) -> list[str]:
        self.cmdline_calls += 1
        raise AssertionError("cmdline must never be queried")


class FakePsutil:
    class NoSuchProcess(Exception):
        pass

    class AccessDenied(Exception):
        pass

    class ZombieProcess(Exception):
        pass

    def __init__(self, processes: list[FakeProcess]) -> None:
        self.processes = processes

    def process_iter(self, *, attrs: list[str]):
        self.requested_attrs = attrs
        return iter(self.processes)


class MutableClock:
    def __init__(self, value: float) -> None:
        self.value = value

    def __call__(self) -> float:
        return self.value


class ProcessTests(unittest.TestCase):
    def test_normalization_exposes_only_public_shape(self) -> None:
        process = FakeProcess(42, name="/usr/bin/example", rss=8192)
        entry = normalize_process(process, cpu_percent=12.5)
        self.assertEqual(
            entry,
            {
                "pid": 42,
                "name": "example",
                "cpuPercent": 12.5,
                "memoryBytes": 8192,
                "username": "tester",
            },
        )
        self.assertNotIn("cmdline", entry)
        self.assertNotIn("exe", entry)
        self.assertNotIn("cwd", entry)
        self.assertEqual(process.cmdline_calls, 0)

    def test_first_cpu_sample_is_omitted_then_delta_is_reported(self) -> None:
        process = FakeProcess(42, cpu_time=2.0)
        fake_psutil = FakePsutil([process])
        clock = MutableClock(100.0)
        sampler = ProcessSampler(psutil_module=fake_psutil, clock=clock)

        first = sampler.snapshot()
        self.assertNotIn("cpuPercent", first[0])

        process.cpu_time = 3.0
        clock.value = 102.0
        second = sampler.snapshot()
        self.assertAlmostEqual(second[0]["cpuPercent"], 50.0)
        self.assertNotIn("cmdline", fake_psutil.requested_attrs)

    def test_pid_reuse_requires_a_new_warmup(self) -> None:
        process = FakeProcess(42, create_time=10.0)
        clock = MutableClock(100.0)
        sampler = ProcessSampler(psutil_module=FakePsutil([process]), clock=clock)
        sampler.snapshot()

        process.info["create_time"] = 20.0
        process.cpu_time = 4.0
        clock.value = 102.0
        entry = sampler.snapshot()[0]
        self.assertNotIn("cpuPercent", entry)

    def test_limit_is_bounded_and_sorted(self) -> None:
        processes = [FakeProcess(pid, rss=pid * 100) for pid in range(1, 6)]
        sampler = ProcessSampler(limit=2, psutil_module=FakePsutil(processes))
        entries = sampler.snapshot()
        self.assertEqual([entry["pid"] for entry in entries], [5, 4])
        self.assertEqual(len(entries), 2)


if __name__ == "__main__":
    unittest.main()

