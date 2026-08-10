#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
UNIT_NAME="ttop-desk-backend.service"

systemctl --user status --no-pager "${UNIT_NAME}" || true

if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    SOCKET_PATH="${XDG_RUNTIME_DIR}/ttop-desk.sock"
else
    SOCKET_PATH="${HOME}/.cache/ttop-desk/ttop-desk.sock"
fi

if [[ -S "${SOCKET_PATH}" ]]; then
    echo
    echo "Socket: ${SOCKET_PATH}"
    stat -c 'Permissions: %a  Owner: %U  Type: %F' "${SOCKET_PATH}"
    echo
    echo "Ping:"
    python3 "${REPOSITORY_ROOT}/scripts/backend-client.py" \
        --socket "${SOCKET_PATH}" --ping-only
else
    echo
    echo "Socket unavailable: ${SOCKET_PATH}"
fi

