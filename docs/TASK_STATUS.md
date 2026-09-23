# Task Status

Update only after acceptance criteria are verified.

- [x] 00 — Project Foundation
- [x] 01 — Input Abstraction
- [x] 02 — Responsive UI Foundation
- [x] 03 — Expanded GameFlow State Foundation
- [x] 04 — RUN Movement
- [x] 05 — Seven Obstacle Primitives
- [x] 06 — Segment and Pattern Generator
- [x] 07 — Collectibles and Score
- [x] 08 — Scenario Transition Framework + DevHarness Base
- [x] 09 — Boulevard
- [x] 10 — Sierra Nevada
- [x] 11 — San Francisco Bay
- [x] 12 — Sequoia
- [x] 13 — Filming Sets
- [x] 14 — Golden Gate
- [x] 15 — Hollywood
- [x] 16 — Grass
- [x] 17 — Earthquake
- [x] 18 — Scenario Runtime Hardening
- [x] 19 — Character Data and Presentation
- [x] 20 — Pause and Settings
- [x] 21 — Failure and Game Over
- [x] 22 — CinematicTransitionFX
- [x] 23 — Loading, Island Intro, and Island Attract
- [x] 24 — Logo/Alicorn Reveal and Player Select Entry
- [x] 25 — 3D Logo Carousel and Decorative Player Select
- [ ] 26 — Character Confirmation and Run Intro
- [ ] 27 — Final HUD Behavior
- [ ] 28 — itch.io Web Hardening

## Audit notes — 2026-09-22

- Tasks 00–18 remain at their previously recorded status. The project imports and launches under Godot 4.7.2, and the standalone Task 06–18 scene tests pass.
- Removed redundant layout writes that previously resized a stretched `SubViewport` and an opposite-anchored control; the container/anchors now own those sizes without launch warnings.
- The shared CLI runner for Tasks 00–05 now runs as `tests/cli/TestRunner.tscn`, ensuring project autoload globals are initialized during deterministic acceptance checks.
- Task 19 was completed after this audit with four validated definitions, distinct matched primitive presentation scenes, pause portraits, pause-safe cosmetic replacement, and `Task19Test` acceptance coverage.
- Task 20 was completed after this audit with runtime intent routing, exact-state resume, live Music/SFX mixer buses, face-only Task 19 portraits, direct touch adjustment, separate resume/exit actions, responsive rendered checks, and expanded `Task20Test` acceptance coverage.
- Task 21 was completed after this audit with rendered floor-fall and launch-toward-screen presentations, shared navigable lava Game Over, protected retry/island cleanup, transition-token cancellation, a production-backed DevHarness death path, and expanded `Task21Test` coverage.
- Task 22 was completed after this audit with a profiled reusable fullscreen radial/zoom blur, selectable desktop/mobile/high sample quality, synchronized FOV/overlay fallback, defensive neutralization on completion and interruption, direct DevHarness previews, Compatibility-rendered checks, Web export validation, and `Task22Test` coverage.
- The audit preceding Task 23 repaired the shared Task 00–05 runner as an autoload-aware test scene, corrected stale mutable-capture/sweeper test setup, and removed the two redundant responsive-layout writes; all completed task suites pass again.
- Task 23 was completed with automatic loading handoff, a deterministic four-stage vegetation/city/landscape/island pullback, replaceable California-island placeholder, authored camera/FOV and shared blur cues, responsive narrow-screen camera compensation, indefinite rotating attract, one-shot touch/confirm handling, blue ocean/sky handoff, DevHarness intro/attract/replay/stage controls, and `Task23Test` coverage.
- Task 24 was completed with a color-matched blue-frame scene-group handoff, genuinely extruded red logo and individual 3D `CALIFORNICATION` letters, primitive alicorn approach/camera-pass/departure, one persistent four-anchor logo assembly parked at its first carousel detent, responsive composition adjustment, direct DevHarness entry/stage/complete controls, and `Task24Test` coverage.
- Task 25 was completed with four exact detents on the persistent logo, keyboard/gamepad/touch-safe arrow navigation, one bounded queued step, anchor-bound full-body presentations, settlement-only identity updates, six animated decorative values, one-shot confirmation, responsive wide/narrow layouts, direct DevHarness selection/detent/stat controls, and `Task25Test` coverage.
