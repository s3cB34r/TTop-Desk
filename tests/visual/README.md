# Visual regression QA

The development-only harness renders the production full and compact QML
representations with fixed metric, filesystem, process, and GPU data. It uses
`grabToImage`, so captures contain the bounded widget test surface rather than
the desktop and never touch persistent Plasma configuration or the backend
protocol.

Run all eight scenarios at the required scale factors:

```bash
./tests/visual/capture.sh
```

The scenarios are `full-default`, `minimal`, `process-focused`, `graphs-off`,
`compact-default`, `compact-graph`, `backend-unavailable`, and
`gpu-unavailable`. Narrow runs are supported:

```bash
./tests/visual/capture.sh --scenarios full-default,compact-default --scales 1,1.5,2
```

Candidates are written below `tests/visual/candidate/` and ignored by Git.
Normal runs never create or replace baselines. A reviewed candidate becomes a
baseline only through the explicit command:

```bash
./tests/visual/capture.sh --theme-label breeze-dark --update-baseline
```

When a baseline exists, `compare_png.py` performs a small-tolerance per-pixel
comparison using only the Python standard library. It reports size changes,
changed-pixel ratio, and maximum channel delta. Missing baselines are `SKIP`,
not an implicit approval.

`QT_SCALE_FACTOR` is scoped to each capture process. The supported values are
1, 1.25, 1.5, and 2; the default matrix is 1, 1.5, and 2. Qt 5 synthetic scale
can differ from a compositor-managed fractional scale in font hinting and
device-pixel rounding, so final release QA still includes one real-session
check at the primary desktop scale.

The harness uses the active Plasma theme and never changes the user's theme.
For dark and light coverage, start a disposable/manual test session with the
desired theme and use distinct truthful labels such as `breeze-dark` and
`breeze-light`. The label affects paths only; it does not assert or fake the
active theme. Review contrast in both sessions.

Software Qt Quick rendering is used for repeatability while the active session
platform is retained. In a controlled X11 test session it can be selected
explicitly with `QT_QPA_PLATFORM=xcb`. `QT_QPA_PLATFORM=offscreen` is also
supported, but some Qt 5 Plasma component/Canvas combinations do not expose a
renderable window there and will time out as a failed capture. Do not capture
the whole desktop. Review candidates for clipping, overflow, overlap, broken
icons and rows, compact sizing, theme contrast, and configuration gaps; metric
text itself is intentionally not asserted.
