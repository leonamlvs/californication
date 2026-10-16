# Task 23 Loading Image Fill and Lossless Optimization

> Historical revision report: this records one implemented loading revision, not an outstanding task or the live maintenance specification. The loading screen is complete and accepted under [LOADING_SCREEN.md](LOADING_SCREEN.md); [the audit](LOADING_SCREEN_DOC_AUDIT.md) distinguishes current definitions from revision history. Original measurements, dates, and results below are retained.

Revealed images now fill the existing rounded frame interiors up to their borders. The old 5-pixel inset left a visible padding gap; the unchanged 82x82 frames have a 3-pixel border and approximately 76x76 visible image area. Center-cropped textured polygons follow the rounded corners and overlap half a logical pixel beneath the border. The original border draws last, retaining its glow, highlight, position, and thickness.

Only loading image content changes. The SVG, halo, shadow, radial gradient, text, bar, connectors, timeline, island frontend, and project/export settings are preserved. Empty, missing, and unrevealed image slots retain their prior appearance.

## Changed Files

- `frontend/loading/LoadingForeground.gd`: rounded, center-cropped image fill, half-pixel underlap, original border on top, and a shared glow-only helper. No public asset properties changed.
- `art/loading/frames/loading_01.png`, `loading_02.png`, `loading_06.png`, `loading_07.png`, `loading_08.png`: smaller lossless PNG encodings. Files 03-05 remain byte-for-byte unchanged because their candidates were larger. All eight remain 75x75 with exactly identical decoded RGBA pixels. Import files, UIDs, lossless mode, and reference originals are unchanged.
- `tests/cli/LoadingImagesTest.gd` and UID: 107 Compatibility-rendered assertions for all four image edges, rounded corners, unobstructed borders, wide/tall centered cover cropping, missing textures, and unrevealed images.
- `dev/LoadingImagesCompare.gd` and UID: compares all responsive captures against the fresh baseline, permitting changes only in image-content regions, and checks decoded pixels and individual source sizes. Writes measurements and a reference/before/after comparison page.
- `dev/LoadingBootCapture.gd`: optional `--loading-output=` argument stores this revision's production boot evidence separately. Existing default behavior is preserved.
- Loading-related sections of `docs/04_UI_RESPONSIVE.md`, `05_ASSETS.md`, `06_IMPLEMENTATION_TASKS.md`, `07_IMPLEMENTATION_PLAN.md`, and `TASK_STATUS.md`: replacement contract, image-fill acceptance, compression measurements, and validation evidence.

## Sizes

| Measurement | Before | After | Change |
|---|---:|---:|---:|
| Eight source PNGs | 61,565 bytes | 60,766 bytes | -799 bytes (1.30%) |
| Eight Godot-imported textures | 39,636 bytes | 39,636 bytes | Unchanged |
| Exported PCK | 895,108 bytes | 896,196 bytes | +1,088 bytes |
| Entire Web export | 40,744,488 bytes | 40,745,576 bytes | +1,088 bytes |
| Packaged ZIP | 10,712,913 bytes | 10,713,763 bytes | +850 bytes |

Encoding used the available FFmpeg PNG encoder with `-pix_fmt rgb24 -compression_level 9 -pred mixed`. Every input was fully opaque; each candidate was checked for equal dimensions and every decoded RGBA pixel before retaining it only when smaller. Source savings by file: 01=116, 02=9, 06=401, 07=166, 08=107 bytes.

The source PNGs are slightly lighter without quality loss. Browser image data does not shrink: Godot already imports them losslessly into the same compressed textures. The small PCK increase is from the added rounded-drawing code, not larger images. The engine WASM and all other Web companion files are unchanged. No downsampling, lossy re-encoding, or global texture/export setting changes were used.

## Validation

- Fresh pre-edit Task 23 and Compatibility capture suite pass.
- Godot import/parser validation and updated Task 23 pass. Original reveal boundaries, fill plateaus, focus pause, full-bar hold at 1.95 seconds, and single two-second handoff remain covered.
- `LoadingImagesTest.gd` reports `LOADING_IMAGES_PASS checks=107`, without parser errors or warnings.
- Compatibility captures cover six checkpoints at 960x720, 1280x720, 844x390, and 360x640, plus the inset case and first visible frame. Frame 0070 was visually compared with the supplied reference on desktop and phone layouts.
- `LoadingImagesCompare.gd` reports `LOADING_IMAGES_COMPARE_PASS captures=26`: 13,277,162 compared pixels outside the eight image interiors match the fresh baseline exactly; outside changes are zero. Empty first-visible compositions are unchanged, including image interiors.
- Both the encoding check and Godot comparison confirm identical decoded pixels for all eight PNGs.
- SHA-256 validation confirms all eight import files and 12 protected loading/map/island/project/export files are unchanged.
- Production boot reports `LOADING_NATIVE_BOOT_PASS active_seconds=2.0000`, with complete first-frame map effects and the full-bar hold.
- Web export and package validation pass. Exported resource audit reports `PACK_CONTENT_PASS resources=383`.
- `node tools/smoke_web.mjs` reports `WEB_RUNTIME_NO_ERRORS`. Exported loading and attract screenshots were inspected; the smoke path also covers selection, running, touch, pause/resizing, retry, and island return. Browser captures and the clean console log are archived under this revision's `browser/` directory.
- `git diff --check` passes.

## Evidence and Acceptance

All revision evidence is under `build/rehabilitation/loading-images/`: fresh `before/`, `after/`, original `before-assets/`, lossless `candidates/`, rendered fixture PNGs, `boot/`, size/compression measurements, and `comparison.html`. Earlier dedicated SVG-revision evidence remains intact.

Image-fill, clipping, replacement, timing-preservation, and strictly lossless optimization criteria pass. The non-blocking limitation is that source PNG optimization does not reduce the already-compressed browser image payload. No unrelated system or next numbered task was implemented.
