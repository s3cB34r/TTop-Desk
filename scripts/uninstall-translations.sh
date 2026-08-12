#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPOSITORY_ROOT
DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
readonly DATA_HOME

while IFS= read -r -d '' PO_FILE; do
    LANGUAGE_CODE="$(basename -- "$(dirname -- "${PO_FILE}")")"
    CATALOG_NAME="$(basename -- "${PO_FILE}" .po)"
    DESTINATION="${DATA_HOME}/locale/${LANGUAGE_CODE}/LC_MESSAGES/${CATALOG_NAME}.mo"
    rm -f -- "${DESTINATION}"
    printf 'Removed %s\n' "${DESTINATION}"
done < <(find "${REPOSITORY_ROOT}/po" -mindepth 2 -maxdepth 2 \
             -type f -name '*.po' -print0 | sort -z)
