# Island, camera, and water study — 23.V3

The user approved **V2 visual review 1 on 2026-10-16** and requested V3 water animation. This isolated study now includes animated water. The production game still runs the accepted loading/current graybox frontend; integration is V5.

## View it

```powershell
python tools/build_island_scene_preview.py --web
node tools/serve_island_scene.mjs
```

Open **http://127.0.0.1:8064/index.html**. The initial view holds the measured full reveal (source native frame 199) while the water animates. Controls:

- **Pullback:** play from the planned overlap start, then settle and rotate indefinitely.
- **Pause:** hold the current camera, rotation, and water phase.
- **Rotate:** start from the final attract pose.
- **Water:** hold the island/camera at full reveal while water continues.
- **Ref:** switch between source frame 199 and the corresponding live pose.
- **Relief:** show clay shading on the actual mesh.
- **Slider:** scrub the camera from 3.3033 through 4.137067 seconds.

The preview uses a fixed 960x720 render fitted into centered 4:3 with black unused space. It pauses on focus loss and discards the first resumed frame's delta. Video/live blending remains V4.

Native preview:

```powershell
godot --path build/island-scene-preview/project
```

The V3 water review is `docs/evidence/island_intro/v3/review/index.html`, served at **http://127.0.0.1:8064/water-review/index.html** after review generation. It includes normal-speed water motion, a complete 72-second rotation sampled at 5 fps, and comparison stills. The approved V2 review remains preserved under `docs/evidence/island_intro/v2/review/` and `/review/index.html` as historical evidence.

## Editable assets and replacement contract

| File | Purpose |
|---|---|
| `art/source/island_intro/island.blend` | Editable mesh, packed color atlas, and reference camera. Blender 4.2.2. |
| `art/source/island_intro/authoring.json` | Coast scale, elevation, terrain ridge controls/heights, atlas regions, detail tessellation, and submerged edge. |
| `dev/island_scene/assets/island.glb` | One closed island mesh; 10,766 triangles, one surface; Godot Y up. No water geometry or embedded color texture. |
| `dev/island_scene/assets/island-color.png` | The one 2048x2048 island color/lighting atlas. Base image occupies 1536x2048; a 512x512 region, including gutter, holds the road detail. |
| `dev/island_scene/assets/ocean-static.png` | Historical V2 color plate; available with `--static-water`, unused by the default V3 material. |
| `dev/island_scene/assets/ocean-shore.png` | 1024x1024 RGBA data: shore distance, cyan coefficient, foam variation, and blue shelf coefficient. |
| `dev/island_scene/assets/ocean-ripple.png` | One 256x256 periodic grayscale noise texture, sampled twice in world coordinates. |
| `dev/island_scene/ocean.tres` / `IslandOceanProfile.gd` | Editable ocean colors, map extent, wave/ripple settings, and deterministic phase sampling. |
| `art/source/island_intro/ocean-authoring.json` | Reproducible shoreline/color extraction and noise seed settings. |
| `dev/island_scene/transition.tres` | Fourteen measured camera samples and Inspector-editable settling/rotation settings. |
| `docs/evidence/island_intro/v2/reference-measurements.json` | Coastline coordinates, affine image registrations, scores, similarity approximation, and source frame/timeline mapping. |

`IslandLiveStudy` exposes the island PackedScene, atlas, ocean profile, historical color plate, and transition profile. Asset coordinates are centered on the reference picture, with 30 reference pixels per Godot unit. Sea level is Y=0; the lowest beach boundary is -0.06 and the closed underside -0.14. The island material is unshaded because lighting is baked into reference color.

The actual terrain surface has relief up to approximately 2.94 units. Its projected vertices/UVs match the reference camera at 78 degrees elevation. The original metric scale, camera projection, heights, and hidden slopes cannot be uniquely recovered from these images; these are explicit authored choices. Rotating the mesh reveals inferred terrain, not recovered original geometry.

## Water contract

The active ocean is one opaque, unshaded material on the existing 240x240 plane (two triangles). It uses exactly three texture reads: one packed shore sample and two samples of the same ripple map. There is no displacement, transparency, refraction, or real-time reflection.

The shore lookup uses `pivot.global_transform.affine_inverse()` and a 32x24.536174 world-unit map centered on the island. R stores distance divided by 4 units; G stores the reference-shaped cyan coefficient; B controls local foam variation; A stores the blue shelf coefficient. A is data, not transparency. Texture import must keep `process/fix_alpha_border=false`, lossless compression, and automatic 3D compression disabled. The packed border is constant deep water, with a smooth guard band.

Wave bands travel outward at 0.09 world units/second with 0.6-unit spacing and 0.075 maximum blend strength. Deep-water noise uses a 9-unit world tile, two directions, and 0.10 relative brightness strength. Colors and all settings are Inspector-editable in the ocean profile. The generator preserves the reference cyan shape while replacing frozen outer wave rings; wave patterns and timing are authored approximations.

`sample(time)` samples camera, rotation, and water together. `sample_water(time)` also supports holding the camera during inspection. The transition profile's `water_phase` offsets the controller time. `IslandOceanProfile.phases_at()` computes bounded phases from double-precision time, then supplies shader uniforms. The shader never reads `TIME`. Thus pausing, seeking, repeated sampling, phase wraps, and long attract waits share one deterministic path. V4 must feed this path from the coordinated video/controller clock without starting a separate water timer.

## Rebuild assets and measurements

Godot and FFmpeg/FFprobe must be on PATH. Asset tools use Blender 4.2.2's bundled NumPy 1.24.3 plus OpenCV 4.11.0.86 installed only inside ignored `build/`:

```powershell
python -m pip download --no-deps --dest build/island-authoring-wheels opencv-python-headless==4.11.0.86
& 'C:/Program Files/Blender Foundation/Blender 4.2/4.2/python/bin/python.exe' -m pip install --no-deps --target build/island-authoring-deps build/island-authoring-wheels/opencv_python_headless-4.11.0.86-cp37-abi3-win_amd64.whl
python tools/build_island_scene_preview.py --generate --web
```

Use `--blender "path/to/blender"` with the builder on another machine. Use the equivalent wheel for that machine's platform. The isolated preview can be rebuilt from the saved GLB/PNG/TRES sources without installing OpenCV or opening Blender; omit `--generate`.

Regenerate **only water**, preserving the approved island:

```powershell
python tools/build_island_scene_preview.py --generate-ocean --web
```

This invokes `tools/generate_island_ocean.py` and regenerates the two water textures and `ocean.tres` from `ocean-authoring.json`. Save any manually edited ocean profile before regenerating. It uses durable reference PNG/mask files, so neither the full original video nor `.godot` caches are needed. Integer-frequency Fourier noise (seed 2303) makes the repeating texture periodic in both axes.

Recompute reference measurements only when needed:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/analyze_island_reference.py
```

That analysis needs `.ref/music-video.mp4` with the recorded V0 hash; it uses the durable approved clip for native frames 180–190 and the original for 191–199. Existing durable measurements and PNGs suffice to rebuild the asset without the full original. Frame labels are **native decode indices**, not the old JPG extraction cadence.

The generator uses a constrained triangulation of the traced coastline, a height field controlled by named ridge points, deterministic relief noise (seed 2302), a submerged skirt, and a tessellated closed underside. The base atlas preserves native frame 199 color. Earlier frames 180–198 are registered into the road detail region, using feathered coverage and the highest available detail. This preserves actual markings but retains some source motion softness/streaking; no new blur is baked by the tool. The early close-up mesh/coast/atlas boundary still needs V4 inspection under the actual live blur and blend.

The generated `island.blend` is overwritten by `--generate`. Save manual Blender edits under a separate version or encode them in authoring data/script before regenerating. To export a manually edited replacement, select `IslandTerrain`, export GLB with selection only, Y up, and materials disabled; keep the UV atlas contract or update the study's exposed texture.

## Camera interpretation

Adjacent-frame grayscale ECC registration measures affine transforms. Invalid anisotropy/scale solutions are rejected; the camera uses the mean singular-value scale, image center, and roll. The resulting orthographic camera reproduces the measured image-space pullback without claiming the original camera's physical parameters.

Samples span 3.3033–3.737067 s. The final five clip frames start at 3.3033; the clip endpoint at 3.470133 s maps to native frame 191. The camera continues through that endpoint. After full reveal, a velocity-matched monotonic easing reaches size 25.2, target pixel (479,354), and roll -1 degree; individual components stop within the approved 0.4-second settle. Rotation eases to 5 degrees/second and then continues indefinitely. Attract does not assign a new camera pose.

The final settle values are authored, not source measurements. V4 may tune them and the blend/blur profile with recorded evidence. The nominal timing and source speed/duration are unchanged.

## Validate and regenerate review

```powershell
python tools/build_island_scene_preview.py --web
python tools/validate_island_scene.py
node tools/test_island_scene_web.mjs
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/capture_island_ocean_review.py
```

Validation checks Godot import/startup, Task 23/24, geometry/atlas/plane budgets, camera knots, 73 rotation poses, fixed final pose, ocean coverage, packed map edges, deterministic phases, native captures, and production pack exclusion. Render checks compare repeated times, phase boundaries, ocean world anchoring, and the full rotation. Browser checks run the actual exported study in Edge with SwiftShader, including real tab focus loss; they establish functional/layout behavior only. Actual device performance and seamless-transition approval remain pending.

The legacy `--capture=<directory>` recipe explicitly switches to static V2 water. V3 captures use `--capture-ocean=<directory>`; do not overwrite V2 review files with animated-water captures. `tools/capture_island_scene_review.py` remains the historical V2 review generator.

Source/evidence directories use `.gdignore`; the study is under production-excluded `dev/`. Production settings, GameFlow, shared input, loading, and the current frontend controller are unchanged. Do not promote these assets or change production startup until V5.
