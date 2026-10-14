# Task 23 loading-map effects revision — 2026-10-11

Historical report: the later loading-only SVG replacement supersedes this renderer. See `TASK23_LOADING_SVG_REPORT.md` for the current implementation and validation. The evidence below is retained unchanged.

The loading map now uses a continuous cached Gaussian halo instead of the stepped four-direction effect. The authored model, its fit and rotation, image slots, foreground drawing, timing owner, focus pause, and island handoff are preserved.

**Functional and numerical acceptance passed. Exact visual acceptance remains incomplete.** Rendered inspection still shows flatter side illumination and different fine west-coast/southern glints from the reference. The retained mesh also has small contour/depth differences. Numerical tolerances do not erase those differences; this revision is not recorded as an exact visual match.

## Implementation and files

- `frontend/loading/LoadingPresentation.gd`: existing appearance controls retained; adds edge width, bottom tint, side brightness, glow offset, and directional bias.
- `frontend/loading/LoadingMeshBackground.gd` and `.tscn`: isolated 960x720 mesh viewport with 4x MSAA, two nested isolated 960x720 2D passes, CPU-normalized paired Gaussian kernels, coalesced one-frame rendering, explicit disabled cache state, and extended snapshots.
- `frontend/loading/loading_mesh.gdshader`: projected vertical tint and fixed virtual side lighting.
- `frontend/loading/loading_mesh_composite.gdshader`: narrow/wide boundary masks, proper alpha compositing, restrained inward haze, calibrated glow displacement/direction, and fine physical seam highlights sampled from the loading mesh texture.
- New `frontend/loading/loading_mesh_blur.gdshader` and UID: horizontal/vertical narrow and broad Gaussian channels.
- `dev/LoadingPreview.gd`: background/isolated-effect views, output-directory option, first-frame equality/completeness checks, and cached-render checks.
- New `dev/LoadingEffectsCompare.gd` and UID: reference normalization, 5x5 patches, masked edge profiles, measurements, CSV/SVG plots, and comparison HTML.
- New `dev/LoadingBootCapture.gd` and UID: observes production boot without seeking its clock.
- `tests/cli/Task23Test.gd`: resolution/MSAA, blur worlds, cache/re-entry/resize, and appearance-refresh checks.
- `tests/cli/RehabilitationTest.gd`: restores simulated focus after Windows capture resize for manually stepped, processing-disabled frontend controllers. Production focus behavior is unchanged.
- `docs/04_UI_RESPONSIVE.md`, `05_ASSETS.md`, `06_IMPLEMENTATION_TASKS.md`, `07_IMPLEMENTATION_PLAN.md`, and `TASK_STATUS.md`: revised rendering budget, tuning/replacement instructions, acceptance, and remaining visual work.

## Verification

Windows Godot commands were run with waited processes; logs and exit codes were inspected.

| Check | Outcome |
|---|---|
| Baseline `godot --headless --path . res://tests/cli/Task23Test.tscn` | `TASK23_PASS` before edits |
| `godot --headless --editor --path . --import --quit` | Passed; no parser/import errors |
| Updated Task 23 scene | `TASK23_PASS`; intentional meshless-fixture warning only |
| Compatibility preview with `--capture-loading-suite --capture-loading-effects` | Passed; first-frame composition equals settled empty state; all three targets complete immediately and cache |
| `godot --headless --path . --script res://dev/LoadingEffectsCompare.gd` | Exit 0; all primary patch/profile thresholds passed |
| `godot --path . --rendering-method gl_compatibility --script res://dev/LoadingBootCapture.gd` | Complete mesh/glow in the first recorded frame, full-bar hold, direct intro handoff at 2.0000 accumulated active seconds |
| `tools/validate_rehabilitation.ps1 -Render -Export` | Passed import/main, Tasks 00–27, nine 600-second scenario soaks, production flow, Compatibility layouts, Web packaging, and pack-content audit |
| `node tools/smoke_web.mjs` | `WEB_RUNTIME_NO_ERRORS`; loading and island-attract captures inspected |
| `git diff --check` | Passed |

The first full validation attempt exposed a rendered-fixture focus assumption after window resizing. The test setup was repaired and the full pipeline rerun successfully. No production controller change was used to make that test pass.

The native recording includes screenshot I/O and can include focus pauses; its wall-clock duration is not a two-second performance measurement. The production owner still advances exactly two accumulated active seconds and pauses while unfocused. The render targets are cached but consume more memory than the former single 480x360 target.

## Rendered evidence

All loading-specific evidence is under `build/rehabilitation/loading-effects/` (development artifacts, excluded from Git/export):

- `before/`: original empty/intermediate/full captures across four viewport shapes.
- `after/`: empty, frames 20/40/60/70, full-bar hold at 960x720, 1280x720, 844x390, and 360x640; safe-inset landscape and differently proportioned replacement-box captures.
- `after/diagnostic-background-960x720.png`, `diagnostic-surface-960x720.png`, `diagnostic-contour-960x720.png`, `diagnostic-halo-960x720.png`, source texture, and blurred mask.
- `reference-10-normalized.png`, `reference-11-normalized.png`, `reference-40-normalized.png`, `reference-70-normalized.png`: source pillarboxes removed; frame 10 additionally expanded from its 960x566 active rectangle to 960x720.
- `comparison.html`, `measurements.json`, `edge-profiles.csv`, and `edge-profiles.svg`: inspectable comparisons and numerical evidence.
- `native-first-01.png` through `native-first-04.png`, `native-intermediate.png`, `native-full-hold.png`, and `native-first-island-intro.png`: observed real-time production frames.

Exported-browser evidence is under `build/rehabilitation/browser/`: `00-loading.png`, `01-attract.png`, subsequent flow/resize captures, and `console.json` with no runtime errors. The Web ZIP is `build/itch/californication-web.zip`; package audit passed at 9 files / 40,630,100 extracted bytes, with 386 packed resources and no reference/dev/test content.

Primary face patch maximum channel errors are **4.52, 4.00, and 6.00** RGB levels. Edge-profile mean absolute RGB errors:

| Profile | Before | After | Limit |
|---|---:|---:|---:|
| Top | 2.77 | 3.61 | 8 |
| Northeast | 12.49 | 6.58 | 8 |
| West | 9.82 | 7.91 | 8 |
| South | 8.77 | 7.05 | 8 |

Foreground bloom is excluded from profile measurements. The top profile's numerical average was closer before, despite its visible banding; this illustrates why visual inspection remains necessary. Cross-checks against normalized frames 10/40/70 are recorded separately in the JSON.

## Inspector tuning

Open `frontend/loading/LoadingPresentation.tscn`, select the root, and expand **Background 3D**. The production instance is `FrontendUI/LoadingOverlay` inside `frontend/island/IslandFrontend.tscn`. Save and restart the preview (F6) to see changes.

| Property | Calibrated value |
|---|---|
| Background Color | `#313189` |
| Background Mesh Tint | `(0.72, 0.70, 0.83)` |
| Background Mesh Bottom Tint | `(0.72, 0.72, 0.96)` |
| Background Surface Opacity | `0.26` |
| Background Side Brightness | `0.65` |
| Background Edge Strength / Width | `0.10` / `2` logical pixels |
| Background Halo Strength / Radius | `0.95` / `32` logical pixels |
| Background Halo Offset | `(3, -3)` logical pixels; moves only the broad glow |
| Background Halo Direction Bias | `(0.42, -0.42)`; zero removes direction variation |

The model slot and transform controls remain unchanged. All tuning applies only to loading materials; imported mesh/material resources are not modified. Preview **B** hides the foreground and **D** cycles effect diagnostics. Remaining visual work is the reference's localized surface/depth highlights; do not mark exact acceptance complete solely because the current measurements pass.
