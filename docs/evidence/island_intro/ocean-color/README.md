# Static reference-textured ocean review

**Superseded:** the user rejected this processed-water result. Current production
uses the untouched screenshot described in [the replacement review](../ocean-frame/README.md).
This folder preserves the earlier attempt, not the current appearance.

Implemented 2026-10-18 against revision
`64a0912c0eba0f2bfabb89059a1e30d7e3b40f71` (`feat: add island intro handoff`).
This is the user-requested Task 23 color-texture revision, not V6 completion.
Implementation is ready for visual review; wave animation is disabled.

## Review and editing

- Desktop review: **http://127.0.0.1:8069/index.html**;
  restart with `node tools/serve_ocean_color_review.mjs`.
- Android production preview: **https://192.168.100.126:8068/index.html**;
  restart with `node tools/serve_production_web.mjs --https`. Reload after export.
- Open `art/source/island_intro/ocean-color/ocean-color.ora` in Krita.
  Its README explains exporting individual PNGs and updating runtime colors.
- `review/comparison.png` shows the user's frame 0167, lossless native source 199,
  and the rendered 3D island. `browser-handoff.mp4` is the actual exported browser
  composition with recorded wall-clock timing, not an offline composite.
- `rotation-sheet.png`, `close-beach.png`, overlap samples and portrait capture
  document the coastline and framing. New visual approval is pending.

## Reproduction commands

```powershell
# Regeneration overwrites generated art: back up manual edits first.
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/build_ocean_color_texture.py
python tools/validate_island_production.py
godot --path . --rendering-method gl_compatibility --resolution 960x720 tests/cli/OceanColorCapture.tscn
node tools/capture_ocean_color_web.mjs
node tools/smoke_web.mjs
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/finalize_ocean_color_review.py
```

Godot 4.7.2; Blender 4.2.2 LTS/NumPy 1.24.3/OpenCV 4.11.0; FFmpeg 8.0;
Node 24.19.0; Edge 155.0.4283.45; AMD Radeon RX 7600. Browser capture overhead
and callback cadence are not performance acceptance measurements.

## Evidence

- `assets.json`: source/extraction/runtime texture hashes and recipe.
- `baseline-before/results.json`: thirteen successful V5 checks before edits.
- `validation/`: final thirteen CLI/regression/production/package checks, including
  Task 23 static-texture bindings and the exact external MP4 audit. Editable ORA,
  source images, references, native previews and tests remain outside the pack.
- `checks.json`: 21 rendered/asset/preservation checks. Same-time and later-water
  captures match exactly; the full-turn return matches within 0.01 mean RGB level.
  Texture edges, ORA layers and untouched water RGB retention are checked.
- `preservation.json`: island geometry/atlas, source shore/ripple data, camera,
  handoff profile and production controller unchanged (text newline normalization
  is allowed for comparison with Git blobs).
- `recording.json`: raw composed-frame timestamps and observed browser video clock.
  Duplicate CDP timestamps keep their final image during encoding. Overlap PNG
  labels are approximate observations, not deterministic frame-lock assertions.

## Limits and next action

The extracted wave selection and neighboring-pixel fill are an editable
single-frame approximation. Faint diffuse variations remain in the base texture.
The land area is filled with nearest-water colors underneath the unchanged mesh;
this hidden fill is not intended to be viewed without the island. No AI art was
used and no extra detail is claimed beyond the reference resolution.

Review or paint the static textures first. Do not enable waves automatically.
Wave-only shader animation is a subsequent request. V2/V4 historical approvals
remain recorded, but do not approve this changed sea. V6 remains unfinished;
the user confirmed Android HTTPS startup, while model/browser details, measured
desktop/phone performance, iPhone Safari and visual review 3 are pending.
