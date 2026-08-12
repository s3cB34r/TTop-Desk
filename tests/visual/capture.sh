#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_DIR REPOSITORY_ROOT

SCENARIOS="full-default,minimal,process-focused,graphs-off,compact-default,compact-graph,backend-unavailable,gpu-unavailable"
SCALES="1,1.5,2"
THEME_LABEL="current"
UPDATE_BASELINE=false

usage() {
    printf '%s\n' \
        'Usage: tests/visual/capture.sh [options]' \
        '  --scenarios LIST       Comma-separated scenario names' \
        '  --scales LIST          Comma-separated factors: 1, 1.25, 1.5, 2' \
        '  --theme-label LABEL    Label only; never changes the active theme' \
        '  --update-baseline      Explicitly replace matching baselines' \
        '  --help                 Show this help'
}

while (($# > 0)); do
    case "$1" in
        --scenarios) SCENARIOS="${2:?missing scenario list}"; shift 2 ;;
        --scales) SCALES="${2:?missing scale list}"; shift 2 ;;
        --theme-label) THEME_LABEL="${2:?missing theme label}"; shift 2 ;;
        --update-baseline) UPDATE_BASELINE=true; shift ;;
        --help) usage; exit 0 ;;
        *) printf 'ERROR: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

if ! command -v qmlscene >/dev/null 2>&1; then
    printf 'SKIP: qmlscene is unavailable; no screenshots captured.\n'
    exit 0
fi
if [[ ! "${THEME_LABEL}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'ERROR: theme label must contain only letters, digits, dot, underscore, or dash.\n' >&2
    exit 2
fi

IFS=',' read -r -a SCENARIO_LIST <<<"${SCENARIOS}"
IFS=',' read -r -a SCALE_LIST <<<"${SCALES}"
KNOWN_SCENARIOS=" full-default minimal process-focused graphs-off compact-default compact-graph backend-unavailable gpu-unavailable "
for scenario in "${SCENARIO_LIST[@]}"; do
    if [[ "${KNOWN_SCENARIOS}" != *" ${scenario} "* ]]; then
        printf 'ERROR: unknown visual scenario: %s\n' "${scenario}" >&2
        exit 2
    fi
done
for scale in "${SCALE_LIST[@]}"; do
    case "${scale}" in 1|1.25|1.5|2) ;; *) printf 'ERROR: unsupported scale: %s\n' "${scale}" >&2; exit 2 ;; esac
done

CANDIDATE_ROOT="${SCRIPT_DIR}/candidate/${THEME_LABEL}"
BASELINE_ROOT="${SCRIPT_DIR}/baseline/${THEME_LABEL}"
CAPTURE_PLATFORM="${QT_QPA_PLATFORM:-}"
CAPTURE_LOGGING_RULES="${QT_LOGGING_RULES:-kf.i18n.warning=false}"
readonly CAPTURE_PLATFORM CAPTURE_LOGGING_RULES
mkdir -p -- "${CANDIDATE_ROOT}"

PASSED=0
FAILED=0
SKIPPED=0
for scale in "${SCALE_LIST[@]}"; do
    SCALE_DIRECTORY="${scale//./_}x"
    mkdir -p -- "${CANDIDATE_ROOT}/${SCALE_DIRECTORY}"
    for scenario in "${SCENARIO_LIST[@]}"; do
        CANDIDATE="${CANDIDATE_ROOT}/${SCALE_DIRECTORY}/${scenario}.png"
        BASELINE="${BASELINE_ROOT}/${SCALE_DIRECTORY}/${scenario}.png"
        CAPTURE_ENVIRONMENT=(
            env
            QT_QUICK_BACKEND=software
            QT_SCALE_FACTOR="${scale}"
            QT_LOGGING_RULES="${CAPTURE_LOGGING_RULES}"
        )
        if [[ -n "${CAPTURE_PLATFORM}" ]]; then
            CAPTURE_ENVIRONMENT+=(QT_QPA_PLATFORM="${CAPTURE_PLATFORM}")
        fi
        if (cd -- "${CANDIDATE_ROOT}/${SCALE_DIRECTORY}" && \
            timeout 30s "${CAPTURE_ENVIRONMENT[@]}" \
                qmlscene --software --scaling --resize-to-root \
                "${SCRIPT_DIR}/scenarios/${scenario}.qml"); then
            printf 'PASS: captured %s at %sx (%s theme label)\n' \
                "${scenario}" "${scale}" "${THEME_LABEL}"
            PASSED=$((PASSED + 1))
        else
            printf 'FAIL: capture failed for %s at %sx\n' "${scenario}" "${scale}" >&2
            FAILED=$((FAILED + 1))
            continue
        fi

        if [[ "${UPDATE_BASELINE}" == true ]]; then
            mkdir -p -- "$(dirname -- "${BASELINE}")"
            install -m 0644 -- "${CANDIDATE}" "${BASELINE}"
            printf 'PASS: baseline explicitly updated: %s\n' \
                "${BASELINE#"${REPOSITORY_ROOT}/"}"
            PASSED=$((PASSED + 1))
        elif [[ -f "${BASELINE}" ]]; then
            if python3 "${SCRIPT_DIR}/compare_png.py" "${BASELINE}" "${CANDIDATE}"; then
                PASSED=$((PASSED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        else
            printf 'SKIP: no baseline for %s at %sx (%s)\n' \
                "${scenario}" "${scale}" "${THEME_LABEL}"
            SKIPPED=$((SKIPPED + 1))
        fi
    done
done

printf 'Visual summary: %d passed, %d failed, %d skipped.\n' \
    "${PASSED}" "${FAILED}" "${SKIPPED}"
((FAILED == 0))
