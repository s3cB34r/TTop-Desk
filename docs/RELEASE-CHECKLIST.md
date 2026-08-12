# TTop Desk release checklist

Use this checklist for the proposed `v0.9.0` beta. Checking an item records
work; this document does not create a tag, GitHub release, or upload.

## Candidate validation

- [ ] Worktree and intended release commit are reviewed.
- [ ] `./scripts/build-release.sh` completes from the intended commit.
- [ ] `./scripts/release-check.sh --release` reports no failures.
- [ ] Clean-profile install, repeated install, uninstall, and reinstall pass.
- [ ] Backend stop/start/restart and automatic widget recovery pass.
- [ ] Process and available-NVIDIA GPU responses pass.
- [ ] No-NVML behavior remains graceful.
- [ ] English, German, system language, settings persistence, layout, compact,
      HiDPI, dark-theme, and light-theme paths are reviewed.
- [ ] `cd dist && sha256sum --check --strict SHA256SUMS` passes.
- [ ] Archive and installed-file development-path scans pass.
- [ ] Public screenshots contain no private desktop or process data.

## Release content

- [ ] `VERSION`, metadata, changelog, and release notes agree.
- [ ] `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, issue templates, and PR
      template are current.
- [ ] Known limitations and Plasma 5.27 support are explicit.
- [ ] `LICENSE` and metadata both state GPL-3.0-or-later.
- [ ] Final artifact hashes are copied from the candidate build, not an older
      local build.

## GitHub actions performed manually after approval

- [ ] Create annotated tag `v0.9.0` from the approved release commit.
- [ ] Push the tag.
- [ ] Draft a GitHub pre-release using `RELEASE-NOTES.md`.
- [ ] Attach the full Linux bundle, plasmoid, backend archive, and SHA256SUMS.
- [ ] Verify attached-file checksums after download.
- [ ] Publish the pre-release only after final maintainer review.
