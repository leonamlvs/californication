# Island Intro Implementation Handoff

## Current state

- Scope: the approved [Task 23 island revision](ISLAND_INTRO_PLAN.md), one milestone per request.
- Baseline revision: `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720` (`fix: simplify loading bar fill`). Working tree was clean before 23.V0.
- Last fully completed milestone: **23.V5 - Production integration** (2026-10-18). V2 was explicitly approved on 2026-10-16. On 2026-10-17 the user explicitly approved visual review 2: **"Approve V4 transition"**. See the [approval record](evidence/island_intro/v4/APPROVAL.md).
- The normal game now uses the approved video/live island sequence after loading. Production integration, shared input/layout preservation, companion packaging, and regression checks are complete. Actual device validation remains V6.
- V1 was rebuilt and its native/Web/production checks re-run before V2 edits. V2 import, main startup, Task 23/24, geometry/camera/rotation coverage, native captures, exported browser, and package-isolation checks pass. See [V2 evidence](evidence/island_intro/v2/README.md).
- Visual reviews 1 and 2 are approved. Visual review 3 and actual phone performance remain pending.

| Milestone | Status | Evidence / next gate |
|---|---|---|
| 23.V0 | Complete | Documents/spec links, tool versions, verified clip/frame mapping, durable references, before/after baseline checks, and export isolation recorded. |
| 23.V1 | Complete | Common adapter, exact browser clip, native OGV preview, 4:3 framing, pause/retry/release, functional browser/native checks, and package isolation. |
| 23.V2 | Complete; approved | User approved silhouette, terrain, coastline, colors, and framing on 2026-10-16. Nine native/CLI/package and five browser checks re-passed before V3 edits. |
| 23.V3 | Complete | Packed shore data, periodic ripple map, one opaque material, deterministic clock; eleven CLI/native/package, eight browser, and sixteen rendered checks pass. |
| 23.V4 | Complete; approved | Eleven CLI/native/package and twelve browser checks pass; actual exported-browser recording preserved. User explicitly approved the transition on 2026-10-17. |
| 23.V5 | Complete | Production flow, 13 CLI/package checks, exported browser playback/input/retry/focus checks; durable V5 evidence. |
| 23.V6 | In progress | Android LAN preview prepared; actual device results, measured performance and visual review 3 pending. iPhone unavailable. |

## Authoritative sources and durable evidence

See the [V0 evidence README](evidence/island_intro/v0/README.md) and [machine-readable reference manifest](evidence/island_intro/v0/reference-manifest.json).

- Runtime footage source: `.ref/island-intro/island-intro.mp4`.
- Durable identical copy: `docs/evidence/island_intro/v0/reference/island-intro.mp4`.
- SHA-256: `3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866`.
- Continuation/reference PNGs and the short reference MP4 are preserved alongside it. The 15 media assets total approximately 7.5 MB and have individual hashes in the manifest.
- Reproduction command: `python tools/capture_island_intro_reference.py`. Requires the original two videos to reproduce the full mapping; no Python packages need installing.
- A parent `.gdignore` prevents importing/exporting the evidence as runtime resources. Later milestones must explicitly promote approved derived assets into runtime locations.

### Important frame-index correction

The approved plan's original-video labels **88-191** are timeline slots. The original starts at PTS 0.033367 s, and earlier CFR decoding padded its start. With native passthrough decoding the matching indices are **87-190**, and full-reveal timeline slot 200 is **native 199 / PTS 6.673333 s**. The manifest records actual timestamps. **Playback duration, blend timing, and settling timing are unchanged.** Always use native indices for FFmpeg `select` and `trim` commands.

## Environment

| Tool | Recorded version / location |
|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf`; command `godot`; resolved to `C:/Users/Leonam Alves/Downloads/Apps/Godot_v4.7.2-stable_win64.exe/godot.exe`. |
| Blender | `4.2.2 LTS`, build date 2024-09-24; `C:/Program Files/Blender Foundation/Blender 4.2/blender.exe`. |
| FFmpeg / FFprobe | `8.0-full_build-www.gyan.dev`; both available on PATH through Chocolatey. |
| Python | `3.14.0`; command `python`; the reference script uses standard library only. |

V1 additionally used Node 24.19.0, installed Microsoft Edge (exact version in browser results), and the AMD Radeon RX 7600 for native rendering. Browser automation used SwiftShader and establishes no hardware performance result. Blender 4.2.2 successfully encoded the native development OGV.

## Implementation starting points

- `frontend/island/IslandFrontendController.gd` currently owns the accepted two-second loading timer, an eight-second staged graybox intro, hardcoded camera/FOV points, and 5-degree/second attract rotation. It resets the camera on attract entry; the revision must retain the completed live-tail pose instead.
- `frontend/island/CaliforniaIsland.tscn` is the existing CSG placeholder; `IslandFrontend.tscn` contains the static ocean plane and staged placeholders. These are unchanged in 23.V0.
- `presentation/PresentationRoot.gd` currently supports mobile-flex framing. The new fixed 4:3 rule applies only to the island states; preserve subsequent layout policy and accepted loading behavior.
- `presentation/cinematic_fx/CinematicTransitionFX.gd` currently owns a separate effect clock and can modify FOV. External sampling must preserve its existing consumers while avoiding duplicate camera ownership.
- The current Web export has no custom video shell. `tools/package_web.ps1` allows root-level `index.*` output names; the approved future video companion fits this convention.
- `tests/cli/ExportAudit.gd` forbids MP4 inside the resource pack. Preserve that check and add explicit external-companion verification when packaging the runtime video.
- `tools/smoke_web.mjs` uses software rendering and relaxed autoplay flags. It is not phone performance or default-autoplay acceptance evidence; its server needs MP4 MIME/range support in the later implementation.

## Changes in 23.V0

- Added the approved plan, this handoff, and the reference evidence README/manifest/media.
- Added `tools/capture_island_intro_reference.py` to reproduce source verification and evidence extraction.
- Linked the scoped revision from the README and architecture, responsive, asset, task, and implementation-plan specifications. These links explicitly reconcile the recorded-video/art and fixed-4:3 exceptions. Updated `docs/TASK_STATUS.md` with V0 completion separately from the historical Task 23 baseline.
- Recorded baseline evidence and tool versions. Runtime scenes/scripts, loading art, input, and export settings are unchanged.

## V0 validation and limits (historical)

Before-change checks: Godot import, main scene (90 frames), Task 23 (`TASK23_PASS`), and Task 24 (`TASK24_PASS`) all passed with exit code 0. Logs and commands are preserved under `docs/evidence/island_intro/v0/validation/`.

Reference capture passed ten sampled frame matches, verified 104 silent intro frames, verified 33 continuation frames, and preserved the exact intro bytes. Final decoded clip frame and full-island PNG were visually inspected for extraction/framing correctness; this is source inspection, not visual approval of a new render.

After-change evidence is in [baseline-after.json](evidence/island_intro/v0/validation/baseline-after.json), with all seven checks passing and exit code 0:

| Check | Result |
|---|---|
| Import and main startup | PASS; no parser/resource errors. |
| Task 23 | `TASK23_PASS`; existing loading/intro/attract acceptance preserved. |
| Task 24 | `TASK24_PASS`; existing frontend boundary preserved. |
| Fresh Web resource pack | Export succeeded using the unchanged Web preset. |
| Existing content audit | `PACK_CONTENT_PASS resources=385`. |
| Reference exclusion audit | `ISLAND_REFERENCE_EXCLUSION_PASS resources=385`; no island evidence directory/resources entered the pack. |

Reference integrity verification checked all 15 asset hashes/sizes and all 13 PNG dimensions (960x720). The capture script passed its ten sampled source matches. The exact intro source bytes are preserved. `git diff --check` passes.

These results complete V0 only. No target-device performance, new-render visual approval, or browser video playback is claimed. The full original music video is still needed to regenerate the source-matching evidence, but its absence does not block V1: the identical intro and essential continuation references are preserved in Git-visible files. Runtime files and export settings have no changes. V0 changes are saved in the working tree; no commit was created.

## Changes and acceptance evidence in 23.V1

Source and usage details are in [the preview README](../dev/island_video/README.md).

- Added `frontend/island/video/IslandVideoPlayback.gd` and `island_video.js`: common lifecycle/signals, presented video clock, browser HTML video, native VideoStreamPlayer, fixed picture rectangle, opacity, focus/pause, poster/last-frame retention, start/retry actions, and release.
- Added isolated preview templates under `dev/island_video/`. The builder creates a separate project under `build/island-video-preview/project/`, without production autoloads. Its Web export uses the exact approved MP4 as `index.island-intro.mp4` outside the PCK.
- Added build/Blender encoding, HTTP MIME/range serving, Godot validation, and browser CDP scripts under `tools/`. Added native contract/rendered tests and a separate video pack audit under `tests/cli/`.
- Preserved V0's evidence snapshot. Added compact V1 logs, source/native metadata, browser results, screenshots, and integrity hashes under `docs/evidence/island_intro/v1/`.
- Existing production scenes, controller, loading, input, main project settings, and export configuration have no changes. The historical spec/document edits from V0 remain in the working tree. No commit was created; HEAD remains the recorded baseline revision.

### Reproduction commands

Run from repository root:

```powershell
python tools/build_island_video_preview.py --web
python tools/validate_island_video.py
node tools/test_island_video_web.mjs
```

Use `node tools/island_video_preview_server.mjs`, then open `http://127.0.0.1:8063/index.html` for browser review. Native preview: `godot --path build/island-video-preview/project`. Do not run the template directly from the production project; generated preview media belongs to the isolated project.

| V1 completion criterion | Evidence / result |
|---|---|
| Clip plays once at correct speed | Browser measures source-speed progress, holds exactly 3.470133 s at completion, and does not implicitly replay. Native prepares/plays all 104 frames and completes once. |
| Startup/readiness and failure | First-frame preparation, missing native file, injected autoplay refusal, real blocked MP4 network request, and retry pass. MP4 hash matches the V0 source. |
| Shared framing and resize | Browser 360x640, 844x390 DPR 2, and 1280x720; native desktop/portrait; tab/fullscreen checks; no time reset on layout changes. Captures inspected for centered 4:3 and black unused space. |
| Pause/interruption | Manual pause, host focus gate, real browser tab hiding/return, injected media stall, last-frame retention, and currentTime fallback pass. |
| Input/resource handling | DOM click/touch start/retry do not bubble into host input. End is one-shot; explicit replay works; release removes DOM/media and is terminal/idempotent. |
| Production isolation | Import/main/Task 23/Task 24 pass before and after. Fresh production PCK passes existing audit (387 resources) and video/reference exclusion. Preview PCK passes JS-presence and OGV-exclusion audit (9 resources). |

Exact commands, exit codes, and log paths are in `evidence/island_intro/v1/validation/results.json`; before-change checks are in `baseline-before/`. Browser results record 15 checks and browser version; native screenshots show poster, paused desktop/portrait, and final-frame hold. These are playback/framing inspections, not visual approval of a new island or seamless handoff.

### Encoding decision and remaining limits

Installed FFmpeg 8.0 full Windows libtheora produced a corrupt OGV (only 10 of 104 frames decoded). The implemented reproducible workaround uses installed Blender VSE Theora at an 8000 kbit/s target, preserving 1280x720, 30000/1001, 104 frames, and no audio. FFprobe and native playback pass. See the preview README for the upstream issue. This changes only the native development preview; the browser MP4 is byte-identical.

Native OGV SHA-256: `0991165c585b951c6520cb18568fd48060be69415f421faaed9566cbdeefab83`. Generated OGV/builds are reproducible ignored outputs, not authoritative source assets. The durable source plus builder and encoding recipe suffice to rebuild them. Source hash remains `3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866`.

The browser keeps one 960x720 canvas copy of the last presented image for failure retention. Its cost needs measurement with the live scene on target phones. Native stream-position timing is only a preview approximation. Browser stalls and autoplay refusal are deterministic injected cases; actual mobile Safari/Chrome behavior is pending V6. Fullscreen must include both canvas and DOM video, as demonstrated by the preview. None of these limits blocks V2.

The adapter is not wired into production. V4/V5 must coordinate video time with camera/blur/water, readiness with the accepted loading presentation, input consumption, full-screen touch confirmation, later layout restoration, one-shot/direct-return policy, blue logo boundary, and release after handoff. Production packaging must explicitly include JS and audit the MP4 companion, and production browser tooling must adopt MIME/range support. These are scheduled work, not V1 completion claims.

## Changes and evidence in 23.V2

Working revision remains `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720`. V0, V1, and V2 are saved as uncommitted working changes. No existing production scenes/controllers, input, loading assets, project settings, or export presets were modified by V2.

### Assets and sources

- Editable source: `art/source/island_intro/island.blend`; generator controls: `art/source/island_intro/authoring.json`. Its `.gdignore` excludes editable files from imports and release.
- Replaceable GLB: `dev/island_scene/assets/island.glb`; **10,766 triangles**, one surface. Closed underside and submerged beach edge; separate two-triangle water PlaneMesh. Blender topology inspection found **zero nonmanifold edges**.
- One **2048x2048** island atlas: `dev/island_scene/assets/island-color.png`. Frame 199 supplies base color/lighting; registered frames 180–198 supply a separate high-detail road tile inside the same atlas. Original markings are preserved; no hand-built car/road assets were added.
- Static ocean color plate: `dev/island_scene/assets/ocean-static.png` (1024x1024). This is a V2 inspection aid; its frozen rings/deep-water pattern rotate with the map. V3 must replace that detail with the specified shoreline animation and world-anchored ripples.
- Camera data: `dev/island_scene/transition.tres`; resource implementation `IslandTransitionProfile.gd`; isolated scene/controller and preview are alongside them. Source measurements and preserved native frames are in `docs/evidence/island_intro/v2/`.
- Per-file asset hashes/sizes, Blender version, geometry bounds, and budgets are recorded in [asset-manifest.json](evidence/island_intro/v2/asset-manifest.json). Original video/clip hashes remain the V0 authoritative hashes above. [Reference measurements](evidence/island_intro/v2/reference-measurements.json) record NumPy 1.24.3 and OpenCV 4.11.0.

### Measured values and authored assumptions

The coast is traced from source color; image transforms are measured with adjacent-frame ECC affine registration. The live camera uses their scale/center/roll approximation. Frame 186 is 3.3033 s; frame 191 is the 3.470133 s video endpoint; frame 199 is the 3.737067 s full reveal. Source speed/duration and approved milestones are unchanged.

The orthographic projection, 78-degree camera elevation, 30 pixels/unit, terrain heights, and hidden slopes are **authored inferences**, not recovered original geometry. Vertices and UVs are projected through that reference camera, preserving the observed appearance at full reveal. The mesh has actual relief up to about 2.94 units and can rotate through 360 degrees; it is not a billboard.

Recorded settle tuning: orthographic size 24 at reveal, ending at **25.2**; image target (480,360) ending at **(479,354)**; roll 0 ending at **-1 degree**. A monotonic easing preserves the last measured velocity and stops each component within the 0.4-second settle. Rotation eases to 5 degrees/second by 4.137067 s, then continues. There is no attract camera reset. No runtime radial blur or video/live blend is included in V2.

### Reproduction and review

See [study README](../dev/island_scene/README.md) for the full asset contract, local tool dependency setup, source extraction, manual export guidance, and limitations.

```powershell
python tools/build_island_scene_preview.py --web
python tools/validate_island_scene.py
node tools/test_island_scene_web.mjs
```

To regenerate assets, add `--generate` to the builder (requires Blender and the isolated OpenCV tool dependency described in the README). Saved GLB/PNG/TRES files suffice for the normal preview build. Generation replaces `island.blend`; preserve any manual edits separately or encode them in the controls/generator first.

Native study: `godot --path build/island-scene-preview/project`.

Browser: `node tools/serve_island_scene.mjs`, then **http://127.0.0.1:8064/index.html**. Visual review page: **http://127.0.0.1:8064/review/index.html** (durable copy at `docs/evidence/island_intro/v2/review/index.html`). Regenerate the review after captures with:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/capture_island_scene_review.py
```

### Checks and acceptance status

- Rebuilt V1 and re-ran its CLI/native/Web/package checks before editing; all passed. Evidence under V2 `baseline-before/` preserves this resume check.
- V2 final CLI suite: import, main 90 frames, Task 23, Task 24, island contract, native captures, fresh production PCK export, existing content audit, and source isolation — **nine checks pass**. Command arrays/exit codes are in V2 `validation/results.json`.
- Island contract checks the triangle/atlas/plane budgets, 14 camera knots, 73 rotation poses without clipping, coastline transform alignment, ocean coverage, indefinite 5-degree/second rotation, and settled camera continuity.
- Exported Edge preview: **five functional checks pass**, covering startup/reveal, pullback/pause, portrait/landscape/wide resize, reference/relief controls, and rotation. Screenshots are in V2 `browser/`. SwiftShader results are functional evidence only; native captures used AMD Radeon RX 7600.
- Matched full-reveal stills, five pullback samples, camera MP4, eight-angle contact sheet, and clay view are in V2 `review/`. Full-reveal land RGB mean absolute difference is about **1.84/255**, expected from projection of source pixels; it does not prove reconstructed 3D accuracy or seamless motion.
- **Visual approval 1: approved after these captures.** On 2026-10-16 the user answered: "Approve V2 and implement V3 water animation". See [approval record](evidence/island_intro/v2/APPROVAL.md). The original review artifacts retain their historical capture-time labels.

### Remaining limits

The reference does not uniquely determine hidden terrain. Close-up samples show residual atlas/coast differences and source motion softness/streaking, especially before the full reveal. V4 must inspect those differences under the real blur/blend; do not claim that blur has already solved them. The static V2 water plate is now retained only for historical comparison. Actual Android/iPhone playback/performance and later visual reviews remain pending. The V2 visual gate was subsequently approved.

## Resume check — 2026-10-16 (before explicit approval)

The latest request was "Implement next step." Visual approval 1 is still unrecorded; that request alone has not been recorded as approval of the island's appearance. A clarification asks whether the user approves V2 and wants V3, or wants V2 revisions first. No runtime or asset changes were made during this resume check.

- `python tools/validate_island_scene.py`: all nine checks passed again, including native captures, Task 23/24 regressions, and production isolation.
- `node tools/test_island_scene_web.mjs`: all five exported-browser functional checks passed again. SwiftShader does not establish device performance.
- The local review page at `http://127.0.0.1:8064/review/index.html` returned HTTP 200.
- Fresh command records and logs are preserved in [resume evidence](evidence/island_intro/v2/resume-20261016-203614/validation/results.json); [browser results](evidence/island_intro/v2/resume-20261016-203614/browser-results.json) are stored separately from the original V2 evidence.
- V3 remains unstarted. The next action is to resolve the pending visual review, then implement the requested water milestone if approved.

## Changes and evidence in 23.V3

Working revision remains `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720`, with uncommitted V0-V3 changes. The user's exact V2 approval is recorded above. The fresh V2 resume checks provided the baseline before V3 edits. Production loading/frontend/input/configuration and the approved V2 island assets remain unchanged; [preservation hashes](evidence/island_intro/v3/preservation.json) check the latter against the V2 manifest.

### Files and implementation

- `art/source/island_intro/ocean-authoring.json` and `tools/generate_island_ocean.py`: reproducible source-color/shore extraction and periodic noise generation. Only the durable native frame 199 and V2 land mask are needed; no full original video or cache is required.
- `dev/island_scene/assets/ocean-shore.png`: **1024x1024 RGBA data**, 866,893 bytes. R = shore distance / 4 units; G = cyan coefficient; B = foam variation; A = blue shelf coefficient. Lossless import keeps alpha-border repair and automatic 3D compression disabled, because A is data.
- `dev/island_scene/assets/ocean-ripple.png`: **256x256 grayscale periodic noise**, 25,566 bytes; seed 2303, integer Fourier frequencies. Two generations produced identical texture hashes.
- `dev/island_scene/ocean_animated.gdshader`: **one opaque unshaded material on the existing two-triangle 240x240 plane**. Three texture reads: one shore map plus two reads of the ripple texture. No displacement, transparency, refraction, or reflections.
- `dev/island_scene/IslandOceanProfile.gd` and `ocean.tres`: editable colors, shore mapping, wave/ripple controls, and bounded phase sampling. `IslandLiveStudy.gd` passes the inverse island transform to the shore lookup; deep-water coordinates remain in world space.
- `IslandScenePreview.gd`: water-only motion, pause/seek/full rotation, fixed 4:3, wrapped controls on narrow windows, focus freeze/resume without carrying hidden elapsed time. Historical `--capture` explicitly uses V2 static water; V3 uses `--capture-ocean` and separate evidence.
- `tests/cli/IslandOceanTest.gd/.tscn`, updated builder/validator/browser checks, and `tools/capture_island_ocean_review.py`: contract checks, rendered continuity/rotation checks, compact videos/stills. `tools/finalize_island_ocean_evidence.py` preserves successful results and hashes.

Default tuning: map size **32 x 24.536174 units**, distance range **4**, wave spacing **0.6**, outward speed **0.09 units/s**, maximum foam blend **0.075**, reach **2.2**, breakup **0.3**; world ripple tile **9 units**, brightness strength **0.10**, UV velocities **(0.012,0.007)** and **(-0.008,0.011)**. Colors: deep `#06144c`, shelf `#1268b5`, shallow `#80e9e1`, foam `#b2eaf2`. Phase origin is the full reveal, **3.737066667 s**; transition-profile `water_phase` remains zero.

`sample(time)` samples camera, rotation, and water together. `sample_water(time)` holds the camera for inspection. The profile derives bounded periodic uniforms from double-precision controller time; the shader does not use `TIME`. Float32 UV values that round to 1 are normalized to the equivalent 0. V4 must feed these functions from the coordinated video/controller timeline; no additional water timer is needed.

### Commands, versions, and checks

```powershell
python tools/build_island_scene_preview.py --generate-ocean --web
python tools/validate_island_scene.py
node tools/test_island_scene_web.mjs
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/capture_island_ocean_review.py
python tools/finalize_island_ocean_evidence.py
```

Omit `--generate-ocean` for a normal rebuild from saved assets. It regenerates the two textures and `ocean.tres`, so save any manual profile edits first. Do not use `--generate` unless intentionally rebuilding the approved island. OpenCV dependency setup is in [the study README](../dev/island_scene/README.md).

Tools remain Godot **4.7.2**, Blender **4.2.2 LTS**, NumPy **1.24.3**, OpenCV **4.11.0**, FFmpeg **8.0**, Node **24.19.0**, and Edge **155.0.4283.45**. Native captures used the **AMD Radeon RX 7600**; browser checks used SwiftShader. Source/output hashes are in [the V3 asset manifest](evidence/island_intro/v3/asset-manifest.json); exact commands, exit codes, and logs are under [V3 evidence](evidence/island_intro/v3/README.md).

- **Eleven CLI/native/package checks pass:** import, main startup, Task 23, Task 24, island contract, ocean contract, legacy captures, animated ocean captures, fresh production export, existing content audit, and study/source exclusion. Production still contains **387 resources** with no V3 study/assets.
- **Eight exported-browser checks pass:** startup, camera/pause, portrait/landscape/wide layouts, reference/relief controls, attract camera, water-only pause, deterministic seeking/day-long time, and real tab focus loss/resume. Hidden tabs suspend Godot's published state; the browser check observes document visibility and the held water clock directly.
- **Sixteen rendered/map checks pass:** same-time captures are byte-identical in RGB; the full-turn return differs by less than 0.00004/255 mean; sampled deep-ocean patches remain identical at eight rotation angles. Wave/UV wrap boundaries differ by at most 1/255 per channel. Packed edges meet constant deep water and periodic-noise edge derivatives stay within ordinary interior variation.
- Full-rotation contact sheet and portrait layout were inspected. The cyan region follows the coast, with no visible beach gaps, rectangular texture boundary, or ocean coverage hole. Motion remains intentionally faint; the recorded five-second fixed-camera clip makes it easier to inspect.

### Preview, acceptance, and remaining limits

Run `node tools/serve_island_scene.mjs` and open **http://127.0.0.1:8064/index.html**. It starts with animated water over a stationary island; use **Rotate** for attract. The compact review is **http://127.0.0.1:8064/water-review/index.html**, with a durable copy in `docs/evidence/island_intro/v3/review/`. The local review route returned HTTP 200.

**V3 acceptance is satisfied.** Shore waves follow the rotating coast, world ripples remain subtle and independent, pauses/seeks/wraps remain continuous, and the flat ocean covers every authored camera pose. Visual review 1 remains the user's V2 approval; reviews 2 and 3 are still pending. Automated/rendered V3 checks do not approve the future video blend.

The original water shader and phase cannot be recovered uniquely. The cyan shape comes from the reference, while wave timing/patterns and the constrained color palette are authored approximations. Frozen outer reference wave rings were replaced. The offline near-water palette-fit diagnostic is about **17.8/255 mean RGB error**; this is not a seamlessness score. V4 must compare the actual overlap and tune exposed colors/phase if needed. Approved island geometry/atlas/camera are preserved. Hardware FPS, Android/iPhone behavior, and overlap performance remain unmeasured and belong to V6 (overlap inspection begins in V4). None of these limits blocks the V4 implementation.

## Changes and evidence in 23.V4

Implementation and validation finished on 2026-10-17; **visual review 2 was explicitly approved by the user: "Approve V4 transition"**. HEAD remains `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720`; V0-V4 are uncommitted working changes. At completion of that request, the last fully completed milestone was V4.

### Implementation and tuning

- Added `dev/island_transition/`: isolated controller/scene, presentation clock, handoff profile, live-only blur shader/profile, and browser controls. The V1 adapter supplies presented media time. The controller samples camera, water, opacity, and blur together, then continues from the exact media endpoint into the existing live camera tail and rotation without resetting the pose.
- Added optional shader/softness properties to `data/definitions/CinematicFXProfile.gd` and external sampling to `presentation/cinematic_fx/CinematicTransitionFX.gd`. Existing profiles retain the original shader and behavior. External mode receives no camera, holds on focus/resize, and is explicitly canceled by its controller. Task 22/23/24/26 regression checks pass, including restoration of the normal shader/FOV behavior after external use.
- The video/live view shares centered 4:3 framing. Scene/effect warmup runs behind the first-frame poster. Buffering, pause, failure, and lost focus hold the coordinated presentation. Retry resets the clock and clears host pause. Video is released after the completed handoff. Direct attract/replay remain available in the isolated toolbar.
- Added build/server/validation/browser/capture/evidence tools named `*island_transition*`; deterministic `tests/cli/IslandHandoffTest.*`; extended `IslandScenePackAudit.gd` to exclude the new preview from production.
- No V2 geometry, atlas, camera, V3 water assets/shader/profile, or live study changes. No production scenes/controllers, loading assets, input system, project settings, or export preset changes. The two shared cinematic files above are the only existing runtime files changed by V4. Production flow/package integration remains V5.

Initial recording inspection showed excessively sharp live coastline edges during the fast pullback. Final tuning adds live-only screen mipmap softening at LOD **3.5**, radial strength **0.22**, center **(0.5,0.5)**, **12 desktop / 4 mobile** radial samples, zero FOV kick, and no fade overlay. Envelope knots: `(3.3033,.65), (3.4367667,.85), (3.5035,1), (3.6036,.65), (3.7370667,.15), (3.90,0), (4.1370667,0)`. Video opacity follows inverse smoothstep from 3.3033 to 3.470133333 seconds. Source speed/duration, measured camera knots, reveal/settle times, water phase, and approved colors are unchanged. These settings live in replaceable profiles, not controller constants.

### Reproduction, checks, and review

See [preview instructions](../dev/island_transition/README.md) and [V4 evidence](evidence/island_intro/v4/README.md).

```powershell
python tools/build_island_transition_preview.py --web
python tools/validate_island_transition.py
node tools/test_island_transition_web.mjs
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/capture_island_transition_review.py
python tools/finalize_island_transition_evidence.py
node tools/serve_island_transition.mjs
```

- Before editing, re-ran V3's eleven CLI/native/package and eight browser checks successfully; preserved under V4 `baseline-before/`.
- Final **eleven CLI/native/package checks pass**: Godot import/main startup, Tasks 22/23/24/26, simulated-clock/FX contract, native rendered playback-to-attract, fresh production export, existing content audit (387 resources), and source exclusion.
- Final **twelve browser checks pass**: playback-to-attract/release, actual composed recording, pause, portrait/landscape/wide resize, containing-element fullscreen, buffering, real tab focus loss during blend, retained error/Retry including host pause, rejected autoplay/start, direct attract, `currentTime` fallback, exact MP4/byte ranges/no runtime errors. Error/stall/autoplay refusal are injected cases; native automated capture simulates active focus in a hidden window.
- Actual browser recording: **677 frames / approximately 7.049 seconds**, encoded with captured wall-clock timestamps. No offline video/live compositing. Eight overlap/settle PNGs, a contact sheet, trace, commands, logs, native screenshot, and browser framing/error screenshots are preserved durably. Sample inspection found no black sample and confirmed softened live edges and centered framing; automated checks do not establish seamless appearance.
- Browser: Edge **155.0.4283.45**, accelerated **AMD Radeon RX 7600 / ANGLE D3D11**. Godot/Blender/FFmpeg/Python versions remain listed above; Node 24.19.0, Blender NumPy 1.24.3 and isolated OpenCV 4.11.0 were used. The recording's rAF cadence during both overlap and attract was about **4.20 ms median / 4.30 ms p95**. This measures instrumented callback cadence, not delivered game FPS or GPU frame time; V6 performance acceptance remains pending.
- `preservation.json` confirms approved V2 assets and the entire V3 study/camera/water implementation are unchanged. `integrity.json` records V4 implementation/evidence hashes and HEAD. The external MP4 retains authoritative SHA-256 `3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866`.

**Review URL:** http://127.0.0.1:8065/review/index.html. Interactive preview: http://127.0.0.1:8065/index.html. Native: `godot --path build/island-transition-preview/project`. The server serves local assets only; restart using the command above if unavailable. At V4 completion the normal game did not yet show this sequence; V5 below integrates it. The preview continuation prompt is visual only; whole-screen confirmation and the blue logo boundary belong to V5.

### Approval and remaining limitations

Visual review 2 is **approved**; see [the explicit approval record](evidence/island_intro/v4/APPROVAL.md). Capture-time pending labels in the review artifacts and integrity snapshot are historical and superseded by this approval. No runtime changes or new test runs were needed to record approval. Reconstruction and water retain their documented authored approximations; no exact source reconstruction is claimed. Actual Android/iPhone autoplay, performance, and visual review 3 remain pending V6. V5 was not started at that historical checkpoint; see the completed integration below.

## Changes and evidence in 23.V5

Completed 2026-10-18. HEAD remains `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720`; V0-V5 are uncommitted working changes. [V5 evidence](evidence/island_intro/v5/README.md) contains exact commands, exit codes, package manifest, browser captures, and source hashes.

### Implementation and audit fixes

- Promoted the approved island/atlas/shore/ripple assets byte-for-byte into `frontend/island/live/`; copied approved camera/water/handoff profiles with distinct runtime class names. Editable sources and isolated previews remain available. No art regeneration or transition retuning.
- `IslandProductionSequence.gd/.tscn` connects preloading, warmup, native/Web playback, synchronized camera/water/blur, indefinite rotation, poster/retry/focus handling, and resource release to GameFlow. It shares one viewport-derived 4:3 rectangle with the HTML adapter. Web document focus owns pause behavior; native uses focus notifications.
- `IslandFrontendController.gd/.tscn` retains accepted two-second loading and blue environment ownership; removes obsolete placeholder intro geometry/animation. The old ocean stays hidden at the logo boundary so it cannot occlude the logo's blue plane.
- `PresentationRoot.gd/.tscn` mounts the sequence and keeps island states in 4:3. `Main.tscn` puts the existing shared touch surface at the root so black-border taps work. Later layout resumes during the blue cover. The cover matches the logo plane's material. DevHarness now previews the production sequence.
- `package_web.ps1` packages and hashes the exact external `index.island-intro.mp4` plus poster. Web excludes native OGV, old island placeholder, references, authoring sources, tests and previews. Local browser serving supports MP4 MIME and byte ranges.
- Audit fixed invisible/zero-sized presentation, premature DOM poster over loading, hidden viewport warmup, stale canvas focus after Retry, retained poster after retry, and old ocean geometry bleeding into the blue logo handoff. Final browser captures were inspected after fixes.

### Reproduction and validation

```powershell
python tools/validate_island_production.py
node tools/smoke_web.mjs
python tools/finalize_island_production_evidence.py
node tools/serve_production_web.mjs
```

Normal native entry: `godot --path .`. Production browser: **http://127.0.0.1:8066/index.html**. The server must be running and `build/web` must have been exported. Runtime ownership/native-media regeneration are documented in [the runtime README](../frontend/island/live/README.md).

- Before editing, V4's eleven CLI/native/package and twelve browser checks re-passed; baseline result records preserved under V5 `baseline-before/`.
- Final thirteen checks: Godot import/main startup, Tasks 22/23/24/26, shared Tasks 01/02/03, production flow and nine scenario soaks, Web packaging, general pack audit, and island resource/exclusion audit. Task 23 now checks real production resources, readiness, interruption holds, camera continuity, rotation, direct returns and shared confirmation instead of obsolete placeholder geometry.
- Exported browser: default-policy video startup, injected error/Retry, actual tab focus loss during overlap, release after handoff, portrait 4:3, black-border touch into Player Select, gameplay/swipe/pause/resize/death/retry/direct island return, no runtime errors. Captures include loading, video, overlap, attract, logo boundary and later screens. Buffering/error/gesture clock holds are also covered deterministically; adapter buffering/autoplay refusal coverage remains in the V4 baseline.
- ZIP contains the exact authoritative MP4 hash `3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866`, 11 files, approximately 47.54 MB uncompressed. See `validation/package.json` for exact bytes. No MP4/OGV is embedded in the resource pack; no editable/reference/preview assets are shipped.
- Tools: Godot 4.7.2, Python 3.14, Node 24.19.0, Edge 155.0.4283.45. Browser uses accelerated AMD Radeon RX 7600. Blender 4.2.2/FFmpeg 8 sources remain reproducible from previous milestones; V5 did not regenerate approved art.

**V5 acceptance is satisfied.** Visual reviews 1 and 2 remain the user's explicit approvals. Browser checks and desktop screenshot inspection are functional evidence, not phone performance acceptance. Actual Android Chrome/iPhone Safari tests, sustained measured frame rates and visual review 3 remain pending V6. Authored reconstruction/water limitations remain as documented above; none blocks V5. Non-blocking CLI diagnostic: Task 23's immediate shutdown reports four shared Music/SFX audio ObjectDB instances (identified by a verbose rerun); no parser/resource or browser runtime errors occur. See V5 evidence for details.

## V6 progress - 2026-10-18

V6 has started; **V5 remains the last fully completed milestone**. Fresh V5 baseline validation passed all thirteen checks before device work; the result record is preserved under `evidence/island_intro/v6/baseline-before/`.

The user now has an Android device available for browser testing; no iPhone is available. `tools/serve_production_web.mjs --lan` serves only the exported `build/web` directory on port 8067, while the default command remains localhost-only on 8066. The hidden background server is running. Current phone URL: **http://192.168.100.126:8067/index.html** (computer and phone must share the LAN; the address can change). HTML returned 200 and MP4 returned 206 with video/mp4 and the requested 32 bytes from the host computer. This does not establish phone reachability. No firewall settings were changed; the Windows Ethernet profile is Public.

Android connection/model feedback has been requested. Follow the [device checklist](evidence/island_intro/v6/README.md). Actual desktop/Android performance measurements and final visual approval are still pending. No runtime presentation or approved assets were changed. The device setup does not complete V6.

## Next action and resume prompt

V6 HTTPS correction: Android reached the HTTP page but reported missing Secure
Context; HTTPS on the HTTP port reported ERR_SSL_PROTOCOL_ERROR. Added optional
TLS support to the shared local server, `--https` on port 8068, and reproducible
`tools/prepare_island_https.ps1`. Current phone URL is
**https://192.168.100.126:8068/index.html**. The local seven-day self-signed
certificate requires a browser exception for this preview. Host-side certificate,
hostname, HTML and MP4 range checks pass; phone playback remains pending.
Keys are ignored under build and are not served or packaged. No runtime game
or approved asset changes were made. See V6 README and `https-checks.json`.

**Current milestone: 23.V6 - Device validation.** First unfinished criterion: confirm Android Chrome can reach the LAN preview and record its device/browser version. Then capture appearance and measured performance on available devices. iPhone is unavailable; keep that criterion and visual review 3 pending. Do not infer hardware performance from smoke-test timing.

> Read the island plan and handoff, inspect repository changes, and verify V5 recorded checks. V0-V5 are complete; visual reviews 1 and 2 are explicitly approved. Implement only requested V6, beginning with actual target device validation. Preserve the approved presentation, loading, shared input, and frontend behavior. Record measured evidence and any device access limits; obtain visual review 3 explicitly before declaring V6 complete.
