#!/usr/bin/env bash
set -euo pipefail

UNIT_NAME="ttop-desk-backend.service"
CONFIG_ROOT="${XDG_CONFIG_HOME:-${HOME}/.config}"
INSTALLED_UNIT="${CONFIG_ROOT}/systemd/user/${UNIT_NAME}"
MANAGED_MARKER="# Managed by TTop Desk development service installer."

if [[ -e "${INSTALLED_UNIT}" ]] && ! grep -Fqx "${MANAGED_MARKER}" "${INSTALLED_UNIT}"; then
    echo "Refusing to remove unmanaged unit: ${INSTALLED_UNIT}" >&2
    exit 1
fi

if [[ -e "${INSTALLED_UNIT}" ]]; then
    systemctl --user disable --now "${UNIT_NAME}" || true
    rm -f -- "${INSTALLED_UNIT}"
    echo "Removed ${INSTALLED_UNIT}"
else
    echo "TTop Desk backend user service is not installed"
fi

systemctl --user daemon-reload
systemctl --user reset-failed "${UNIT_NAME}" 2>/dev/null || true

