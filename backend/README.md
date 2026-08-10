# TTop Desk local backend

This directory contains the minimal local backend foundation for metrics that
KDE Plasma 5 cannot expose directly. Current CPU, RAM, network, temperature,
filesystem, and disk-I/O metrics remain Plasma-native. Milestone 1.9 connected
the backend's process snapshot to the full widget through a persistent
in-process Qt `QLocalSocket` bridge. Milestone 1.10 adds bounded process
requests and an optional development `systemd --user` service. Milestone 1.12
adds an optional NVIDIA NVML provider for read-only GPU metrics.

## Architecture

- `ttop_backend.main` owns one synchronous Unix-domain socket server.
- `ttop_backend.protocol` validates and encodes versioned NDJSON messages.
- `ttop_backend.metrics` composes stable top-level snapshots.
- `ttop_backend.processes` samples and normalizes bounded psutil process data.
- `ttop_backend.gpu` selects optional vendor providers; `gpu.nvidia` is a
  minimal standard-library `ctypes` binding to NVIDIA NVML.

The backwards-compatible snapshot retains its reserved `gpu: null` field; live
GPU data uses the dedicated `gpu` command.
At most 512 normalized processes are returned. There is no persistent history
or database. CPU deltas retain only the immediately previous observation for
currently present PIDs.

## Socket and protocol

The default socket is `$XDG_RUNTIME_DIR/ttop-desk.sock`. If
`XDG_RUNTIME_DIR` is unavailable, the fallback is
`$HOME/.cache/ttop-desk/ttop-desk.sock`. `--socket PATH` overrides both.

Requests and responses are one-line UTF-8 JSON documents. Protocol version 1
supports ping, backwards-compatible snapshots, and bounded process requests:

```json
{"command":"ping"}
```

```json
{"status":"ok","version":1}
```

```json
{"command":"snapshot"}
```

```json
{"version":1,"timestamp":1720000000.0,"processes":[],"gpu":null}
```

```json
{"command":"processes","sort":"cpu","limit":5}
```

```json
{"status":"ok","version":1,"timestamp":1720000000.0,"sort":"cpu","limit":5,"processes":[]}
```

`sort` defaults to `cpu` and accepts `cpu` or `memory`. `limit` defaults to 5
and must be an integer from 1 through 20. Both modes sort descending by their
metric, then deterministically by process name and PID. Invalid parameters
return `invalid_sort` or `invalid_limit`; requests are never unbounded.

```json
{"command":"gpu"}
```

```json
{"status":"ok","version":1,"timestamp":1720000000.0,"gpus":[{"index":0,"name":"NVIDIA GeForce RTX 5060 Ti","utilizationPercent":8.0,"memoryUsedBytes":2147483648,"memoryTotalBytes":8589934592,"memoryPercent":25.0,"temperatureCelsius":47.0}]}
```

The backend loads `libnvidia-ml.so.1` directly, initializes NVML once per
backend lifetime, and shuts it down on exit. It never invokes `nvidia-smi` and
does not require `pynvml`. All NVIDIA devices are represented in `gpus`; the
widget selects index 0. Missing NVML, driver failures, and zero devices return
a successful response with `gpus: []`. AMD and Intel are possible future
providers but are not implemented.

Errors are structured, for example:

```json
{"status":"error","version":1,"error":"unsupported_command"}
```

## Manual development run

From the repository root:

```bash
cd backend
python3 -m ttop_backend.main --debug
```

In another terminal:

```bash
./scripts/build-bridge.sh
plasmoidviewer -a "$(pwd)/package"
```

The development JSON client remains available separately:

```bash
python3 scripts/backend-client.py
python3 scripts/backend-client.py --gpu
```

For an isolated test socket:

```bash
cd backend
python3 -m ttop_backend.main --socket /tmp/ttop-desk-test.sock --debug
```

```bash
python3 scripts/backend-client.py --socket /tmp/ttop-desk-test.sock
```

Stop a foreground backend with `Ctrl+C`. Send `SIGTERM` using the process
manager that started it when testing managed shutdown. Normal SIGINT and
SIGTERM shutdown remove the owned socket.

## Optional systemd user service

From the repository root, install and immediately start the development unit:

```bash
./scripts/install-backend-service.sh
```

The generated unit is installed at
`~/.config/systemd/user/ttop-desk-backend.service`. It embeds the current
repository path until final packaging exists. It has no `User=` directive,
needs no `sudo`, restricts address families to `AF_UNIX`, uses `UMask=0077`,
and restarts unexpected failures after two seconds with a bounded start limit.

```bash
./scripts/backend-status.sh
systemctl --user stop ttop-desk-backend
systemctl --user start ttop-desk-backend
systemctl --user restart ttop-desk-backend
journalctl --user -u ttop-desk-backend -f
./scripts/uninstall-backend-service.sh
```

Run unit tests without a desktop session:

```bash
PYTHONPATH=backend python3 -m unittest discover -s backend/tests -v
```

## Security and privacy model

The server opens no TCP port and uses a mode `0600` Unix socket. On Linux it
also checks peer credentials and accepts only the current user. It never needs
root, executes no shell or subprocess, performs no network access, and exposes
only explicitly dispatched read-only commands. Requests are limited to 4096
bytes and malformed, oversized, or unknown requests receive stable errors
without tracebacks.

Process output may contain only `pid`, `name`, `cpuPercent`, `memoryBytes`, and
`username`. Memory is resident set size (RSS). The backend never requests full
command lines, environment variables, executable paths, working directories,
open files, or sockets. A newly observed PID has no `cpuPercent` until a second
valid CPU-time sample is available. Subsequent values are CPU-time deltas over
monotonic elapsed time and are not clamped to 100%.

The widget requests `{"command":"processes","sort":"cpu","limit":5}` every
two seconds by default. Milestone 1.11 substitutes the live configured CPU or
memory sort mode and exact visible limit of 3–5 rows. It discards `username`
before exposing its QML model.
It automatically falls back to `snapshot` when an older protocol-v1 backend
rejects the newer command. A stopped backend clears process rows
and changes only that section to `Backend unavailable`; reconnect attempts use
a five-second backoff. No process action is supported.

GPU polling uses the same QML socket bridge and defaults to one second. Hiding
the GPU section stops GPU requests. `GPU unavailable` means the backend replied
but exposed no supported device; `Backend unavailable` means the socket could
not be reached. GPU access is strictly read-only: no process, clock, fan,
power-limit, or other device-control APIs are bound.
