#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

"${SCRIPT_DIR}/build-bridge.sh"

exec plasmoidviewer -a "${REPOSITORY_ROOT}/package"
