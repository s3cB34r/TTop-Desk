#!/usr/bin/env bash
set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly SCRIPT_DIR REPOSITORY_ROOT
cd -- "${REPOSITORY_ROOT}"

RUN_VISUAL=false
RUN_BACKEND_STATUS=false
RUN_RELEASE=false
while (($# > 0)); do
    case "$1" in
        --visual) RUN_VISUAL=true ;;
        --backend-status) RUN_BACKEND_STATUS=true ;;
        --release) RUN_RELEASE=true ;;
        --help)
            printf '%s\n' \
                'Usage: scripts/release-check.sh [--visual] [--backend-status] [--release]' \
                '  --visual          Capture full and compact views at 1x, 1.5x, and 2x' \
                '  --backend-status  Report the optional user-service state' \
                '  --release         Require and validate generated dist artifacts'
            exit 0
            ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

PASSED=0
FAILED=0
SKIPPED=0
TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/ttop-desk-release.XXXXXX")"
readonly TEMPORARY_DIRECTORY
trap 'rm -rf -- "${TEMPORARY_DIRECTORY}"' EXIT

pass() { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAILED=$((FAILED + 1)); }
skip() { printf 'SKIP: %s\n' "$1"; SKIPPED=$((SKIPPED + 1)); }

run_check() {
    local label="$1"
    shift
    local log_file="${TEMPORARY_DIRECTORY}/check.log"
    if "$@" >"${log_file}" 2>&1; then
        pass "${label}"
    else
        fail "${label}"
        sed -n '1,80p' "${log_file}" | sed 's/^/      /'
    fi
}

check_json() {
    mapfile -d '' files < <(find package tests -type f -name '*.json' -print0 | sort -z)
    python3 -c 'import json, pathlib, sys
for name in sys.argv[1:]:
    json.loads(pathlib.Path(name).read_text(encoding="utf-8"))' "${files[@]}"
}

check_xml() {
    mapfile -d '' files < <(find package -type f -name '*.xml' -print0 | sort -z)
    python3 -c 'import sys, xml.etree.ElementTree as ET
for name in sys.argv[1:]:
    ET.parse(name)' "${files[@]}"
}

check_shell() {
    mapfile -d '' files < <(find scripts release tests/visual -type f -name '*.sh' -print0 | sort -z)
    bash -n "${files[@]}"
}

check_python_syntax() {
    mapfile -d '' files < <(find backend scripts tests -type f -name '*.py' -print0 | sort -z)
    python3 -c 'import pathlib, sys
for name in sys.argv[1:]:
    source = pathlib.Path(name).read_text(encoding="utf-8")
    compile(source, name, "exec")' "${files[@]}"
}

check_qml() {
    mapfile -d '' files < <(find package/contents -type f -name '*.qml' -print0 | sort -z)
    local file
    for file in "${files[@]}"; do
        qmllint "${file}"
    done
}

check_translations() {
    local po_file
    local catalog_count=0
    while IFS= read -r -d '' po_file; do
        catalog_count=$((catalog_count + 1))
        msgfmt --check --check-accelerators='&' \
            --output-file="${TEMPORARY_DIRECTORY}/$(basename -- "${po_file}" .po).mo" \
            "${po_file}"
        if msgattrib --untranslated --no-obsolete "${po_file}" | grep -q '^msgid '; then
            printf 'Untranslated entries in %s\n' "${po_file}" >&2
            return 1
        fi
    done < <(find po -mindepth 2 -maxdepth 2 -type f -name '*.po' -print0 | sort -z)
    ((catalog_count > 0))
}

check_package_structure() {
    python3 -c 'import json, pathlib
root = pathlib.Path("package")
version = pathlib.Path("VERSION").read_text(encoding="utf-8").strip()
required = [root / "metadata.json", root / "contents/ui/main.qml",
            root / "contents/config/config.qml", root / "contents/config/main.xml",
            root / "contents/ui/TTop/Runtime/qmldir",
            root / "contents/ui/TTop/Runtime/libttopruntimeplugin.so"]
missing = [str(path) for path in required if not path.is_file()]
if missing:
    raise SystemExit("missing: " + ", ".join(missing))
metadata = json.loads((root / "metadata.json").read_text(encoding="utf-8"))
plugin = metadata["KPlugin"]
assert plugin["Id"] == "io.github.s3cb34r.ttopdesk"
assert plugin["Version"] == version
assert metadata["X-Plasma-MainScript"] == "ui/main.qml"'
}

check_release_service_template() {
    local instantiated_unit="${TEMPORARY_DIRECTORY}/ttop-desk-backend.service"
    sed -e 's|@BACKEND_DIRECTORY@|/tmp/ttop-desk-backend|g' \
        -e 's|@PYTHON_EXECUTABLE@|"/usr/bin/python3"|g' \
        -e 's|@BACKEND_DOCUMENTATION@|"file:///tmp/ttop-desk-backend/README.md"|g' \
        release/ttop-desk-backend.service.in >"${instantiated_unit}"
    systemd-analyze --user verify "${instantiated_unit}"
}

check_installed_service_unit() {
    local unit_path="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user/ttop-desk-backend.service"
    systemd-analyze --user verify "${unit_path}"
}

check_translation_runtime() {
    local data_home="${TEMPORARY_DIRECTORY}/translation-data"
    local message_directory="${data_home}/locale/de/LC_MESSAGES"
    mkdir -p -- "${message_directory}"
    msgfmt --output-file="${message_directory}/plasma_applet_io.github.s3cb34r.ttopdesk.mo" \
        po/de/plasma_applet_io.github.s3cb34r.ttopdesk.po
    timeout 15s env XDG_DATA_HOME="${data_home}" LANGUAGE=de LC_ALL=de_DE.UTF-8 \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        qmlscene tests/TranslationProbe.qml
}

if command -v git >/dev/null 2>&1; then
    WORKTREE_STATE="$(git status --short)"
    if [[ -n "${WORKTREE_STATE}" ]]; then
        printf '%s\n' "${WORKTREE_STATE}" | sed 's/^/      /'
        pass "Git worktree state reported (changes present)"
    else
        pass "Git worktree state reported (clean)"
    fi
else
    fail "Git is required"
fi

if command -v cmake >/dev/null 2>&1; then
    run_check "Native Plasma runtime build" scripts/build-bridge.sh
else
    fail "CMake is required to build the native Plasma runtime"
fi

if command -v python3 >/dev/null 2>&1; then
    run_check "JSON files parse" check_json
    run_check "XML files parse" check_xml
    run_check "Python syntax" check_python_syntax
    run_check "Backend tests" env PYTHONPATH="${REPOSITORY_ROOT}/backend" \
        python3 -m unittest discover -s backend/tests -t .
    run_check "Configuration tests" python3 -m unittest discover -s tests -p 'test_*.py'
    run_check "Widget-local translation keys and German coverage" \
        python3 scripts/check-translations.py
    run_check "Plasma package structure" check_package_structure
    run_check "Release source/version consistency" python3 scripts/validate-release.py
else
    fail "Python 3 is required"
fi

if command -v qmlscene >/dev/null 2>&1 && command -v msgfmt >/dev/null 2>&1; then
    run_check "Per-widget translation runtime" check_translation_runtime
else
    skip "qmlscene or msgfmt unavailable; per-widget translation runtime not exercised"
fi

run_check "Shell syntax" check_shell

if command -v qmllint >/dev/null 2>&1; then
    run_check "Production QML lint" check_qml
else
    skip "qmllint unavailable"
fi

if command -v msgfmt >/dev/null 2>&1 && command -v msgattrib >/dev/null 2>&1; then
    run_check "Translation catalogs (complete and valid)" check_translations
else
    skip "gettext validation tools unavailable"
fi

run_check "Whitespace errors" git diff --check

if command -v systemd-analyze >/dev/null 2>&1; then
    run_check "Release backend service template" check_release_service_template
else
    skip "systemd-analyze unavailable; release service template not exercised"
fi

INSTALLED_UNIT="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user/ttop-desk-backend.service"
if command -v systemd-analyze >/dev/null 2>&1 && [[ -f "${INSTALLED_UNIT}" ]]; then
    run_check "Installed backend user-service unit" check_installed_service_unit
else
    skip "Installed backend user-service unit unavailable"
fi

if command -v systemctl >/dev/null 2>&1 \
        && systemctl --user is-active --quiet ttop-desk-backend.service; then
    run_check "Active backend client ping" scripts/backend-client.py --ping-only
else
    skip "Backend client ping (user service inactive or unavailable)"
fi

if [[ "${RUN_VISUAL}" == true ]]; then
    run_check "Visual captures (full and compact at required scales)" \
        "${REPOSITORY_ROOT}/tests/visual/capture.sh" \
        --scenarios full-default,compact-default --scales 1,1.5,2
else
    skip "Visual captures not requested (use --visual)"
fi

if [[ "${RUN_BACKEND_STATUS}" == true ]]; then
    if "${SCRIPT_DIR}/backend-status.sh" >/dev/null 2>&1; then
        pass "Optional backend user service is active"
    else
        skip "Optional backend user service is inactive or unavailable"
    fi
else
    skip "Backend user-service status not requested (use --backend-status)"
fi

if [[ "${RUN_RELEASE}" == true ]]; then
    if [[ -d "${REPOSITORY_ROOT}/dist" ]]; then
        run_check "Generated release artifacts" \
            python3 scripts/validate-release.py --dist "${REPOSITORY_ROOT}/dist"
        run_check "Generated release checksums" \
            bash -c 'cd "$1" && sha256sum --check --strict --quiet SHA256SUMS' \
            _ "${REPOSITORY_ROOT}/dist"
    else
        fail "Generated dist artifacts are required with --release"
    fi
else
    skip "Generated release artifacts not requested (use --release)"
fi

printf 'Summary: %d passed, %d failed, %d skipped.\n' \
    "${PASSED}" "${FAILED}" "${SKIPPED}"
((FAILED == 0))
