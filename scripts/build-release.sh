#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${REPOSITORY_ROOT}/VERSION"
DIST_DIRECTORY="${REPOSITORY_ROOT}/dist"
readonly SCRIPT_DIR REPOSITORY_ROOT VERSION_FILE DIST_DIRECTORY

pass() { printf 'PASS: %s\n' "$1"; }
warn() { printf 'WARN: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

[[ -f "${VERSION_FILE}" ]] || fail "Missing central VERSION file"
VERSION="$(<"${VERSION_FILE}")"
[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "VERSION must contain one semantic version"
readonly VERSION

for command_name in bash cmake git msgfmt python3 sha256sum; do
    command -v "${command_name}" >/dev/null 2>&1 \
        || fail "Required release-build dependency missing: ${command_name}"
done

cd -- "${REPOSITORY_ROOT}"
if [[ -n "$(git status --short)" ]]; then
    warn "Building from an uncommitted worktree; the artifact will contain current source files"
else
    pass "Git worktree is clean"
fi

python3 scripts/validate-release.py
pass "Release sources and centralized version are valid"

./scripts/release-check.sh
pass "Required release checks passed"

[[ -f package/contents/ui/TTop/Runtime/libttopruntimeplugin.so ]] \
    || fail "Native runtime plugin was not built"
if find package -type d \( -name tests -o -name __pycache__ -o -name .pytest_cache \) \
        -print -quit | grep -q .; then
    fail "Plasma package source contains developer or cache directories"
fi

STAGING_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/ttop-desk-build-release.XXXXXX")"
cleanup() {
    rm -rf -- "${STAGING_DIRECTORY}"
}
trap cleanup EXIT

rm -rf -- "${DIST_DIRECTORY}"
mkdir -p -- "${DIST_DIRECTORY}"

PLASMOID_STAGE="${STAGING_DIRECTORY}/plasmoid"
BACKEND_STAGE="${STAGING_DIRECTORY}/backend"
BUNDLE_STAGE="${STAGING_DIRECTORY}/bundle"
BUNDLE_ROOT_NAME="ttop-desk-${VERSION}-linux"
BACKEND_ROOT_NAME="ttop-desk-backend-${VERSION}"
mkdir -p -- "${PLASMOID_STAGE}" "${BACKEND_STAGE}" "${BUNDLE_STAGE}"

cp -a -- package/. "${PLASMOID_STAGE}/"
PLASMOID_ARTIFACT="${DIST_DIRECTORY}/ttop-desk-${VERSION}.plasmoid"
python3 scripts/release_archive.py zip "${PLASMOID_STAGE}" "${PLASMOID_ARTIFACT}"
pass "Plasmoid artifact created"

mkdir -p -- "${BACKEND_STAGE}/ttop_backend"
while IFS= read -r -d '' backend_file; do
    relative_path="${backend_file#backend/}"
    destination="${BACKEND_STAGE}/${relative_path}"
    mkdir -p -- "$(dirname -- "${destination}")"
    install -m 0644 -- "${backend_file}" "${destination}"
done < <(find backend/ttop_backend -type f -name '*.py' -print0 | sort -z)
sed "s/@VERSION@/${VERSION}/g" release/backend-README.md >"${BACKEND_STAGE}/README.md"
chmod 0644 "${BACKEND_STAGE}/README.md"
install -m 0644 -- LICENSE "${BACKEND_STAGE}/LICENSE"
install -m 0644 -- VERSION "${BACKEND_STAGE}/VERSION"
install -m 0644 -- release/ttop-desk-backend.service.in \
    "${BACKEND_STAGE}/ttop-desk-backend.service.in"
BACKEND_ARTIFACT="${DIST_DIRECTORY}/ttop-desk-backend-${VERSION}.tar.gz"
python3 scripts/release_archive.py tar.gz "${BACKEND_STAGE}" \
    "${BACKEND_ARTIFACT}" --prefix "${BACKEND_ROOT_NAME}"
pass "Backend artifact created"

install -m 0755 -- release/install.sh "${DIST_DIRECTORY}/install.sh"
install -m 0755 -- release/uninstall.sh "${DIST_DIRECTORY}/uninstall.sh"
sed "s/@VERSION@/${VERSION}/g" release/README.md >"${DIST_DIRECTORY}/README.md"
chmod 0644 "${DIST_DIRECTORY}/README.md"
install -m 0644 -- RELEASE-NOTES.md CHANGELOG.md LICENSE VERSION "${DIST_DIRECTORY}/"
CATALOG_DIRECTORY="${DIST_DIRECTORY}/locale/de/LC_MESSAGES"
mkdir -p -- "${CATALOG_DIRECTORY}"
msgfmt --check --check-accelerators='&' \
    --output-file="${CATALOG_DIRECTORY}/plasma_applet_io.github.s3cb34r.ttopdesk.mo" \
    po/de/plasma_applet_io.github.s3cb34r.ttopdesk.po

cp -a -- "${DIST_DIRECTORY}/." "${BUNDLE_STAGE}/"
(
    cd -- "${BUNDLE_STAGE}"
    find . -type f ! -name SHA256SUMS -printf '%P\0' \
        | sort -z \
        | xargs -0 sha256sum >SHA256SUMS
)
FULL_BUNDLE="${DIST_DIRECTORY}/ttop-desk-${VERSION}-linux.tar.gz"
python3 scripts/release_archive.py tar.gz "${BUNDLE_STAGE}" \
    "${FULL_BUNDLE}" --prefix "${BUNDLE_ROOT_NAME}"
pass "Full Linux release bundle created"

(
    cd -- "${DIST_DIRECTORY}"
    find . -type f ! -name SHA256SUMS -printf '%P\0' \
        | sort -z \
        | xargs -0 sha256sum >SHA256SUMS
)
python3 scripts/validate-release.py --dist "${DIST_DIRECTORY}"
pass "Release artifacts, contents, portability, and checksums are valid"

printf '\nVersion: %s\n' "${VERSION}"
printf 'Artifacts:\n'
find "${DIST_DIRECTORY}" -maxdepth 1 -type f -printf '  %f\n' | sort
printf 'Checksums:\n'
sed 's/^/  /' "${DIST_DIRECTORY}/SHA256SUMS"
printf '%s\n' \
    'Next manual steps:' \
    '  1. Review RELEASE-NOTES.md and the exact archive contents.' \
    '  2. Extract the Linux bundle and run ./install.sh on the Plasma 5.27 target.' \
    '  3. Do not publish until clean-environment release-candidate QA is complete.'
