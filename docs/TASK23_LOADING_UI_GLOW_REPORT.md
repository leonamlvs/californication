# Task 23 loading text fill and foreground glow

> Historical revision report: this records one implemented loading revision, not an outstanding task or the live maintenance specification. The loading screen is complete and accepted under [LOADING_SCREEN.md](LOADING_SCREEN.md); [the audit](LOADING_SCREEN_DOC_AUDIT.md) distinguishes current definitions from revision history. Original measurements, dates, and results below are retained.

The loading screen now draws the supplied Solid font in white at exactly 50% opacity behind the unchanged Outline lettering. Text, bar, frame, and connector glows have smooth, wider falloff. The California map, its halo/shadow, radial background, other screens, layout, image contents, and loading timeline are preserved.

## Changed files

- `frontend/loading/LoadingPresentation.gd`: adds the optional fill-font slot, default white/0.5 fill color, four logical glow radii, and shared strength control. The existing outline-font property remains compatible.
- `frontend/loading/LoadingPresentation.tscn`: assigns the already-bundled Solid font to the fill slot. Both supplied OTF files and their imports remain unchanged.
- `frontend/loading/LoadingForeground.gd`: draws glow, Solid, then Outline with one transform/baseline; replaces coarse glow bands with 16 Gaussian-opacity passes; caches pass weights and reusable styles. Text stroke units are calibrated from glyph metrics so its logical radius remains accurate under font rasterization and fitting.
- `tests/cli/LoadingUiGlowTest.gd` and UID: controlled-background rendering checks for opacity, paired glyph positions, missing fill font, text/bar/frame/connector falloff, normalized near-edge brightness, stable bar glow, and highlight tint.
- Loading-related sections of `docs/04_UI_RESPONSIVE.md`, `05_ASSETS.md`, `06_IMPLEMENTATION_TASKS.md`, `07_IMPLEMENTATION_PLAN.md`, `TASK_STATUS.md`, and this report.

## Final behavior and controls

Open `frontend/loading/LoadingPresentation.tscn` and select its root:

- **Replaceable Assets**: `loading_font` remains Outline; `loading_fill_font` is Solid. A missing fill font leaves outlined text. A missing outline font keeps the previous system-font fallback without overlaying an unmatched Solid face.
- **Loading Text**: `loading_fill_color = Color(1, 1, 1, 0.5)`.
- **Foreground Glow**: text/bar/frame/connector radii are 8/12/8/6 logical pixels; shared strength is 1. A zero radius disables that glow; zero strength disables all foreground glows.

Both font layers use the original text, size, advances, baseline, and Outline-derived fitting, including the leading N cap height and corrected raised I dot. No independent scaling or offset is applied to Solid. Outline color remains `(0.90, 0.92, 1.0, 0.94)`.

Each glow uses a Gaussian falloff with sigma = radius/3. Incremental source-over alphas normalize near-edge strength independently of radius. The rounded-rectangle glow's inner edges sit beneath the existing sharp borders. The bar glows around its fixed outer perimeter at every fill level, with no glow added to the moving fill edge. Highlighted frames retain their green/yellow tint. No fullscreen bloom, viewport, shader, map-effect, input, or controller change was introduced.

## Validation

| Check | Result |
| --- | --- |
| Godot import/parser validation | Passed without errors or warnings |
| Task 23 | `TASK23_PASS`; existing timeline, fitting, caching, and handoff criteria retained |
| New Compatibility-rendered fixtures | `LOADING_UI_GLOW_PASS checks=101` |
| Controlled 50% fill | 1,002 fully covered glyph-interior samples; maximum RGB error 0.001961, within one rounding step |
| Isolated exterior glow profiles | Text, bar, frames, and connectors fade monotonically to the backdrop; radius change preserves near-edge brightness |
| Existing rendered image checks | `LOADING_IMAGES_PASS checks=107` |
| Responsive preview | 35 captures covering six timeline checkpoints at 960x720, 1280x720, 844x390, and 360x640, plus safe-inset, first-visible, replacement-texture, and diagnostic views |
| Pixel preservation | 17,826,699 pixels outside authorized UI regions match the fresh baseline exactly; all seven isolated background/map/effect captures are identical |
| Source preservation | All 575 protected pre-existing files match their baseline hashes, including font binaries/imports, image assets, map resources/shaders, island code, and project/export settings |
| Native production boot | Complete first frame, full-bar hold, and one handoff at exactly 2.0000 active seconds |
| Web export/package and resource audit | Passed; 9 files / 40,780,812 extracted bytes, 385 packed resources; no reference or development content |
| Exported scene configuration | Both font resources, white/0.5 fill, and 8/12/8/6 radii verified inside the exported pack |
| Exported browser smoke | `WEB_RUNTIME_NO_ERRORS`; loading capture inspected, and the existing flow/touch/pause/resize/retry/return path completed |
| `git diff --check` | Passed |

One native boot capture encountered the existing focus-pause behavior and timed out. An isolated rerun passed without changing production behavior. The text-profile check also exposed narrow native font stroke units; glyph-metric calibration corrected the glow extent before the final renders and Web build.

## Evidence and acceptance

Evidence lives under `build/rehabilitation/loading-ui-glow/`: fresh `before/` and `after/` captures, `before-source/`, `fixtures/`, `boot/`, exported `browser/` screenshots and clean console log, `protected-before.json`, `preservation.json`, `ui-glow.log`, `text-comparison.png`, and `comparison.html`. The authorization mask covers text and UI glow bands, including rounded corners and antialiasing; deep bar/frame interiors and all other pixels remain protected. The comparison script is saved beside the evidence as `compare.py`.

Run the direct preview with `godot --path . --rendering-method gl_compatibility dev/LoadingPreview.tscn -- --capture-loading-suite --capture-loading-effects --loading-output=build/rehabilitation/loading-ui-glow/after`. Run the new fixtures with `godot --path . --rendering-method gl_compatibility --script res://tests/cli/LoadingUiGlowTest.gd`.

All requested functional and preservation criteria pass. Native desktop/phone and exported-browser views were inspected against normalized frame 0070. The 16-pass glow approximates a continuous Gaussian, and the reference retains video softness/compression; this is not a pixel-for-pixel recreation. No later numbered task was started.
