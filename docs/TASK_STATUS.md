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
- [ ] 19 — Character Data and Presentation
- [ ] 20 — Pause and Settings
- [ ] 21 — Failure and Game Over
- [ ] 22 — CinematicTransitionFX
- [ ] 23 — Loading, Island Intro, and Island Attract
- [ ] 24 — Logo/Alicorn Reveal and Player Select Entry
- [ ] 25 — 3D Logo Carousel and Decorative Player Select
- [ ] 26 — Character Confirmation and Run Intro
- [ ] 27 — Final HUD Behavior
- [ ] 28 — itch.io Web Hardening

## Audit notes — 2026-09-22

- Tasks 00–18 remain at their previously recorded status. The project imports and launches under Godot 4.7.2, and the standalone Task 06–18 scene tests pass.
- Main-scene smoke launch exits successfully but reports redundant layout writes: `PresentationRoot` assigns a stretched `SubViewport` size and directly sizes an opposite-anchored control. These are warnings rather than launch blockers, but should be removed during the next relevant UI pass.
- The documented shared CLI runner for Tasks 00–05 currently fails to compile when invoked with `--script`; repair that validation path before relying on it for a fresh acceptance audit.
- Task 19 has character resources and runtime cosmetic swapping, but the four definitions do not assign the required pause-face portraits and there is no Task 19 acceptance test or equivalent recorded evidence.
- Task 20 has a pause overlay and an isolated controller test, but runtime `InputRouter` intents are not connected to `PauseController`; resuming a pause entered from `TRANSITION_READY` also returns to `RUNNING` and loses readiness. Responsive rendered checks and working audio-bus application are still unverified.
- Task 21 has failure coordination, retry reset logic, a Game Over overlay, and a passing isolated test. It remains incomplete because `failure_started` has no presentation consumer, so the required floor-fall and launch-toward-screen families are not rendered, and manual integration/layout evidence is still missing.
