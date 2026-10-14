# Task 23 loading SVG replacement

The loading-only California GLB and procedural fallback are replaced by the supplied SVG. Its painted depth and highlights remain in the artwork. A cached silhouette-driven outer halo and a very subtle downward/right shadow sit behind it. The existing radial-background shader, foreground drawing, image slots, fit behavior, timing owner, and island frontend are unchanged.

This authorized revision supersedes the loading mesh/3D MSAA requirements. `TASK23_LOADING_EFFECTS_REPORT.md` preserves historical evidence for the earlier mesh renderer.

## Files and Controls

- Added `art/loading/california-map.svg` and its import settings: byte-identical to the supplied source, rasterized at 2x (1225x936), with mipmaps and transparency.
- Replaced `LoadingMeshBackground` with `frontend/loading/LoadingSvgBackground.gd` and `.tscn`. The SVG fits uniformly inside `(143, 82, 718, 546)` on the 960x720 canvas. All three cached targets use isolated 2D worlds; no loading camera, model, or 3D world remains.
- Replaced loading mesh materials with `loading_map_blur.gdshader` and `loading_map_composite.gdshader`. Gaussian R/G masks independently control shadow and halo; premultiplied viewport edges are corrected before compositing the sharp artwork.
- Updated `LoadingPresentation.gd/.tscn` with Background Map texture/scale/offset, tint/opacity, Outer Halo, Drop Shadow, and `refresh_background()` controls. The default texture is also the null-texture fallback.
- Removed `art/models/loading/california.glb`, its import file, the procedural loading placeholder, mesh shader, old component/material files, and their obsolete UIDs. The separate 3D island remains untouched.
- Updated `dev/LoadingPreview.gd`, `LoadingBootCapture.gd`, and `LoadingEffectsCompare.gd` for SVG replacement, first-frame/cache assertions, isolated artwork/halo/shadow captures, baseline preservation, and reference comparison.
- Updated Task 23 and export-audit tests, loading specifications, and task status. Existing unrelated changes to `RehabilitationTest.gd` are preserved byte-for-byte.

Defaults: map tint `(1.12, 1.06, 1.02, 1)`, map opacity `1`, halo color `(0.68, 0.67, 0.88, 1)`, strength `0.45`, radius `32`, direction bias `(0.30, -0.45)`, shadow color `(0.08, 0.07, 0.22, 1)`, opacity `0.10`, offset `(2, 3)`, and softness/sigma `2`. Direction bias changes only halo intensity along the silhouette, never the blur kernel. The SVG itself supplies the contour and internal glints.

## Evidence

All new evidence lives under `build/rehabilitation/loading-svg/`, keeping the older mesh report/captures intact. `mesh-baseline/` was captured immediately before editing, with the already-existing radial gradient. `after/` contains six timeline checkpoints at 960x720, 1280x720, 844x390, and 360x640, the inset case, replacement-texture capture, and isolated effects/backdrop/foreground views. `comparison.html` links the normalized references, profiles, and measurements.

- First visible composition equals the settled empty loading frame. Source and both blur passes are complete immediately, settle to disabled updates, and do not regenerate during seeking or resizing.
- All three primary frame-0011 face patches pass the eight-level RGB tolerance. Maximum primary patch channel error is 6.60.
- Foreground-masked edge profile RGB MAE: top 5.23, northeast 6.55, west 7.98, south 7.86; all pass the unchanged eight-level threshold.
- Face-patch cross-checks against frames 0010, 0040, and 0070 pass. The comparator now enforces 0040/0070 as well as the primary frame.
- Across six checkpoints, 1,208,400 pixels outside the conservative map/effects region match the pre-change baseline exactly. All sampled pixels outside each fitted composition remain black.
- SHA-256 checks confirm the radial shader, foreground script, island scene/controller, and pre-existing rehabilitation-test changes are unchanged. Runtime SVG and supplied SVG SHA-256 both equal `A448987DD3C9C973B07A4DD786F7E392A2437B429C75977AC6AC3B030FFE4A41`.
- Compatibility captures were inspected at desktop, landscape-phone, portrait-phone, and inset sizes, including the isolated subtle shadow.
- Native production boot reports `LOADING_NATIVE_BOOT_PASS active_seconds=2.0000`, with the full-bar hold and automatic island handoff.

## Validation

- Godot import/parser validation and updated Task 23 suite pass.
- Loading preview, numerical/preservation comparison, and production boot capture pass.
- Rehabilitation Tasks 00-27, all nine production scenario soaks, production flow, and Compatibility renders pass.
- `tools/validate_rehabilitation.ps1 -Render -Export` passes through Web packaging and exported resource audit (`PACK_CONTENT_PASS resources=383`). The audit requires the bundled SVG and rejects removed loading mesh/model resources.
- `node tools/smoke_web.mjs` reports `WEB_RUNTIME_NO_ERRORS`. Exported loading and island-attract screenshots were inspected; the smoke path also covers selection, running, touch, pause/resizing, retry, and island return.
- `git diff --check` passes.

## Acceptance and Limits

Loading-only functional and measured visual criteria pass. The supplied artwork preserves much finer coastline/depth details than the removed model. This is a closer interpretation of the reference, not a claim of pixel-for-pixel identity: the source capture has different softness/compression and minor silhouette differences. Foreground font, images, styling, and layout deliberately remain as before. No later numbered task was started.
