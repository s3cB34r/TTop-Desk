#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPOSITORY_ROOT

VERSION_FILE="${REPOSITORY_ROOT}/VERSION"
if [[ ! -f "${VERSION_FILE}" ]]; then
    printf 'ERROR: missing version source: %s\n' "${VERSION_FILE}" >&2
    exit 1
fi
PROJECT_VERSION="$(<"${VERSION_FILE}")"
if [[ ! "${PROJECT_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'ERROR: invalid release version: %s\n' "${PROJECT_VERSION}" >&2
    exit 1
fi
readonly PROJECT_VERSION

CATALOG_DOMAIN="plasma_applet_io.github.s3cb34r.ttopdesk"
POT_FILE="${REPOSITORY_ROOT}/po/${CATALOG_DOMAIN}.pot"
readonly CATALOG_DOMAIN POT_FILE

for tool in xgettext msgmerge; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        printf 'ERROR: required translation tool not found: %s\n' "${tool}" >&2
        exit 1
    fi
done

cd -- "${REPOSITORY_ROOT}"
mapfile -d '' SOURCE_FILES < <(
    find package/contents -type f -name '*.qml' -print0 | sort -z
)

if ((${#SOURCE_FILES[@]} == 0)); then
    printf 'ERROR: no QML sources found below %s\n' \
        "${REPOSITORY_ROOT}/package/contents" >&2
    exit 1
fi

TEMPORARY_POT="$(mktemp "${TMPDIR:-/tmp}/ttop-desk-messages.XXXXXX.pot")"
readonly TEMPORARY_POT
TEMPORARY_NEW_NORMALIZED="${TEMPORARY_POT}.new-normalized"
TEMPORARY_OLD_NORMALIZED="${TEMPORARY_POT}.old-normalized"
readonly TEMPORARY_NEW_NORMALIZED TEMPORARY_OLD_NORMALIZED
trap 'rm -f -- "${TEMPORARY_POT}" "${TEMPORARY_NEW_NORMALIZED}" "${TEMPORARY_OLD_NORMALIZED}"' EXIT

xgettext \
    --from-code=UTF-8 \
    --language=JavaScript \
    --keyword=i18n:1 \
    --keyword=ttopTr:1 \
    --keyword=i18nc:1c,2 \
    --keyword=i18np:1,2 \
    --keyword=i18ncp:1c,2,3 \
    --add-comments=TRANSLATORS \
    --package-name='TTop Desk' \
    --package-version="${PROJECT_VERSION}" \
    --copyright-holder='TTop Desk contributors' \
    --msgid-bugs-address='https://github.com/s3cb34r/TTop-Desk/issues' \
    --output="${TEMPORARY_POT}" \
    "${SOURCE_FILES[@]}"

mkdir -p -- "$(dirname -- "${POT_FILE}")"
if [[ -f "${POT_FILE}" ]]; then
    sed '/^"POT-Creation-Date:/d' "${TEMPORARY_POT}" >"${TEMPORARY_NEW_NORMALIZED}"
    sed '/^"POT-Creation-Date:/d' "${POT_FILE}" >"${TEMPORARY_OLD_NORMALIZED}"
fi
if [[ ! -f "${POT_FILE}" ]] \
        || ! cmp -s -- "${TEMPORARY_NEW_NORMALIZED}" "${TEMPORARY_OLD_NORMALIZED}"; then
    cp -- "${TEMPORARY_POT}" "${POT_FILE}"
fi

while IFS= read -r -d '' PO_FILE; do
    msgmerge --quiet --update --backup=none -- "${PO_FILE}" "${POT_FILE}"
done < <(find "${REPOSITORY_ROOT}/po" -mindepth 2 -maxdepth 2 \
             -type f -name "${CATALOG_DOMAIN}.po" -print0 | sort -z)

printf 'Updated %s and existing language catalogs.\n' \
    "${POT_FILE#"${REPOSITORY_ROOT}/"}"
