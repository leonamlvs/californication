# Asset Contract

## MVP art philosophy

Use primitive 3D meshes and simple materials.

The MVP proves:
- movement;
- gameplay;
- transitions;
- responsive presentation;
- browser behavior.

It does not prove final art style.

## itch.io package budget

The HTML5 build is distributed as an itch.io ZIP. The extracted archive must remain within itch.io's current limits: at most 1,000 files, 500 MB total, 200 MB for any single file, and 240 characters for any full path. These are upload ceilings, not target budgets.

Prefer shared materials, consolidated reusable resources, short paths and names, and a small startup payload. Avoid creating hundreds of one-off placeholder files when a parameterized scene/resource can serve the same purpose. Preserve exact filename case so Windows development does not hide failures that will occur on itch.io's case-sensitive hosting.

## Replaceability

Gameplay systems must not reference assets by visual meaning.

Example:

Bad:
```text
if collided_object.name == "Bench":
```

Good:
```text
obstacle.obstacle_class == BLOCK
```

A bench, boulder, parked car, studio camera or underwater rock may all later reuse `BLOCK`.

## Frontend placeholder set

The graybox frontend eventually requires replaceable primitives for:

- close palm/vegetation and larger vegetation groups;
- roads, cars, city blocks, and distant city/landscape groups;
- a California-shaped cinematic island;
- one genuinely extruded red asterisk/logo with four indexed character-panel faces;
- individual 3D letters arranged as circular `CALIFORNICATION` text;
- an alicorn/winged-horse presentation model;
- four humanoid character presentation scenes with idle animation;
- a Boulevard/start-environment reveal group.

Reference captures in `.ref/start screen transition/` define the order, camera relationships, logo-to-carousel continuity, and broad composition. Do not copy the captured assets or bake the reference imagery into the game.

The island sequence must fake extreme scale rather than model literal geography. Separate near-vegetation, city, landscape, and island groups may use different working scales and swap under motion blur/blue-frame coverage. Their authored anchors, bounds, and camera markers are stable replacement contracts.

Useful placeholder proportions:

```text
humanoid character: 1.7–1.8 m
car: 4–5 m long
palm tree: 8–12 m
building/city props: plausible relative proportions
California island: cinematic scale only
```

The logo mesh must keep a stable center pivot, four equal selection detents, sufficient extrusion for edge-on readability, and named panel attachment surfaces. Final logo, panel, letter, alicorn, character, and environment art must fit these contracts without rewriting carousel logic or camera choreography.

### Loading-screen replacement contract

`frontend/loading/LoadingPresentation.tscn` exposes one optional font and eight independent `Texture2D` slots under **Replaceable Assets**. Replacement images may have any aspect ratio; the presentation center-crops them into the existing square frames. Replacing the font or images must not change the measured layout, deterministic fill/reveal timeline, controller, or two-second state duration. Reference captures remain development evidence only and are never runtime resources.

The current eight frame images are copied into `art/loading/frames/loading_01.png` through `loading_08.png` from the user-provided `.ref/loading/0.png` through `7.png`. The presentation assigns them in numeric order to `image_1` through `image_8`; `.ref` remains excluded from runtime exports.

The same scene exposes **Background Map** properties. **Background Texture** defaults to `art/loading/california-map.svg`, an unchanged copy of the user-provided SVG from `.ref/loading/`. The runtime SVG is imported at 2x resolution with mipmaps; its transparency, painted face, fine highlights, and illustrated depth are preserved. A missing replacement texture falls back to this bundled SVG, never to a 3D model. The dedicated loading GLB, procedural mesh fallback, and mesh shader have been removed.

**Background Map Scale** and **Background Map Offset** uniformly fit any replacement `Texture2D` into the logical subject rectangle `(143, 82, 718, 546)`; offsets use logical pixels. **Background Map Tint** and **Background Map Opacity** affect only the artwork. The default tint is `(1.12, 1.06, 1.02, 1)`, with opacity `1.0`; do not reuse the old translucent mesh opacity. The existing radial-background shader and its center/border colors are unchanged.

**Outer Halo** controls expose color `(0.68, 0.67, 0.88, 1)`, strength `0.45`, radius `32` logical pixels, and direction bias `(0.30, -0.45)`. Direction bias varies intensity along the smooth silhouette normal without changing Gaussian kernel shape; zero removes this modulation. **Drop Shadow** controls expose color `(0.08, 0.07, 0.22, 1)`, opacity `0.10`, offset `(2, 3)` logical pixels, and softness `2` (Gaussian sigma). The faint shadow sits behind the halo and sharp artwork. Both effects derive only from silhouette alpha; the SVG supplies internal highlights without another contour pass.

`LoadingSvgBackground` uses an isolated transparent 960x720 2D source and two nested, isolated 960x720 Gaussian passes. `loading_map_blur.gdshader` packs shadow and halo into independent R/G channels with CPU-normalized consecutive-texel kernels. `loading_map_composite.gdshader` composites shadow, halo, and artwork, correcting premultiplied viewport edge colors. Loading entry or appearance refresh schedules all targets once; seeking and resizing reuse the cache, and hidden targets stay disabled. `get_visual_snapshot()` exposes texture identity/size, fitted bounds, fallback state, 2D isolation, target sizes/update modes, and render generation. Scripts changing appearance on a live instance call `refresh_background()`; this does not change progress.

For manual tuning, open `frontend/loading/LoadingPresentation.tscn`, select its root, and expand **Background Map**. The production instance remains `FrontendUI/LoadingOverlay` inside `frontend/island/IslandFrontend.tscn`. Save and restart `dev/LoadingPreview.tscn` (F6) to apply Inspector edits. Left/Right seek checkpoints, **B** toggles foreground, **D** cycles composite/artwork/halo/shadow diagnostics, and **S** captures.

Development comparisons: run the preview with `--capture-loading-suite --capture-loading-effects --loading-output=build/rehabilitation/loading-svg/after`; the pre-change mesh captures are under `build/rehabilitation/loading-svg/mesh-baseline/`. Run `godot --headless --path . --script res://dev/LoadingEffectsCompare.gd` for normalized references, patch measurements, profile CSV/SVG, preservation checks, and `comparison.html`. Run `godot --path . --rendering-method gl_compatibility --script res://dev/LoadingBootCapture.gd` to observe production boot without seeking its clock. Reference captures, diagnostics, and comparison tools remain excluded from exports. Numerical measurements do not establish an exact visual match by themselves.

## Placeholder obstacle assets

Create one graybox asset per class:

```text
BLOCK      tall prism
HURDLE    low barrier
OVERHEAD  overhead U-frame
CROSSER   moving capsule
SWEEPER   pivoting beam
GAP       missing track region
GATE      blockers leaving safe opening
```

Use simple materials/colors for debugging only.

Never make mechanic recognition depend only on color.

## Placeholder characters

Create simple humanoid placeholders for four selectable characters.

All use:
- same root scale;
- same collision;
- same movement controller;
- same animation interface.

Character differences are cosmetic.

Each character resource also supplies a frontend presentation scene, display name, instrument/category label, category value, STRENGTH, STAMINA, AGILITY, CHARISMA, RHYTHM values, and idle-animation key. These values drive only the Player Select display and animation. They must not appear in runner/gameplay profiles.

Each character definition also provides a face portrait for the pause HUD. Portrait assets share one minimum readable size and may not embed names, statistics, or card-style information; selection focus is drawn by the UI as a rounded green/yellow outline.

## Placeholder Transition Token

Final appearance intentionally undefined.

MVP token needs only:
- obvious difference from normal collectible;
- clear silhouette at speed;
- simple glow/animation;
- collision trigger.

Do not spend time polishing it.

## Placeholder transition cinematics

Each scenario provides a primitive real-time 3D scripted cinematic scene matching its documented concept. Cinematic presentation may animate the shared character visual, props, environment, and camera, but it must not require gameplay lanes, obstacle collision, collectible placement, failure presentation, or input prompts. The centered `BONUS` label is shared UI, not baked into scenario art.

## Cinematic effect assets

Radial/zoom blur is a reusable Compatibility-rendered screen/camera effect, not blur baked into textures or video. Profiles may tune strength, center, samples, FOV kick, fade, and duration. Provide a low-sample mobile profile and a no-screen-sampling camera/FOV/overlay fallback. No effect material may remain enabled during normal gameplay.

## Final 3D asset contract

Use this convention unless deliberately revised later:

```text
Up: +Y
Forward: -Z
Scale: 1 Godot unit = 1 meter
Character origin: ground point between feet
Vehicle origin: centered near ground contact
Environment origin: modular snap/reference point
Logo origin: central carousel pivot
Logo panel anchors: four equal indexed detents around the extrusion
Preferred interchange format: GLB/glTF
Animation target: 30 fps unless a different rate is required
```

Character assets should share one humanoid skeleton where practical.

Keep:
- low material count;
- reusable textures;
- simple shaders;
- low-poly silhouette-first modeling.

## Naming examples

```text
chr_character_01.glb
chr_character_02.glb

obs_block_placeholder.tscn
obs_hurdle_placeholder.tscn

env_boulevard_segment_a.tscn
env_bay_segment_a.tscn

pup_transition_placeholder.tscn
col_collectible_placeholder.tscn
```

## Final-art direction later

Target:
- fully 3D;
- Dreamcast / PS2-era visual language;
- simple geometry;
- low-to-medium resolution textures;
- restrained lighting;
- deliberate fog;
- no forced PS1 pixelation;
- no modern glossy mobile-game UI.

The art system must allow all RHCP-specific imagery, likenesses, branding and video-inspired assets to be replaced without changing mechanics.
