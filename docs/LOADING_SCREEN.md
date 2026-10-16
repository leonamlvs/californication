# Loading screen: accepted current contract

**Status: complete and accepted on 2026-10-16.** This document defines the current boot loading screen and guides subsequent maintenance. It is authoritative for loading-specific definitions referenced by the architecture, UI, asset, Task 23, and implementation documents. It does not redefine Island Intro, Island Attract, other screens, or gameplay.

The accepted result is the implemented presentation, inspired by the music-video reference. Pixel-for-pixel video reproduction is not an outstanding completion requirement. Earlier plans and revision measurements are classified in the [documentation audit](LOADING_SCREEN_DOC_AUDIT.md); dated revision reports are historical evidence, not instructions to restore previous renderers.

## Ownership and timing

[`GameFlow`](../autoload/GameFlow.gd) owns the legal `BOOT -> LOADING -> ISLAND_INTRO` state changes. [`IslandFrontendController`](../frontend/island/IslandFrontendController.gd) owns the loading clock, resets it on loading entry, advances the presentation, and requests the single handoff. The production overlay is `FrontendUI/LoadingOverlay` in [`IslandFrontend.tscn`](../frontend/island/IslandFrontend.tscn).

[`LoadingPresentation`](../frontend/loading/LoadingPresentation.gd) renders a normalized seek position; it does not own elapsed time or authorize transitions. The controller's `loading_duration` defaults to **2.0 active seconds**. Application/window focus loss pauses that clock. Wall-clock startup can therefore exceed two seconds. Normal player input cannot skip this presentation; development stepping and the legacy placeholder API are separate test paths.

The bar is a deterministic presentation, **not a measurement of resource loading, browser downloads, or engine initialization**. It makes no promise about network startup time.

| Active time at the default duration | Presentation |
| --- | --- |
| Entry / normalized 0 | Complete layout is visible immediately; fill is empty, image contents are unrevealed, and no image is highlighted |
| 0–1.9 s / normalized 0–0.95 | Source frames 11–70 drive measured fill coordinates, linearly interpolated between samples, with plateaus at source frames 29–39, 43–52, and 62–68 |
| 1.9–1.95 s / normalized 0.95–0.975 | Remaining fill completes to 100% |
| 1.95–2.0 s / normalized 0.975–1 | Full bar holds before handoff |
| 2.0 s | Controller requests `ISLAND_INTRO`; the loading overlay is hidden |

Image slots reveal in order at source frames **15, 19, 24, 29, 43, 55, 59, 62**. Only the latest revealed slot is highlighted. Fill samples remain in `FILL_FRAMES`/`FILL_RIGHTS`; source frame numbers are presentation coordinates, not the application's frame rate.

## Composition and appearance

All geometry below uses the **960x720 logical canvas**. Fit the whole canvas uniformly and center it inside the loading control's available rectangle, using the smaller width/height scale. Unused wide/tall space is black. Loading does not reflow or select gameplay HUD density profiles, and must not apply safe insets a second time.

| Element | Current logical geometry |
| --- | --- |
| Text cap fitting bounds | `(80, 195, 374, 40)`; this is not the total ink/glow bounding box |
| Outer / inner bar | `(58, 249, 838, 43)` / `(61, 252, 833, 37)` |
| Map fit target | `(143, 82, 718, 546)`; replacement artwork fits uniformly inside it |
| Eight image frames | 82x82; left coordinates `55, 165, 274, 382, 491, 600, 709, 817`; top coordinates alternate `409, 373` |
| Image borders / corners | Border parameter 2.5, rounded to 3 pixels by the style helper; corner radius 7 |
| Connector tree | 2-pixel lines; stem `(472, 292)` to `(472, 340)`, horizontal branch `(97, 340)` to `(858, 340)`, then vertical lines to each frame center |

Revealed images center-crop without stretching and fill the rounded frame interiors, approximately 76x76. Textured polygons extend half a logical pixel beneath the existing border, which draws on top. Missing or unrevealed textures retain their empty frame; they do not alter geometry or reveal timing.

### Layered text

The text is `NOW LOADING`, currently a code constant in [`LoadingForeground`](../frontend/loading/LoadingForeground.gd). Draw order is **glow, Solid fill, Outline lettering**. Both fonts use size 96 before fitting, the same baseline/advances/transform, and the Outline-derived ink width and leading N cap height. The corrected I dot extends above the cap line. Do not independently resize or offset the two font layers.

| Layer | Configured RGBA |
| --- | --- |
| Outline lettering | **`(0.90, 0.92, 1.0, 0.94)`**, pale lavender at 94% opacity; fixed in the foreground script |
| Solid fill | **`(1, 1, 1, 0.5)`**, white at 50% opacity; Inspector property |
| Text glow tint | `(0.72, 0.77, 1.0)` with per-pass opacity |

These are drawing colors, not final pixel values after antialiasing, glow, and background compositing. Pure white at 100% outline opacity is not implemented and is not a pending completion requirement.

A missing fill font leaves outlined text. A missing outline font uses `ThemeDB.fallback_font` and suppresses the unmatched Solid layer. Replacement font pairs must retain compatible glyph advances, bearings, and alignment; the supplied pair is covered by rendered checks.

### Foreground glows and sharp UI

Current text/bar/frame/connector glow radii are **8/12/8/6 logical pixels**, with shared strength **1**. Sixteen nested drawing passes approximate Gaussian falloff with sigma = radius/3. Source-over opacity increments normalize near-edge strength across radii, subject to rasterization. Text stroke units are calibrated from glyph metrics and compensated for its fitted transform. A zero radius disables that category; zero shared strength disables all foreground glows.

The bar glows around its fixed perimeter at every fill level. Its moving fill edge has no added glow. Image-frame highlight tint remains green/yellow. Sharp border geometry, image contents, and connector positions are independent of glow extent.

| Sharp UI component | Configured RGBA |
| --- | --- |
| Bar border / empty underlay | `(0.93, 0.95, 1, 0.96)` / `(0.09, 0.12, 0.38, 0.74)` |
| Bar fill | `(0.87, 0.88, 0.97, 0.90)`, with the existing subtle top/bottom variation |
| Normal / highlighted frame border | `(0.92, 0.95, 1, 0.94)` / `(0.88, 0.94, 0.72, 0.98)` |
| Empty frame underlay | `(0.10, 0.14, 0.40, 0.48)` |
| Connectors | `(0.965, 0.99, 1, 1)` |

### Map and effective background colors

[`LoadingSvgBackground`](../frontend/loading/LoadingSvgBackground.gd) renders the supplied SVG in an isolated transparent 960x720 2D source. Two nested, isolated 960x720 2D Gaussian passes pack shadow and halo masks in R/G. The composite draws the subtle downward/right shadow, continuous outer halo, then sharp artwork, correcting premultiplied edges. The illustrated depth/highlights belong to the SVG; there is no loading-specific 3D model, camera, mesh shader, or procedural fallback. Island presentation remains 3D.

Loading entry/reset, showing the overlay, or `refresh_background()` schedules source and blur targets once. They complete in dependency order on the first visible frame and settle to disabled updates. Seeking/resizing reuses their textures; hiding disables target updates. Refreshing appearance does not change progress.

The visible radial gradient is defined by [`loading_radial_background.gdshader`](../frontend/loading/loading_radial_background.gdshader): `center_color = (0.278431, 0.278431, 0.615686, 1)` and `border_color = (0.184314, 0.203922, 0.513725, 1)`. The exported `background_color = Color("313189")` is assigned to the backdrop ColorRect, but the active shader writes its own fragment color. That property is not the effective radial-gradient color control; edit the shader/material uniforms for a requested gradient change.

## Assets, controls, and interfaces

Open [`LoadingPresentation.tscn`](../frontend/loading/LoadingPresentation.tscn), select its root, and use these existing Inspector properties. The production instance has no separate visual overrides. This documentation introduces no API or scene changes.

| Group / properties | Defaults and meaning |
| --- | --- |
| Replaceable Assets: `loading_font`, `loading_fill_font` | [`Californication-Outline.otf`](../art/loading/fonts/Californication-Outline.otf), [`Californication-Solid.otf`](../art/loading/fonts/Californication-Solid.otf) |
| Replaceable Assets: `image_1` through `image_8` | `art/loading/frames/loading_01.png` through `loading_08.png`, in numeric order |
| Loading Text: `loading_fill_color` | `(1, 1, 1, 0.5)` |
| Foreground Glow: `text_glow_radius`, `bar_glow_radius`, `frame_glow_radius`, `connector_glow_radius` | `8`, `12`, `8`, `6`; Inspector range 0–24, step 0.5 |
| Foreground Glow: `foreground_glow_strength` | `1`; Inspector range 0–2, step 0.05 |
| Background Map: `background_texture` | [`california-map.svg`](../art/loading/california-map.svg); missing/invalid replacements use the bundled SVG |
| Background Map: `background_map_scale`, `background_map_offset` | `1`, `(0, 0)`; scale multiplies uniform fitting, offset uses logical pixels |
| Background Map: `background_color` | `Color("313189")`; backdrop base property, with shader behavior described above |
| Background Map: `background_map_tint`, `background_map_opacity` | `(1.12, 1.06, 1.02, 1)`, `1`; artwork-only tuning |
| Outer Halo: `background_halo_color`, `background_halo_strength`, `background_halo_radius`, `background_halo_direction_bias` | `(0.68, 0.67, 0.88, 1)`, `0.45`, `32`, `(0.30, -0.45)` |
| Drop Shadow: `background_shadow_color`, `background_shadow_opacity`, `background_shadow_offset`, `background_shadow_softness` | `(0.08, 0.07, 0.22, 1)`, `0.10`, `(2, 3)`, `2` Gaussian sigma |

The supplied SVG is imported at 2x resolution with mipmaps (1225x936). The eight supplied PNGs are 75x75, imported Lossless without mipmaps. Both OTF files use dynamic grayscale font rendering, with MSDF disabled. Preserve filenames, case, import UIDs, and decoded image pixels during maintenance unless an asset replacement is explicitly requested. Lossless re-encoding is retained only when smaller; historical source-size savings are not a guarantee of smaller imported/Web payloads.

The runtime assets are bundled under `art/loading/`. `.ref/` is development reference/provenance only. The Web preset excludes `.ref/`, `build/`, `dev/`, and `tests/`; no captured reference frame is a runtime asset. Source OTFs, SVG, and PNGs remain replaceable user-provided artwork, not placeholders awaiting replacement.

| Existing `LoadingPresentation` method | Contract |
| --- | --- |
| `reset()` | Seek to zero and request the cached map render; the controller separately resets elapsed time |
| `set_progress(value: float)` | Clamp to 0–1, calculate fill/reveals/highlight, and queue foreground drawing; no state change |
| `refresh_background()` | Once ready, apply map/effect properties and request recaching; preserve progress |
| `get_visual_snapshot() -> Dictionary` | Report progress, composition/bar/text/image rectangles, and prefixed map-cache diagnostics; text bounds are cap fitting bounds |

For live foreground property/font-slot changes, queue `foreground.queue_redraw()`; normal loading progress already does so. Map changes use `refresh_background()`. To reimport/tune font resources or apply Inspector edits predictably, save and restart the preview; measurements are cached per outline-font reference. No runtime text/localization property is implemented.

Map pixels are cached in viewports. Foreground glyph measurements, glow weights, and reusable styles are cached as data, but **the finished text/glow is not cached into a texture**: the shared foreground redraws during bar animation, including 16 text-glow commands and two font-layer commands. These command counts are not measured GPU draw-call counts. No low-end mobile-browser performance benchmark has been established.

## Preview, validation, and evidence

Run from the project root with Godot 4.7.2 available as `godot`. On a clean checkout, first run `godot --headless --editor --path . --import --quit` to populate imported resources/class caches. The regular checks below use bundled assets and do not require `.ref/` or archived build artifacts. Rendered checks require a working Compatibility graphics context; headless execution alone cannot establish visual correctness.

```text
godot --headless --path . tests/cli/Task23Test.tscn
godot --path . --rendering-method gl_compatibility --script res://tests/cli/LoadingUiGlowTest.gd
godot --path . --rendering-method gl_compatibility --script res://tests/cli/LoadingImagesTest.gd
godot --path . --rendering-method gl_compatibility dev/LoadingPreview.tscn
```

Preview Left/Right selects source checkpoints 11/20/40/60/70/71 (71 represents the full-bar hold). **B** toggles foreground, **D** cycles composite/artwork/halo/shadow diagnostics and hides foreground, and **S** saves to `.godot/`. `--loading-frame=70` selects a starting checkpoint.

For a fresh responsive suite, use a new output directory rather than overwriting acceptance evidence:

```text
godot --path . --rendering-method gl_compatibility dev/LoadingPreview.tscn -- --capture-loading-suite --capture-loading-effects --loading-output=build/loading-review
godot --path . --rendering-method gl_compatibility --script res://dev/LoadingBootCapture.gd -- --loading-output=build/loading-review/boot
```

The preview covers 960x720, 1280x720, 844x390, 360x640, first-frame/cache checks, safe-inset fitting, and replacement artwork. The boot capture observes the production clock without seeking; keep its native window focused. Focus-related wall-clock timeout is not evidence that the active two-second duration changed.

[`LOADING_SCREEN_DOC_AUDIT.md`](LOADING_SCREEN_DOC_AUDIT.md#validation-and-evidence) separates checks rerun for this documentation audit from reused native/Web evidence. `build/` and `.ref/` are ignored local evidence; their absence on another checkout is not an application-resource failure.

[`LoadingEffectsCompare.gd`](../dev/LoadingEffectsCompare.gd) requires the SVG revision's `build/rehabilitation/loading-svg/mesh-baseline/`, matching `after/` captures, and reference frames 0010/0011/0040/0070. [`LoadingImagesCompare.gd`](../dev/LoadingImagesCompare.gd) requires the image revision's matching `before/`, `after/`, and `before-assets/` under `build/rehabilitation/loading-images/`. Their revision-specific preservation masks are not general checks against the later font/glow presentation. Older RGB thresholds and “exact match incomplete” notes belong to those historical comparisons, not a reopened loading-screen acceptance gate.

## Future-change rules

The stable contract is accepted appearance/composition, paired-font alignment, reveal/fill behavior, focus handling, handoff ownership, responsive fitting, replaceable asset interfaces, and runtime/reference separation. Current pass counts, caching techniques, and shader organization describe the implementation; they do not prohibit a separately requested optimization that preserves those contracts.

For a requested loading change, identify the affected properties, take a fresh baseline, preserve pixels/behavior outside its authorized regions, run the relevant focused checks and desktop/phone views, and update this document plus applicable acceptance notes. Validate Web packaging/browser behavior when runtime rendering/assets change. Do not silently retune unrelated UI or the map. Other frontend work must preserve the loading screen without requiring a new visual recreation.

Pure-white/100%-opacity outlining and caching the finished text/glow into a texture are **proposed but unimplemented**, not outstanding work. A future optimization should be motivated by browser profiling and preserve the accepted result. No performance percentage or universal device guarantee follows from the existing smoke test. Historical implementation reports retain their original results; new evidence must identify the revision and prerequisites it actually checks.
