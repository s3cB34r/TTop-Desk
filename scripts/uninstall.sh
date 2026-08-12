#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPOSITORY_ROOT

"${SCRIPT_DIR}/uninstall-translations.sh"

exec kpackagetool5 --type Plasma/Applet --remove io.github.s3cb34r.ttopdesk
