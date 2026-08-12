#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

"${SCRIPT_DIR}/build-bridge.sh"
"${SCRIPT_DIR}/install-translations.sh"
"${SCRIPT_DIR}/install-backend-service.sh"

kpackagetool5 --type Plasma/Applet --upgrade "${REPOSITORY_ROOT}/package"
printf '%s\n' \
    'TTop Desk upgraded. Reopen or remove/re-add the widget instance to load' \
    'updated native runtime code; restarting Plasma is not required.'
