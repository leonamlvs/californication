# 23.V3 evidence — animated ocean

V2 was explicitly approved on 2026-10-16: **"Approve V2 and implement V3 water animation"**. Its nine CLI/native/package and five browser checks were re-run immediately before V3 changes; see `../v2/resume-20261016-203614/`. The approved island mesh, atlas, Blender source, and camera data are preserved.

Start with [the water review](review/index.html), [the handoff](../../../ISLAND_INTRO_HANDOFF.md), and [preview instructions](../../../../dev/island_scene/README.md).

## Implementation

- One opaque, unshaded, two-triangle plane and one material. Exactly three texture reads per fragment.
- A 1024x1024 RGBA map: shore distance, reference cyan coefficient, local foam variation, and blue shelf coefficient. The alpha channel is data; it never makes the plane transparent.
- One 256x256 periodic grayscale texture sampled twice in world coordinates, independently of island rotation.
- Shore sampling uses the inverse island transform. Outward bands are broken up by local variation and fade into deep water.
- Explicit controller time produces bounded wave/ripple phases. No shader `TIME`, separate timer, displacement, reflection, refraction, or transparency.
- Water colors/mapping and wave/ripple settings are an editable Resource. The preview supports water-only motion, pause, seek, rotation, reference view, and relief view.

## Evidence inventory

- `asset-manifest.json`: reference/input/output hashes, texture dimensions via authoring config, Blender/NumPy/OpenCV versions, channel contract, and color-fit diagnostic.
- `maps/`: individual data channels and the offline reference-color fit.
- `validation/`: eleven Godot import/startup/regression/geometry/water/capture/package checks and build logs.
- `browser/`: eight exported Edge functional checks, including layout, pause, deterministic seeking, and real browser tab focus loss/resume. Uses SwiftShader, not a device-performance benchmark.
- `render-checks.json`: sixteen native pixel/map checks: repeatability, wave/ripple wrap continuity, world anchoring at eight angles, full rotation return, temporal continuity, packed borders, and periodic texture derivatives.
- `review/`: normal-speed water MP4, complete 72-second rotation at 5 fps, source/live comparison, rotation sheet, and wrap/long-wait stills. The rotation recording is a coverage inspection, not a measured frame-rate result.
- `review-commands.json`: exact FFmpeg encoding commands.
- `preservation.json`: hashes of the approved V2 assets compared with their recorded manifest.
- `commands.json`, `integrity.json`: reproduction commands and the current implementation/evidence snapshot.

## Reproduce

```powershell
python tools/build_island_scene_preview.py --generate-ocean --web
python tools/validate_island_scene.py
node tools/test_island_scene_web.mjs
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/capture_island_ocean_review.py
python tools/finalize_island_ocean_evidence.py
node tools/serve_island_scene.mjs
```

Then open `http://127.0.0.1:8064/water-review/index.html` or `http://127.0.0.1:8064/index.html`. Omit `--generate-ocean` when using the committed/saved textures and profile. The generator needs the same isolated OpenCV dependency as V2; setup is in the study README. It does not need the full original video or cached Godot imports. Do not use `--generate` unless deliberately rebuilding the approved island.

The normal native capture recipe remains static V2 water. The separate `--capture-ocean=<directory>` mode captures V3 to ignored build output before compact evidence is copied here. Reproducing the current water review does not rewrite the approved V2 review.

## Interpretation and limits

V3's geometry, phase, alignment, and artifact checks do not establish seamless video blending. Water colors use a constrained palette fitted to the reference cyan region; outer frozen wave rings are replaced, and the original shader/phase cannot be recovered. The offline near-water RGB fit error is recorded (approximately 17.8/255); it is not a seamlessness score. V4 must assess the actual source/live overlap and tune exposed colors/phase as needed.

Native captures use the AMD Radeon RX 7600. No new FPS acceptance or Android/iPhone result is claimed. Target-hardware performance, overlap performance, and user visual reviews 2/3 remain scheduled. Production scene/controller, loading, input, and export settings remain unchanged; V5 performs integration.
