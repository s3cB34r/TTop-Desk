#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIRECTORY="${REPOSITORY_ROOT}/build"

cmake -S "${REPOSITORY_ROOT}" -B "${BUILD_DIRECTORY}"
cmake --build "${BUILD_DIRECTORY}" --target ttopruntimeplugin
