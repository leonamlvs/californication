# Playable experience rehabilitation: implementation handoff

Updated September 23, 2026 after resuming implementation. This is a status record, not a completion certificate.

**Current acceptance: automated source and exported-browser checks pass; hands-on experience and device acceptance remain incomplete.** The safe-runway regression described below was fixed. The current Web ZIP was rebuilt from this uncommitted worktree.

The workspace contains extensive uncommitted rehabilitation changes and new files. Preserve them and the user's separate `AGENTS.md` changes. `TASK_STATUS.md` remains historical.

## 1. Original objective and scope

Turn the historically completed engineering prototype into a good, coherent arcade graybox. The criterion is the complete playable experience, not isolated acceptance checkmarks. Primitive characters and geometry are acceptable; disconnected flow, accidental cameras, unreadable hazards, weak controls, and development artifacts are not.

Approved priority order:

1. Repair production integration and remove debug leakage.
2. Make runner controls and camera consistently satisfying.
3. Populate all nine scenarios with fair, readable, distinct gameplay.
4. Connect frontend, transitions, failure, UI, sound, and ambience.
5. Validate the real playable flow, including browser and manual experience checks.

Retain shared/data-driven architecture, discrete three-lane movement, all five movement modes, InputRouter, one responsive HUD, and all nine scenarios: Boulevard, Sierra Nevada, San Francisco Bay, Sequoia, Filming Sets, Golden Gate, Hollywood, Grass, and Earthquake. No physics-heavy free steering or scenario-name branches in RunnerController.

Key approved targets:

- Eased one-lane movement, one queued request, safe opposing reversal, and a 0.12-second vertical-action buffer.
- Run-global base-to-maximum speed progression over 150 seconds, retaining normalized difficulty across scenario changes.
- A collision-independent visual pivot and shared CameraProfile-driven rig: approximately 10/s position and 12/s rotation damping, 20% ground/55% depth-mode vertical follow, bounded 2.5-degree roll and +5-degree speed FOV, lane anticipation, and narrow-viewport adaptation.
- Protected 24-30 m opening with guides/pickups; first hazard around 2.5-4 seconds. Difficulty tiers at 30/90 seconds, no immediate ordinary repeats, ordinary safe selection at most 20%, recovery after hardest sequences, maximum-speed validation, and a 1.25-second absolute reaction floor.
- Selected-character cinematics, hidden frozen runner, motivated camera paths, covered environment handoffs, and safe settlement before unlocking. Preserve 2.4-3.2-second cinematics, input lock/invulnerability, and one-shot +1000/centered BONUS.
- Preserve the deliberately paced frontend: vegetation pullback, expanding landscape, glowing island attract, blue-frame logo/alicorn reveal, the same logo rotating into selection, and selected-character push into Boulevard. Intro plays once per session; return goes directly to attract.
- Original synthesized SFX and crossfaded ambience on existing SFX/Music buses. No captured imagery, likeness assets, referenced song, or copied audio in production/export.
- Full production-flow, movement-rate, pattern, soak, camera, CLI, Compatibility, Web/package, and manual three-viewport acceptance.

The user explicitly authorized revising obsolete behavior/tests. This rehabilitation supersedes conflicting historical implementation details; it is not the next numbered historical task.

## 2. Root causes discovered

### Production composition

- Main mounted `GameFlowPlaceholder` and depended on development flow controls. PresentationRoot contained `PlaceholderBlock`.
- TrackGenerator auto-started behind the frontend, leaking gameplay content.
- Main did not install FailureCoordinator; a normal collision could stall instead of autonomously reaching Game Over.
- Run Intro loaded Boulevard without beginning a production run, leaving the first-run eight-scenario shuffle uninitialized.
- All nine production transitions used explicit fixture destinations, including compactly formatted resources initially missed by text replacement.
- TransitionToken had a stepping function but no production runtime caller, disconnecting natural collection/miss handling.
- TrackPool reused arbitrary segment scenes, allowing old scenario geometry to survive a handoff.
- Fresh-run preparation was duplicated between FailureCoordinator and Run Intro; service rebinding and pause propagation were incomplete.

### Experience and readability

- Simple lane interpolation and constant speed provided little rhythm/feedback. Character presentation did not explain actions.
- CameraProfile resources existed but were not consumed by gameplay.
- Hollywood and Grass had safe-only libraries; Earthquake reused generic city content. Difficulty was not meaningfully driving selection.
- Opaque water/flight volumes, ground in the aerial scenario, overlapping floors, and sparse moving edge detail obscured movement and speed.
- Obstacles lacked consistent silhouettes. Dynamic hazards snapped lanes and used nearest-lane collision; depth barriers/actions were hard to read.
- Cinematics used generic proxies beside a visible frozen runner, lacked intentional camera framing, and had enclosing tunnel/cave solids and missing traversal presentation.
- Debug-facing HUD text, fixed widths, and project viewport stretching undermined production/mobile layout. Run Intro focus loss could unlock gameplay prematurely.
- Audio had bus plumbing but no meaningful runtime cues or ambience.

### Validation blind spots

- Historical tests mostly checked resources/fixtures rather than the complete production composition. A test could print PASS and exit zero while Godot logged script errors.
- Real exported keyboard input revealed a listener-order bug: one pause event could resume and immediately re-pause. Menu confirmation could also act again in the destination state.
- Browser screenshots revealed missing-font Game Over glyphs. A clean console alone did not prove the intended screens had been reached.

## 3. Architectural and design decisions implemented

### Ownership and lifecycle

- Main starts GameFlow and binds production services. Frontend ownership hides/suspends runner, generator, scenario environment, and gameplay lighting. Production generator auto-start is disabled.
- Run Intro solely owns fresh-run preparation: initialize shuffle, load Boulevard, reset run state, prepare the safe opening, settle camera, unlock. FailureCoordinator only cleans failure presentation.
- Scenario loads rebind failure, camera, HUD, and ambience. Production seeds are random; integration tests explicitly request deterministic behavior.
- Production transitions use SHUFFLE. Fixture tests duplicate source resources and explicitly select local EXPLICIT destinations; fixtures must not leak back into production.
- Generator owns token stepping and stops safely if stepping changes flow. Segment pools match requested scene identity.
- InputRouter remains the only device-input route. A dispatch guard prevents the same routed event being interpreted again after changing GameFlow state.

### Movement and camera

- Runner stays discrete/profile-driven. Eased lanes consume leftover frame time, support one queued request and reversal, and keep vertical buffering independent of lane input.
- Global run time drives the 150-second ramp. Profile adoption preserves elapsed time/distance while resetting lane/posture and applying intentional mode speed differences.
- Existing collision-independent CosmeticMount carries bob, lean, banking, stretch, and compression. Primitive board/car details and vertical trails convey mode without model-identity coupling.
- Runner signals expose lane/action start, action completion, pickup response, and failure impact to presentation/audio.
- GameplayCameraRig consumes extended CameraProfile data for damping, anticipation, vertical follow, FOV, aspect pullback, bounded roll/impulses, and camera ownership.
- Run Intro focus loss pauses progression instead of force-completing it; pause also stops cosmetic animation.

### Generation, content, and feedback

- Opening protection counts the next pattern's existing reaction lead-in instead of adding another full empty segment. The short opening also extends behind the player. Earlier evidence placed Boulevard's first hazard roughly 27-31 m ahead. Temporary opening patterns now use an isolated array and pass repeated handoff checks (section 5).
- Pattern selection uses difficulty tiers, repeat avoidance, ordinary-safe rate tracking, and recovery after difficulty 3. Generation history is capped at 256; pools and visual caches are bounded.
- Dressing and obstacle silhouettes are shared/data-driven. Snow/car lane spacing is authored. Moving hazards use continuous lateral movement/overlap; depth avoidance checks actual height, not just an action flag.
- Pickups bob/rotate, trigger bounded bursts, and avoid nearby occupied hazard lanes without changing scoring.
- ScenarioDefinition supplies control hints and ambience identity. AudioManager alone consumes AudioCue/AmbienceProfile resources, with cached synthesis, eight SFX voices, and two crossfaded ambience voices.

### Presentation continuity

- Cinematics clone the selected primitive presentation and hide the gameplay body. Per-transition camera start/end offsets track staged subjects, blend from gameplay, cover handoff, and settle before release.
- Shared FX covers the end of the cinematic and adds approximately 0.22 seconds of target reveal/settlement. Cancellation cleanup respects current flow ownership so it cannot restore gameplay behind the island.
- Existing intro/reveal durations (8 and 7.5 seconds) and persistent logo identity are retained. White lettering and camera-relative alicorn travel improve visibility.
- Project-level window stretching is disabled so PresentationRoot can own desktop 4:3 framing and real mobile dimensions. There is still one responsive HUD.

## 4. Complete, partial, and not started

“Implemented” means source work exists with the stated evidence, not final experience acceptance. No overall release sign-off is claimed.

| Workstream | Status | Evidence / remaining boundary |
| --- | --- | --- |
| Production wiring, failure, retry, first shuffle | Implemented; current automated verification | Production-flow integration and exported-browser retry/island-return captures pass. |
| Runner controls/speed/presentation | Implemented baseline; feel acceptance partial | Earlier 30/60/120 Hz tests cover five modes, lanes, buffering, and ramp/distance. Human feel/readability judgment remains. |
| Gameplay camera | Implemented baseline; broader camera work partial | Profiles, aspect response and bounded feedback exist. Occlusion, cancellation, ownership edge cases, and subjective framing need more review. |
| Generation/rhythm/safe opening | Implemented baseline; fairness review partial | Repeated handoffs, source-resource integrity, contiguous track, all-nine soaks and validation now pass. Fine-grained reachable collision paths remain open. |
| Nine scenario libraries/environments | Implemented content baseline; experience partial | Earlier base/max validation and per-scenario soaks. All have safe/non-safe content; variety, fairness and enjoyment remain unproven. |
| Obstacles/pickups | Implemented baseline; fairness review partial | Silhouettes, continuous hazards, depth clearance and pickup feedback exist. Runtime collision/validator assumptions need adversarial comparison. |
| Frontend | Integration repaired; choreography preserved; polish partial | Earlier multi-size captures reviewed. Not a complete reauthoring of every interval/swap. |
| Scenario cinematics | Integration implemented; camera authoring partial | Selected subject, cover, settle and cleanup exist. Offset interpolation is not full stage-by-stage camera authoring. |
| HUD/pause/Game Over | Implemented baseline; current automated verification | Current native and exported-browser captures show pause, long labels, and readable ASCII Game Over text at tested sizes. |
| Procedural SFX/ambience | Functional baseline implemented; listening acceptance not performed | Resources/caches/buses/bindings exist. Mix and sound quality are unsigned. |
| Validation/packaging infrastructure | Implemented; current pipeline green | Import/Main, Tasks 00-27, production flow and soaks, three-size Compatibility rendering, Web packaging and pack audit pass. Browser smoke has no runtime errors; screenshots were reviewed. |
| Manual/device acceptance | Not completed | Automated capture/visual inspection is not human play, physical touch, listening, or sustained device-performance certification. |

Scenario additions: Hollywood has an aerial rise/dive/slalom corridor with depth markers/clouds/buildings; Grass has root/stone/hurdle/gate content and peripheral moving grass; Earthquake has a dedicated damaged-city environment, track, camera, and debris/crack/overhead/sweeper patterns. Other routes gained lane/edge dressing and corrections, including Golden Gate traffic placement, Boulevard slide content, and early Sequoia crosser variation. Bay's seabed was lowered; opaque aerial/water volumes and overlapping Grass ground were hidden.

Not yet performed: real physical mobile play, Safari/iOS and hosted itch iframe checks, sustained mobile performance checks, and full hands-on play/listening sign-off at the three requested sizes.

## 5. Safe-runway regression: repaired

The prior validation stopped at Task 10. Task 10 printed PASS while Godot logged an error, which the wrapper correctly rejected. The following is historical failure evidence:

Recorded errors:

```text
SCRIPT ERROR: Cannot call method 'duplicate' on a null value.
TrackGenerator._append_safe_recovery_segment
res://gameplay/track/TrackGenerator.gd:203

ERROR: TrackGenerator could not append a validated segment.
```

The stack went through `prepare_safe_runway`, `TransitionCoordinator._on_cinematic_completed`, forced cinematic completion, and Task 10's repeated handoff.

Immediately before the failure, short-runway code was changed to duplicate/shorten the fallback pattern, assign it to the duplicated SegmentDefinition's `eligible_patterns`, and validate the shortened pattern. The intention was an internally valid short-segment resource contract.

Confirmed defects: `_append_safe_recovery_segment()` called `duplicate()` before checking whether source lookup returned null. The duplicated segment's typed `eligible_patterns` array was then changed with `assign()`, which mutated the authored library shared by the shallow resource copy. The later fallback lookup could no longer find a source segment with the authored pattern length.

The fix checks lookup before duplication, replaces the temporary segment's pattern array with a fresh typed array, validates the temporary segment contract, and returns runway-preparation success. Generation is suspended during preparation and remains suspended on failure; Run Intro and scenario handoff keep control locked when preparation fails. Task 10 now snapshots resource identities, pattern IDs/counts/lengths, and checks repeated preparation, source-to-fixture-to-source handoffs, temporary validity, protected hazard distance, contiguous track, and failure suspension.

The clean full validation and export below include these regression assertions.

## 6. Deviations and compromises versus the original plan

- Historical constant speed, linear lanes, long empty opening, fixture destinations, and retry-owner expectations were revised because they conflict with the approved rehabilitation. Their tests were updated instead of preserving defects.
- The opening uses a short segment plus the next pattern's reaction lead-in, not an extra full blank segment, to meet first-hazard timing. The temporary-resource regression is repaired.
- CosmeticMount was reused rather than adding an equivalent second visual-pivot hierarchy, preserving collision separation without unnecessary architectural churn.
- Cinematic cameras currently interpolate per-transition offsets while tracking existing staged subjects. Fully authored multi-stage paths remain unfinished. Solid shared coverage and a short reveal are a baseline, not completion of all planned blur/coverage choreography.
- Tunnel/cave enclosing solids became thin roof geometry. Earthquake gained a torus donut/staged car traversal and Golden Gate's board follows its subject. These repair concrete errors but are not a comprehensive scenic/cinematic pass.
- Frontend work preserved/repaired the existing choreography rather than rebuilding it. Continuous motion/composition through every interval still needs subjective review.
- The soak runs ten simulated minutes per scenario using one-second steps and invulnerability: 90 simulated minutes of generator coverage, not 90 minutes of real play or fine-grained collision testing.
- Browser smoke uses headless Chromium/Edge, software ANGLE, real keyboard dispatch, a real browser touch-swipe dispatch, resizing, and touch-capability emulation. It is not physical touch or Safari/hosted-itch acceptance; the swipe screenshot does not by itself assert lane movement.
- Synthesized tonal/noise beds establish original functional audio without copyrighted material. Richness, mixing, and distinct scenario sound identity have not received listening sign-off.

## 7. Unresolved experience problems

- Safe-runway generation now passes repeated automated handoffs; longer real-play retry/transition endurance remains to be assessed.
- “Good-feeling game” is not signed off. Primitive art is intentional, but repeated corridors/posts/slabs, simple cosmetic transforms and limited pattern variety may still feel generic or weak.
- Continuous moving-hazard overlap and actual-height depth avoidance differ from the discrete validator's abstractions. Reachable reaction paths need testing at relevant speeds/frame rates beyond invulnerable generation.
- Camera entry/failure framing, cinematic stages, portrait occlusion, cancellation and settlement need focused review. Shared framing/impact impulses do not replace authored composition everywhere.
- Frontend/handoff coverage exists, but uninterrupted motion and motivated continuity are only partially evaluated.
- Entry hints are basic directional text; device-specific teaching is limited. Touch gesture comfort and pause/retry interaction remain unverified on hardware.
- `RUN ENDED` ASCII glyphs and long scenario-label wrapping appear in current render/export captures; final device readability is still open.
- Audio levels, repetition, transitions, pause behavior by listening, and mobile browser audio unlocking remain to be checked.
- Exhaustive transition cancellation/ownership and pattern repeat/recovery matrices are incomplete. Pool bounds do not prove acceptable device frame times or memory use.
- Physical mobile, sustained performance, Safari/iOS, hosted itch, and final human play/listening acceptance are outstanding.

## 8. Validation history and artifact freshness

Environment: Godot 4.7.2 Stable, Compatibility renderer. Times below are local filesystem timestamps on September 23, 2026. Base HEAD is `8cca1f0`; rehabilitation changes remain uncommitted, so the artifact hash below identifies this build more precisely than HEAD.

### Earlier passing evidence

- All 28 historical CLI suites (Tasks 00-27) passed at an earlier snapshot.
- RehabilitationTest traversed production boot/attract/reveal/selection/Run Intro, routed pause/resume and native key delivery, natural first-token stepping, all eight shuffled destinations, service/mode/profile bindings, actual collision to automatic Game Over, retry, and island return.
- Runner checks at 30/60/120 Hz covered five modes, queued/opposing lanes, vertical settlement, near-boundary buffering, and global speed/distance.
- Every production scenario's patterns were checked at base/maximum speed. Ten simulated minutes per scenario checked supported content, no holes, bounded windows/pools, and ordinary-safe rates.
- Native Main/Compatibility captures covered 960x720, 844x390, 360x640, frontend, all scenarios/transitions, pause/failure, and resize. A harness deferred-state timing issue was corrected; a targeted render rerun passed at 08:48:45, before the latest generator regression.
- Earlier Web/package audit inspected 355 exported resources and excluded references, recorded media, tests, fixtures and development frontend. Archive: 12 entries, approximately 10.5 MB compressed / 40.5 MB extracted.
- Exported-browser screenshot review after the input guard fix confirmed attract, selection, running, pause, resize, automatic Game Over, fresh retry, and direct island return; console errors were empty. An earlier clean-console run reached incorrect states, so screenshot review remains mandatory.
- A whitespace diff check passed before the stop; this is not runtime evidence.

### Current-source run

| Evidence | Observation | Interpretation |
| --- | --- | --- |
| `./tools/validate_rehabilitation.ps1 -Render -Export` | Final rerun completed at approximately 23:25 | Import, Main, Tasks 00-27, production flow and nine 600-second simulated soaks, three-size Compatibility rendering, Web package, and pack audit passed with no engine errors. |
| `build/rehabilitation/task_10.log` | Current full run | Repeated handoff and resource-integrity regression passed with no engine error. |
| `build/itch/californication-web.zip` | 23:25:11; 10,511,251 bytes | Current exported package. SHA-256 `BCC312D5C758F1269C60BED1E09536B9DF1E58AA7FABBF1AA024072EE91C46E8`. |
| `node tools/smoke_web.mjs` | Run against that exported package | Browser console has no runtime errors. Reviewed attract, selection, running, pause, both resize states, ASCII Game Over, retry and island-return captures. Touch swipe was dispatched and captured; lane response was not independently asserted. |

Logs are overwritten per step, not atomically per complete run: the directory mixes generations. Native screenshots also accumulate. Correlate timestamps and inspect images; do not infer visual acceptance from a PASS line or clean browser console.

Evidence locations:

- `build/rehabilitation/task_10.log`: current regression pass.
- `build/rehabilitation/production_flow_and_soaks.log`: current integration/soak evidence.
- `build/rehabilitation/render.log` and `.godot/rehab-*.png`: current native evidence; correlate timestamps.
- `build/rehabilitation/pack_content.log`: current exported-resource audit.
- `build/rehabilitation/browser/console.json` and PNGs: current Web evidence; review reached states.

## 9. Remaining acceptance work

The next meaningful pass is hands-on play and listening at 960x720, 844x390 and 360x640, with attention to hazard fairness, control feel, camera framing, cinematic continuity, UI reachability and audio mix. Physical touch, Safari/iOS, sustained mobile performance and an itch.io iframe launch still need device/host access. The automated browser swipe capture alone is not a lane-response assertion. Record observed issues and fix those that block a coherent arcade graybox; rerun the relevant current-source pipeline after changes.

Validation commands:

```powershell
./tools/validate_rehabilitation.ps1 -Render -Export
node tools/smoke_web.mjs
```

The wrapper runs import/main, Tasks 00-27, integration/soaks, optional rendering, export/package and resource audit; it rejects engine errors even with exit zero. Browser smoke defaults to installed Microsoft Edge, or accepts a Chromium executable as its first argument. It uses a localhost-only server and isolated profile and closes browser/server. Its runtime-error report is not an automatic assertion of every gameplay state.

## 10. File map

- `main/Main.*`, `presentation/PresentationRoot.*`: production composition/ownership.
- `autoload/GameFlow.gd`, `InputRouter.gd`, `ScenarioManager.gd`: lifecycle, input guard, shuffle/services.
- `frontend/run_intro/`, `gameplay/failure/FailureCoordinator.gd`: fresh-run ownership/failure.
- `gameplay/runner/RunnerController.gd`, `data/movement_profiles/`, `presentation/GameplayCameraRig.gd`, `data/camera_profiles/`: movement/presentation/camera.
- `gameplay/track/TrackGenerator.gd`, `TrackPool.gd`, `TrackSegment.gd`, `data/definitions/SegmentDefinition.gd`, `data/patterns/`, `data/segments/`: generation/resource contracts/pooling/dressing.
- `gameplay/obstacles/ObstacleBase.gd`, `gameplay/collectibles/CollectibleBase.gd`, `presentation/PickupFeedback.gd`: collision/readability/pickups.
- `gameplay/transitions/`, `data/transitions/`, `scenarios/`, `presentation/cinematic_fx/`: handoff camera/subject/coverage/content.
- `autoload/AudioManager.gd`, `data/audio/`, `data/definitions/AudioCue.gd`, `AmbienceProfile.gd`: procedural audio.
- `data/definitions/CameraProfile.gd`, `MovementProfile.gd`, `ScenarioDefinition.gd`: extended interfaces.
- `ui/hud/`, `frontend/logo_reveal/`, `frontend/player_select/`, `project.godot`: frontend/responsive repairs.
- `tests/cli/Task10Test.gd`: handoff and resource-integrity regression. `RehabilitationTest.*`, `ExportAudit.gd`, `tools/validate_rehabilitation.ps1`, `tools/smoke_web.mjs`, `tools/package_web.ps1`, `export_presets.cfg`: validation/packaging.

The current-source automated pipeline is green. Full experience/device sign-off is still open.
