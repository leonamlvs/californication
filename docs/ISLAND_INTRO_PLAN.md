# Island Intro: Video, 3D Island, and Animated Ocean

## 1. Objective and document status

Create a continuous transition from the supplied video into a rotating 3D island above a flat, animated ocean. Preserve the reference's framing, colors, camera movement, and subtle water motion.

This is the user-approved specification for the Task 23 island revision. It replaces the earlier island reconstruction plan. Implementation status and acceptance evidence live in [ISLAND_INTRO_HANDOFF.md](ISLAND_INTRO_HANDOFF.md); saving these documents and recording the baseline is milestone **23.V0**.

Work on **one milestone per implementation request**, then update the handoff and stop. Preserve the accepted loading presentation, shared input system, and subsequent frontend behavior. Do not begin Task 24 or another numbered task.

### Locked decisions

- Use `.ref/island-intro/island-intro.mp4` as the runtime footage. A byte-identical durable copy is preserved in the [V0 reference bundle](evidence/island_intro/v0/README.md).
- Keep the complete 4:3 composition on every device, with black unused space.
- Model mountains, terrain, and beach as the island's 3D mesh.
- Render all water, from cyan shallows to dark blue ocean, on one flat plane.
- Continue into indefinite island rotation.
- Use local tools, including Blender and FFmpeg.
- Target 60 fps for live rendering on desktop and 30 fps on phones. Video retains its original frame rate.

The supplied clip contains **104 frames at 30000/1001 fps**, lasts **3.470133 seconds**, and has no audio. Its active picture is 960x720 inside a 1280x720 encoded frame, with 160-pixel side borders.

### Approved spec exceptions and boundaries

The user explicitly authorized the following Task 23 exceptions. They supersede the general graybox/reference-only wording for this island revision:

- The recorded opening replaces the prior close-vegetation/city/landscape geometry reconstruction. No individual tree, rock, car, or road models are required for those recorded stages.
- Reference-derived final island textures, island geometry, and animated water are in scope for milestones 23.V2-23.V4. The rest of the game retains its current asset policy.
- `ISLAND_INTRO` and `ISLAND_ATTRACT` use fixed 4:3 framing on phones as well as desktop. Subsequent screens retain their existing responsive policy.
- The approved MP4 is a named external web companion asset. The complete original music video, development references, editable sources, and native preview video remain excluded from release.
- Existing loading acceptance criteria are preserved. Its two-active-second timer is presentation timing, not download progress.
- Visual tuning is data-driven and documented. No new gameplay states or scenario-specific input systems are authorized.

The historical staged-group and placeholder-size criteria remain baseline implementation evidence until explicitly replaced by the new presentation checks. Do not report the new island revision complete from old Task 23 passes.

## 2. Choreography and visual continuity

The clip ends during the fast, blurred pullback. The live scene must continue that movement.

| Timeline | Presentation |
|---|---|
| **0-3.303 s** | Supplied video, fully visible; live scene prepared underneath. |
| **3.303-3.470 s** | Smooth blend across the final five blurred frames into the matching live scene. |
| **3.470-3.737 s** | Live camera continues pulling back to reveal the complete island. |
| **3.737-4.137 s** | Camera and blur settle; island rotation eases into 5 degrees/second. |
| **After 4.137 s** | Indefinite rotating-island attract state with the existing continuation prompt. |

These are the initial authored timings, rounded in the table. Clip frame 99 starts at 3.303300 s, the clip ends at 3.470133 s, original timeline slot 200 maps to intro time 3.737067 s, and the initial settle lasts 0.4 s. Any visual tuning must be recorded in the transition profile and handoff; preserve the supplied clip's speed and duration.

### Reference matching

**V0 numbering correction, preserving the approved timing:** the approved plan labels the source segment **88-191** and the full reveal **200**. Measurement found that the original video's first presentation timestamp is 0.033367 s, whereas the supplied clip starts at zero. The earlier comparison used a constant-frame-rate output that padded the original's beginning. Those approved numbers are therefore timeline slots, not zero-based native decode indices.

Use **native original frames 87-190** for the clip match, and **native frame 199 / PTS 6.673333 s** for full-reveal timeline slot 200. Native frame 200 is also preserved as a neighboring fully revealed island reference. The supplied clip's indices remain **0-103**. This corrects reference extraction labels, not the approved choreography or footage.

The V0 manifest records measured sample matches, actual presentation timestamps, source hashes, and exact extraction commands using `-fps_mode passthrough`. Numbered JPGs from the earlier `.ref/frames` extraction use a different cadence; do not substitute their numbers for native video indices.

Use the original video's following frames as reference for:

- Island silhouette, terrain ridges, beach, and water colors.
- Camera position, orientation, zoom center, and apparent shrinking speed.
- Blur strength and direction.
- Shore-wave appearance and phase.

The overlap must match both **image and movement**. Apply radial blur only to the live render because the video already contains it. Complete the camera animation without resetting its pose when entering attract.

## 3. Implementation specification

### Island

- One replaceable island asset, limited to mountains through beach.
- Initial ceiling: **15,000 triangles** and one **2048x2048 color atlas**.
- Bake surface detail and lighting, including tiny visible road markings required near the handoff.
- Let the beach meet the water plane; extend its lowest edge slightly below water level to prevent gaps.
- Preserve the editable Blender source and reproducible export commands.

### Ocean

Use one opaque, unshaded `PlaneMesh`, with **two triangles and one material**. Size it to cover every approved camera pose.

The shader combines two effects:

**Cyan shallows and shore waves**

- Generate a **1024x1024 packed data texture** containing distance from shore, the reference-shaped cyan region, and foam-strength variation.
- Animate faint bands outward along the shore-distance field.
- Break up the bands with noise and fade them smoothly into deeper water.
- Derive shoreline sampling coordinates from the island transform so the cyan region and shore waves follow its rotation.

**Dark blue water**

- Sample one **256x256 repeating ripple/noise texture** twice, scrolling slowly in different directions.
- Use the combined samples for subtle color and brightness changes.
- Anchor this pattern to world coordinates so the surrounding sea does not spin with the island.

Blend both effects within the same shader. Use an explicit controller-driven water clock so pauses and transition previews remain deterministic.

The production baseline uses opaque color shading, with no water displacement, transparency, refraction, or real-time reflections.

### Video and synchronization

Use browser-native HTML video above the Godot canvas. Preserve the supplied H.264 stream; remux only if required for progressive playback. Generate an OGV counterpart for native development previews, excluded from the web package.

Add these interfaces:

| Component | Responsibility |
|---|---|
| **Video playback adapter** | Prepare, play, pause, restart, release; report readiness, presented time, completion, and errors; accept picture rectangle and opacity. |
| **Island transition profile** | Store camera curves, blend timing, blur settings, water phase, and final attract pose. |
| **Ocean profile** | Store colors, shoreline mapping, wave spacing/speed/strength, and ripple settings. |

`GameFlow` remains the global state owner. The island controller coordinates presentation.

Use presented video time through `requestVideoFrameCallback`, with `currentTime` as the browser fallback. Continue from the video endpoint using the controller clock. Sample camera, blur, water, and opacity from this coordinated timeline.

Adapt the shared cinematic effect to accept externally sampled progress while retaining its existing behavior for other consumers. The island controller alone owns its camera/FOV animation.

### Framing, readiness, and failure handling

- Share one centered 4:3 picture rectangle between video and Godot.
- Crop only the video's encoded black side borders.
- Refresh alignment on resize, orientation changes, and fullscreen changes.
- Preload during startup/loading; start video only after its first frame and the live scene are ready.
- Preserve the accepted two-second loading presentation. If preparation runs longer, display the video's first-frame poster afterward.
- Pause both playback and presentation on focus loss or buffering.
- If autoplay requires a gesture, present a start action over the poster.
- On playback failure, retain the last valid image and offer Retry.
- Consume start/retry/confirm input once, preventing leakage into later states.
- Release video resources after the completed handoff.

### Integration and packaging

- Preserve one-shot intro playback and direct returns to attract.
- Preserve whole-screen touch confirmation, including black borders.
- Restore later screens' existing layout policy during their covered transition.
- Preserve the existing blue handoff into the logo sequence; prevent the new ocean material from introducing a boundary flash.
- Package the approved clip as `index.island-intro.mp4`, outside the Godot resource pack.
- Validate that exact companion asset separately. Continue excluding original references, editable assets, and development previews.
- Update the local browser server to serve MP4 correctly, including byte-range requests.

## 4. Short milestones

Work on **one milestone per implementation request**. Each milestone ends with validation, evidence, and an updated handoff. Visual previews remain development-only until production integration in 23.V5.

| Milestone | Deliverable | Completion gate |
|---|---|---|
| **23.V0 - Documents and baseline** | Save both documents; record source hash, frame mapping, tool versions, baseline results, and relevant spec exceptions. Preserve essential reference evidence outside ignored caches. | Another session can identify the authoritative source, decisions, and first unfinished step. |
| **23.V1 - Video playback** | Playback adapter, browser preview, native preview, shared framing, and interruption handling. Keep unfinished presentation isolated from production flow. | Clip plays once at correct speed; startup, resize, pause, retry, and framing checks pass. |
| **23.V2 - Island and camera** | Editable island, baked texture, static ocean colors, and measured live camera continuation. | **Visual review 1:** matched stills and camera preview establish silhouette, coastline, color, and composition. |
| **23.V3 - Water animation** | Packed shoreline map and combined ocean shader with controller-driven timing. | Cyan waves follow the coast through rotation; blue ripples remain subtle; no gaps, texture-boundary artifacts, or visible animation reset. |
| **23.V4 - Seamless handoff** | Synchronized blend, live blur, camera continuation, and transition into rotation. | **Visual review 2:** exported-browser recording shows one continuous pullback at normal speed. |
| **23.V5 - Production integration** | Connect the completed sequence to loading/attract; preserve input and logo boundaries; update development shortcuts, packaging, and regression checks. | Existing acceptance criteria pass, and production export contains only approved assets. |
| **23.V6 - Device validation** | Desktop, Android Chrome, and iPhone Safari evidence; measured optimization where necessary. | **Visual review 3:** appearance and performance pass on actual target devices. |

Visual approval must be recorded explicitly. Automated checks do not establish that a transition looks seamless.

## 5. Validation and handoff contract

### Required checks

- Godot CLI import/startup validation, with no new parser errors or missing resources.
- Task 23 and Task 24 regression checks; shared layout/input and production-flow checks after integration.
- Replace obsolete placeholder-geometry assertions with playback and continuity assertions while preserving loading and input coverage.
- Deterministic transition checks using a simulated playback clock.
- Browser tests for buffering, rejected autoplay, retry, focus loss during the blend, resizing, and orientation changes.
- Full island rotation check for shoreline alignment, beach gaps, texture seams, and ocean coverage.
- Frame inspection around the overlap: no black frame, doubled coastline, exposure jump, scale jump, or camera reset.
- Long attract wait, direct attract entry, return from gameplay, and repeated confirm/touch checks.
- Production package audit and browser playback from the packaged output.

Measure performance during both the overlap and steady attract. Existing software-rendered browser smoke tests are functional evidence only; use actual hardware for performance acceptance. Phone validation stays pending until those devices are available.

### Every handoff must record

- Current repository revision and relevant working changes.
- Last fully completed milestone and evidence supporting completion.
- Current milestone, completed criteria, and first unfinished criterion.
- Asset locations, source hashes, generation commands, and tool versions.
- Exact validation commands, results, and capture locations.
- Visual approvals and any pending review.
- Known limitations and whether they block the next step.
- A concrete next action.

Store essential sources, scripts, and compact evidence durably. Reference files and `.godot` caches alone are insufficient for a handoff. Use `.gdignore` for development evidence containing media so it cannot enter the resource pack.

### Resume instruction

> Read the island plan and handoff, then the relevant project specifications. Inspect repository changes and verify the last completed milestone using its recorded checks. Implement only the requested Task 23 milestone, beginning with its first incomplete criterion. Preserve accepted loading and frontend behavior. Update the handoff with evidence and stop before the next milestone.

### Technical references

- [Godot video playback](https://docs.godotengine.org/en/stable/tutorials/animation/playing_videos.html): core Theora playback and CPU decoding constraints.
- [Browser presented-frame callbacks](https://developer.mozilla.org/en-US/docs/Web/API/HTMLVideoElement/requestVideoFrameCallback): media timestamps for synchronization.
- [Godot spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html): unshaded materials and shader uniforms.
