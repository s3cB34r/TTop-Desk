#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPOSITORY_ROOT

if ! command -v msgfmt >/dev/null 2>&1; then
    printf 'ERROR: required translation compiler not found: msgfmt\n' >&2
    exit 1
fi

DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
readonly DATA_HOME
CATALOG_COUNT=0

while IFS= read -r -d '' PO_FILE; do
    LANGUAGE_CODE="$(basename -- "$(dirname -- "${PO_FILE}")")"
    CATALOG_NAME="$(basename -- "${PO_FILE}" .po)"
    DESTINATION="${DATA_HOME}/locale/${LANGUAGE_CODE}/LC_MESSAGES/${CATALOG_NAME}.mo"
    mkdir -p -- "$(dirname -- "${DESTINATION}")"
    msgfmt --check --check-accelerators='&' --output-file="${DESTINATION}" "${PO_FILE}"
    printf 'Installed %s\n' "${DESTINATION}"
    CATALOG_COUNT=$((CATALOG_COUNT + 1))
done < <(find "${REPOSITORY_ROOT}/po" -mindepth 2 -maxdepth 2 \
             -type f -name '*.po' -print0 | sort -z)

if ((CATALOG_COUNT == 0)); then
    printf 'ERROR: no translation catalogs found below %s/po\n' \
        "${REPOSITORY_ROOT}" >&2
    exit 1
fi
