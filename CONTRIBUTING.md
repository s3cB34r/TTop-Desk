# Contributing to TTop Desk

TTop Desk targets KDE Plasma 5.27 and Qt 5.15. Keep production QML compatible
with Plasma 5 APIs, preserve the versioned local backend protocol, and do not
introduce system commands into metric acquisition.

## Development environment

The primary development target is Linux Mint based on Ubuntu 24.04 with Plasma
5.27.12 and Qt 5.15. Development requires CMake, a C++ compiler, Qt 5 and KDE
Frameworks 5 development files, ECM, gettext, Python 3 with `psutil`,
`qmlscene`, `qmllint`, `plasmoidviewer`, and `kpackagetool5`. Package names vary
by distribution. Project scripts must not invoke `sudo` or install operating-
system packages.

## Change expectations

- Keep changes focused and preserve Plasma 5 API compatibility.
- Keep native metrics independent from the optional backend.
- Do not change protocol version, process/GPU acquisition, or service security
  boundaries without explicit design and regression coverage.
- Use translation-ready complete strings and preserve dynamic implicit sizing.
- Add bounded tests for behavior changes and avoid private data in fixtures,
  logs, and screenshots.
- Run `bash -n scripts/*.sh`, backend/configuration tests, relevant QML probes,
  `qmllint`, `git diff --check`, and `./scripts/release-check.sh` before review.

## Reporting issues

Use the GitHub bug template and include distribution, Plasma, Qt, and TTop Desk
versions, exact reproduction steps, installation method, and bounded relevant
logs. Include backend status for process/GPU issues. Remove usernames, private
paths, tokens, and full process command lines. Security-sensitive reports
belong in the private process documented in `SECURITY.md`.

## Localization

Production QML routes static text through `ttopTr()`. A small native Plasma 5
adapter selects English, German, or the current system language per widget and
reads the standard KDE `.mo` catalog without changing Plasma's process-wide
locale. This compatibility layer is necessary because Plasma 5's QML `i18n()`
helper follows the process locale and does not expose a safe per-plasmoid
locale override. The catalog domain is
`plasma_applet_io.github.s3cb34r.ttopdesk`, matching the plugin ID and Plasma's
applet-domain convention. English source strings are the fallback. Runtime
strings use complete messages and `%1`/`%2` placeholders;
do not concatenate translated sentence fragments. Hardware names, process
names, mount paths, plugin IDs, configuration keys, protocol commands, and
debug logging remain untranslated.

The translatable surface includes full and compact representations, every
settings label and choice, section headings, loading/unavailable/error states,
backend and GPU states, graph tooltips, and accessibility names/descriptions.
Metadata contains the corresponding localized German name and description.

After changing visible QML text, run:

```bash
./scripts/update-translations.sh
```

The helper resolves the repository root, extracts `ttopTr()` calls into
`po/plasma_applet_io.github.s3cb34r.ttopdesk.pot`, and merges every existing
language catalog. It requires `xgettext` and `msgmerge`, uses no `sudo`, and
fails clearly when tooling is missing. Validate a catalog with:

```bash
msgfmt --check --statistics \
  po/de/plasma_applet_io.github.s3cb34r.ttopdesk.po
```

To add one well-maintained language, create `po/<locale>/`, initialize a PO
file named `plasma_applet_io.github.s3cb34r.ttopdesk.po` from the POT with
`msginit`, translate the complete exposed surface, rerun the update helper,
and require zero fuzzy or untranslated messages before review. Do not add a
partially translated language merely to increase the language count.

CMake's `ki18n_install(po)` compiles and installs catalogs in standard KDE
locale locations. The user-local install/upgrade scripts compile them below
`${XDG_DATA_HOME:-$HOME/.local/share}/locale`; uninstall removes those exact
catalog files. The **Language** selector is per widget: **English** (default),
**Deutsch**, or **System default**. It never changes the system locale or
restarts the backend. For a temporary system-default German launch after local
installation:

```bash
LANGUAGE=de_DE:de LANG=de_DE.UTF-8 \
  plasmoidviewer -a "$(pwd)/package"
```

Check the settings page, section labels, graph tooltips and accessibility text,
Backend unavailable, GPU unavailable, and the source-English fallback. Locale
variables apply only to that command and do not change the user's locale.

## Visual regression workflow

The isolated harness and its scenario matrix are documented in
[`tests/visual/README.md`](tests/visual/README.md). Its eight scenarios cover:

- full default, minimal CPU/RAM, process focused, and graphs disabled;
- compact default and compact graph;
- backend unavailable and GPU unavailable.

The harness renders production representation components with deterministic
development-only data. It does not connect to the backend, insert fake values
into production, edit Plasma configuration, capture the desktop, or change the
active theme. Existing logical layout probes cheaply cover additional states:
everything enabled, CPU only, CPU/RAM, processes only, filesystems only, GPU
only, graphs/icons/header disabled, sub-elements, dense spacing, and history
lengths.

Capture the required full and compact views at 1x, 1.5x, and 2x:

```bash
./tests/visual/capture.sh \
  --scenarios full-default,compact-default \
  --scales 1,1.5,2
```

Candidates are ignored by Git. Missing baselines are reported as `SKIP`.
Baselines can only be replaced with explicit `--update-baseline`; review every
candidate first. The standard-library comparator tolerates only tiny rendering
noise and reports dimension or pixel changes.

Synthetic Qt 5 scale factors can differ slightly from compositor scaling, so
also inspect the widget once in the target Plasma session. The harness uses the
current theme without changing it. Run and label captures separately in a dark
and a light disposable/manual session. Never claim a theme label that does not
match the active session and never hardcode colors to imitate a theme.

Review screenshots for card overflow, overlap, clipped labels, missing icons,
graph overflow, process/GPU/filesystem row damage, compact sizing, HiDPI
rounding, contrast, and gaps left by hidden settings. Exact live metric text is
not a visual assertion.

## Release checks

Run:

```bash
./scripts/release-check.sh
```

The script reports `PASS`, `FAIL`, and `SKIP` totals and exits non-zero for real
failures. It reports worktree state; parses JSON and XML; checks shell and
Python syntax; builds the native runtime; runs backend and configuration tests;
validates package identity
and structure; validates widget-local language fallback and complete German
key coverage; lints production QML; verifies complete gettext catalogs; checks
an installed user unit and pings it when active; runs `git diff --check`; and
leaves screenshot capture and detailed backend status disabled unless
`--visual` or `--backend-status` is requested. It uses
no `sudo`, does not install packages, publish, commit, or modify baselines.

Before a release, also launch the production widget for sixty seconds, exercise
the settings page in English and German, inspect both theme variants, confirm
the optional backend states, and review the candidate image matrix. Record any
display/session limitation rather than manufacturing a passing result.

## Building release artifacts

`VERSION` is the central release version source. `package/metadata.json` must
match it; CMake and release scripts read it directly. Release notes and the
changelog record the corresponding public version. Build the complete local
release candidate with one command:

```bash
./scripts/build-release.sh
```

The builder reports a dirty worktree but does not modify Git state. It runs the
required checks, builds the native QML runtime, compiles translations, creates
the `.plasmoid`, creates a backend-only archive, assembles the standalone Linux
bundle, generates sorted SHA-256 manifests, and validates archive contents and
development-path exclusion. Generated output is replaced atomically below the
ignored `dist/` directory; it is never committed or published automatically.

After building, run the artifact-specific release check explicitly:

```bash
./scripts/release-check.sh --release
```

Before publication, extract the full bundle in a clean environment and test
install, repeated install, uninstall, and reinstall. Inspect all archive lists,
verify service enablement and its mode-0600 socket, exercise process and GPU
requests, and confirm the installed unit references only the user data path.
Do not substitute repository installation for this release smoke test.
