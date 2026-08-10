# TTop Desk local backend

This directory contains the minimal local backend foundation for metrics that
KDE Plasma 5 cannot expose directly. Current CPU, RAM, network, temperature,
filesystem, and disk-I/O metrics remain Plasma-native. Milestone 1.9 connects
the backend's process snapshot to the full widget through a persistent
in-process Qt `QLocalSocket` bridge; the backend is still started manually.

## Architecture

- `ttop_backend.main` owns one synchronous Unix-domain socket server.
- `ttop_backend.protocol` validates and encodes versioned NDJSON messages.
- `ttop_backend.metrics` composes stable top-level snapshots.
- `ttop_backend.processes` samples and normalizes bounded psutil process data.

GPU data is reserved as `null`; this milestone does not implement GPU support.
At most 512 normalized processes are returned. There is no persistent history
or database. CPU deltas retain only the immediately previous observation for
currently present PIDs.

## Socket and protocol

The default socket is `$XDG_RUNTIME_DIR/ttop-desk.sock`. If
`XDG_RUNTIME_DIR` is unavailable, the fallback is
`$HOME/.cache/ttop-desk/ttop-desk.sock`. `--socket PATH` overrides both.

Requests and responses are one-line UTF-8 JSON documents. Protocol version 1
supports only two exact commands:

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

The widget requests the existing `{"command":"snapshot"}` response every two
seconds by default, selects at most five CPU-ranked entries, and discards
`username` before exposing its QML model. A stopped backend clears process rows
and changes only that section to `Backend unavailable`; reconnect attempts use
a five-second backoff. No process action is supported.
