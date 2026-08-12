#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="io.github.s3cb34r.ttopdesk"
UNIT_NAME="ttop-desk-backend.service"
CATALOG_NAME="plasma_applet_io.github.s3cb34r.ttopdesk.mo"
RELEASE_MARKER="# Managed by TTop Desk release installer."
DEVELOPMENT_MARKER="# Managed by TTop Desk development service installer."
DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
BACKEND_PARENT="${DATA_HOME}/ttop-desk"
BACKEND_DIRECTORY="${BACKEND_PARENT}/backend"
INSTALLED_UNIT="${CONFIG_HOME}/systemd/user/${UNIT_NAME}"
CATALOG_DESTINATION="${DATA_HOME}/locale/de/LC_MESSAGES/${CATALOG_NAME}"

pass() { printf 'PASS: %s\n' "$1"; }
warn() { printf 'WARN: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

for command_name in kpackagetool5 systemctl; do
    command -v "${command_name}" >/dev/null 2>&1 \
        || fail "Required dependency missing: ${command_name}"
done

if [[ -e "${INSTALLED_UNIT}" ]] \
        && ! grep -Fqx "${RELEASE_MARKER}" "${INSTALLED_UNIT}" \
        && ! grep -Fqx "${DEVELOPMENT_MARKER}" "${INSTALLED_UNIT}"; then
    fail "Refusing to remove unmanaged service unit: ${INSTALLED_UNIT}"
fi

if [[ -e "${INSTALLED_UNIT}" ]]; then
    systemctl --user disable --now "${UNIT_NAME}" || \
        warn "Service was already inactive or could not be disabled"
    rm -f -- "${INSTALLED_UNIT}"
    systemctl --user daemon-reload
    systemctl --user reset-failed "${UNIT_NAME}" >/dev/null 2>&1 || true
    pass "Backend user service removed"
else
    warn "Backend user service was not installed"
fi

EXPECTED_BACKEND="${DATA_HOME}/ttop-desk/backend"
[[ "${BACKEND_DIRECTORY}" == "${EXPECTED_BACKEND}" && -n "${DATA_HOME}" ]] \
    || fail "Refusing to remove an unexpected backend path"
if [[ -d "${BACKEND_DIRECTORY}" ]]; then
    rm -rf -- "${BACKEND_DIRECTORY}"
    rmdir -- "${BACKEND_PARENT}" 2>/dev/null || true
    pass "Backend files removed"
else
    warn "Backend files were not installed"
fi

if [[ -f "${CATALOG_DESTINATION}" ]]; then
    rm -f -- "${CATALOG_DESTINATION}"
    rmdir -- "$(dirname -- "${CATALOG_DESTINATION}")" 2>/dev/null || true
    pass "TTop Desk translation catalog removed"
fi

if kpackagetool5 --type Plasma/Applet --show "${PLUGIN_ID}" >/dev/null 2>&1; then
    kpackagetool5 --type Plasma/Applet --remove "${PLUGIN_ID}"
    pass "Plasma widget removed"
else
    warn "Plasma widget was not installed"
fi

printf '\nTTop Desk runtime files were removed.\n'
printf '%s\n' \
    'Plasma widget configuration was intentionally preserved.' \
    'Remove any remaining TTop Desk instance from the desktop manually if needed.'
