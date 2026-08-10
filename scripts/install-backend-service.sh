#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
UNIT_NAME="ttop-desk-backend.service"
UNIT_TEMPLATE="${REPOSITORY_ROOT}/systemd/${UNIT_NAME}"
CONFIG_ROOT="${XDG_CONFIG_HOME:-${HOME}/.config}"
UNIT_DIRECTORY="${CONFIG_ROOT}/systemd/user"
INSTALLED_UNIT="${UNIT_DIRECTORY}/${UNIT_NAME}"
PYTHON_EXECUTABLE="$(command -v python3)"
MANAGED_MARKER="# Managed by TTop Desk development service installer."

if [[ ! -f "${UNIT_TEMPLATE}" ]]; then
    echo "Missing service template: ${UNIT_TEMPLATE}" >&2
    exit 1
fi
if [[ -e "${INSTALLED_UNIT}" ]] && ! grep -Fqx "${MANAGED_MARKER}" "${INSTALLED_UNIT}"; then
    echo "Refusing to overwrite unmanaged unit: ${INSTALLED_UNIT}" >&2
    exit 1
fi
if [[ "${REPOSITORY_ROOT}" == *$'\n'* || "${PYTHON_EXECUTABLE}" == *$'\n'* ]]; then
    echo "Repository and Python paths must not contain newlines" >&2
    exit 1
fi

escape_systemd_value() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//%/%%}"
    printf '%s' "${value}"
}

escape_systemd_path() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value// /\\x20}"
    value="${value//$'\t'/\\t}"
    value="${value//%/%%}"
    printf '%s' "${value}"
}

escape_sed_replacement() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//&/\\&}"
    value="${value//|/\\|}"
    printf '%s' "${value}"
}

repository_value="$(escape_sed_replacement "$(escape_systemd_path "${REPOSITORY_ROOT}")")"
python_value="$(escape_sed_replacement "$(escape_systemd_value "${PYTHON_EXECUTABLE}")")"

mkdir -p -- "${UNIT_DIRECTORY}"
temporary_unit="$(mktemp "${UNIT_DIRECTORY}/.${UNIT_NAME}.XXXXXX")"
cleanup() {
    rm -f -- "${temporary_unit}"
}
trap cleanup EXIT

sed -e "s|@REPOSITORY_ROOT@|${repository_value}|g" \
    -e "s|@PYTHON_EXECUTABLE@|${python_value}|g" \
    "${UNIT_TEMPLATE}" > "${temporary_unit}"
chmod 0644 "${temporary_unit}"
mv -f -- "${temporary_unit}" "${INSTALLED_UNIT}"
trap - EXIT

systemctl --user daemon-reload
systemctl --user enable "${UNIT_NAME}"
systemctl --user start "${UNIT_NAME}"
systemctl --user is-active --quiet "${UNIT_NAME}"

echo "Installed ${UNIT_NAME} at ${INSTALLED_UNIT}"
systemctl --user status --no-pager "${UNIT_NAME}"
