#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
PLUGIN_ID="io.github.s3cb34r.ttopdesk"
UNIT_NAME="ttop-desk-backend.service"
CATALOG_NAME="plasma_applet_io.github.s3cb34r.ttopdesk.mo"
RELEASE_MARKER="# Managed by TTop Desk release installer."
DEVELOPMENT_MARKER="# Managed by TTop Desk development service installer."

pass() { printf 'PASS: %s\n' "$1"; }
warn() { printf 'WARN: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

[[ -f "${VERSION_FILE}" ]] || fail "Missing VERSION next to installer"
VERSION="$(<"${VERSION_FILE}")"
[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "VERSION must contain one semantic version"

PLASMOID_ARTIFACT="${SCRIPT_DIR}/ttop-desk-${VERSION}.plasmoid"
BACKEND_ARTIFACT="${SCRIPT_DIR}/ttop-desk-backend-${VERSION}.tar.gz"
CATALOG_SOURCE="${SCRIPT_DIR}/locale/de/LC_MESSAGES/${CATALOG_NAME}"
CHECKSUM_FILE="${SCRIPT_DIR}/SHA256SUMS"

for required_file in "${PLASMOID_ARTIFACT}" "${BACKEND_ARTIFACT}" \
        "${CATALOG_SOURCE}" "${CHECKSUM_FILE}"; do
    [[ -f "${required_file}" ]] || fail "Missing release payload: ${required_file}"
done

for command_name in kpackagetool5 plasmashell python3 systemctl tar sha256sum; do
    command -v "${command_name}" >/dev/null 2>&1 \
        || fail "Required dependency missing: ${command_name}"
done
pass "Required commands are available"

PLASMA_VERSION="$(plasmashell --version 2>/dev/null || true)"
[[ "${PLASMA_VERSION}" =~ [[:space:]]5\. ]] \
    || fail "KDE Plasma 5 is required; detected: ${PLASMA_VERSION:-unknown}"
pass "KDE Plasma 5 detected (${PLASMA_VERSION})"

PYTHON_EXECUTABLE="$(command -v python3)"
"${PYTHON_EXECUTABLE}" -c 'import psutil' >/dev/null 2>&1 \
    || fail "Required Python dependency missing: psutil"
pass "Python 3 and psutil are available"

systemctl --user show-environment >/dev/null 2>&1 \
    || fail "A working systemd user session is required"
pass "systemd user session is available"

if "${PYTHON_EXECUTABLE}" -c \
        'import ctypes; ctypes.CDLL("libnvidia-ml.so.1")' >/dev/null 2>&1; then
    pass "Optional NVIDIA NVML library is available"
else
    warn "Optional NVIDIA NVML library is unavailable; GPU metrics will be unavailable"
fi

if ! (cd -- "${SCRIPT_DIR}" && sha256sum --check --strict --quiet SHA256SUMS); then
    fail "Release payload checksum validation failed"
fi
pass "Release payload checksums are valid"

if kpackagetool5 --type Plasma/Applet --show "${PLUGIN_ID}" >/dev/null 2>&1; then
    if ! kpackagetool5 --type Plasma/Applet --upgrade "${PLASMOID_ARTIFACT}"; then
        fail "Widget upgrade failed; backend installation was not changed"
    fi
    pass "Plasma widget upgraded"
else
    if ! kpackagetool5 --type Plasma/Applet --install "${PLASMOID_ARTIFACT}"; then
        fail "Widget installation failed; backend installation was not changed"
    fi
    pass "Plasma widget installed"
fi

DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
BACKEND_PARENT="${DATA_HOME}/ttop-desk"
BACKEND_DIRECTORY="${BACKEND_PARENT}/backend"
UNIT_DIRECTORY="${CONFIG_HOME}/systemd/user"
INSTALLED_UNIT="${UNIT_DIRECTORY}/${UNIT_NAME}"
CATALOG_DESTINATION="${DATA_HOME}/locale/de/LC_MESSAGES/${CATALOG_NAME}"

for path_value in "${DATA_HOME}" "${CONFIG_HOME}" "${BACKEND_DIRECTORY}" \
        "${PYTHON_EXECUTABLE}"; do
    [[ -n "${path_value}" && "${path_value}" != *$'\n'* ]] \
        || fail "Install paths must be non-empty and contain no newlines"
done

if [[ -e "${INSTALLED_UNIT}" ]] \
        && ! grep -Fqx "${RELEASE_MARKER}" "${INSTALLED_UNIT}" \
        && ! grep -Fqx "${DEVELOPMENT_MARKER}" "${INSTALLED_UNIT}"; then
    fail "Refusing to overwrite unmanaged service unit: ${INSTALLED_UNIT}"
fi

TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/ttop-desk-install.XXXXXX")"
NEW_BACKEND="${BACKEND_PARENT}/.backend-new-$$"
OLD_BACKEND="${BACKEND_PARENT}/.backend-old-$$"
OLD_UNIT="${TEMPORARY_DIRECTORY}/previous.service"
HAD_OLD_UNIT=false
cleanup() {
    rm -rf -- "${TEMPORARY_DIRECTORY}" "${NEW_BACKEND}" "${OLD_BACKEND}"
}
trap cleanup EXIT

if [[ -f "${INSTALLED_UNIT}" ]]; then
    cp -- "${INSTALLED_UNIT}" "${OLD_UNIT}"
    HAD_OLD_UNIT=true
fi

while IFS= read -r archive_member; do
    case "${archive_member}" in
        /*|../*|*/../*|*/..) fail "Unsafe path in backend archive: ${archive_member}" ;;
    esac
done < <(tar -tzf "${BACKEND_ARTIFACT}")
tar -xzf "${BACKEND_ARTIFACT}" -C "${TEMPORARY_DIRECTORY}"
EXTRACTED_BACKEND="${TEMPORARY_DIRECTORY}/ttop-desk-backend-${VERSION}"
[[ -d "${EXTRACTED_BACKEND}/ttop_backend" ]] \
    || fail "Backend archive has an invalid structure"
[[ -f "${EXTRACTED_BACKEND}/ttop-desk-backend.service.in" ]] \
    || fail "Backend service template is missing"

mkdir -p -- "${BACKEND_PARENT}" "${UNIT_DIRECTORY}" \
    "$(dirname -- "${CATALOG_DESTINATION}")"
cp -a -- "${EXTRACTED_BACKEND}" "${NEW_BACKEND}"
rm -rf -- "${NEW_BACKEND}/ttop-desk-backend.service.in"

if [[ -d "${BACKEND_DIRECTORY}" ]]; then
    mv -- "${BACKEND_DIRECTORY}" "${OLD_BACKEND}"
fi
mv -- "${NEW_BACKEND}" "${BACKEND_DIRECTORY}"
install -m 0644 -- "${CATALOG_SOURCE}" "${CATALOG_DESTINATION}"

escape_systemd_value() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//%/%%}"
    printf '"%s"' "${value}"
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

backend_value="$(escape_sed_replacement \
    "$(escape_systemd_path "${BACKEND_DIRECTORY}")")"
python_value="$(escape_sed_replacement \
    "$(escape_systemd_value "${PYTHON_EXECUTABLE}")")"
documentation_value="$(escape_sed_replacement \
    "$(escape_systemd_value "file://${BACKEND_DIRECTORY}/README.md")")"
TEMPORARY_UNIT="$(mktemp "${UNIT_DIRECTORY}/.${UNIT_NAME}.XXXXXX")"
sed -e "s|@BACKEND_DIRECTORY@|${backend_value}|g" \
    -e "s|@PYTHON_EXECUTABLE@|${python_value}|g" \
    -e "s|@BACKEND_DOCUMENTATION@|${documentation_value}|g" \
    "${EXTRACTED_BACKEND}/ttop-desk-backend.service.in" >"${TEMPORARY_UNIT}"
chmod 0644 "${TEMPORARY_UNIT}"
mv -f -- "${TEMPORARY_UNIT}" "${INSTALLED_UNIT}"

if ! systemctl --user daemon-reload \
        || ! systemctl --user enable "${UNIT_NAME}" \
        || ! systemctl --user restart "${UNIT_NAME}" \
        || ! systemctl --user is-enabled --quiet "${UNIT_NAME}" \
        || ! systemctl --user is-active --quiet "${UNIT_NAME}"; then
    warn "Backend service activation failed; restoring the previous backend when available"
    systemctl --user stop "${UNIT_NAME}" >/dev/null 2>&1 || true
    rm -rf -- "${BACKEND_DIRECTORY}"
    if [[ -d "${OLD_BACKEND}" ]]; then
        mv -- "${OLD_BACKEND}" "${BACKEND_DIRECTORY}"
    fi
    rm -f -- "${INSTALLED_UNIT}"
    if [[ "${HAD_OLD_UNIT}" == true ]]; then
        cp -- "${OLD_UNIT}" "${INSTALLED_UNIT}"
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        systemctl --user restart "${UNIT_NAME}" >/dev/null 2>&1 || true
    else
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
    fail "Backend installation failed after the widget was installed; rerun after checking the user-service logs"
fi
rm -rf -- "${OLD_BACKEND}"
pass "Backend installed at ${BACKEND_DIRECTORY}"
pass "Backend service is enabled and active"

SOCKET_PATH="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ttop-desk.sock"
for _attempt in {1..50}; do
    [[ -S "${SOCKET_PATH}" ]] && break
    sleep 0.1
done
[[ -S "${SOCKET_PATH}" ]] || fail "Backend service is active but its Unix socket was not created"
SOCKET_MODE="$(stat -c '%a' "${SOCKET_PATH}")"
[[ "${SOCKET_MODE}" == "600" ]] || fail "Backend socket mode is ${SOCKET_MODE}, expected 600"
if ! "${PYTHON_EXECUTABLE}" -c \
        'import json, socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(3)
s.connect(sys.argv[1])
s.sendall(b"{\"command\":\"ping\"}\n")
reply = json.loads(s.recv(4096).decode("utf-8"))
raise SystemExit(0 if reply.get("status") == "ok" and reply.get("version") == 1 else 1)' \
        "${SOCKET_PATH}"; then
    fail "Backend socket ping failed"
fi
pass "Backend socket ping succeeded with mode 600"

printf '\nTTop Desk %s installation complete.\n' "${VERSION}"
printf '%s\n' \
    'Add TTop Desk from Plasma’s widget selector if it is not already present.' \
    'Existing settings were preserved. Reopen or remove/re-add an existing' \
    'instance if it still has older native runtime code mapped in memory.'
