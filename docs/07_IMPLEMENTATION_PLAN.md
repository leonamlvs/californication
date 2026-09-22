# MVP Implementation Plan

This document describes how Tasks 00–24 should be executed incrementally for an itch.io HTML5 release. `docs/06_IMPLEMENTATION_TASKS.md` remains the source of truth for task boundaries, acceptance criteria, and the Global Definition of Done.

The specification audit found no unresolved design contradiction. Where task ordering exposes an unfinished dependency, use development-only fixtures rather than implementing later production content early. Production begins in Boulevard, then selects from the eight-scenario shuffle bag; DevHarness can explicitly cycle all nine scenarios.

## 1. System Dependency Map

```text
GameFlow
├── ScenarioManager ──> ScenarioDefinition
│   ├── Scenario environment / CameraRig
│   ├── TrackGenerator ──> segment + pattern definitions
│   │   ├── obstacle framework
│   │   └── collectible framework
│   └── TransitionCoordinator ──> TransitionDefinition + ShuffleBag
├── RunnerController ──> MovementMode + MovementProfile
│   └── InputRouter <── keyboard / gamepad / touch
├── RunStats ──> shared HUD
├── CharacterPresenter ──> CharacterDefinition
└── frontend / pause / failure UI

PresentationRoot ──> desktop 4:3 or mobile flexible frame + safe-area HUD
DevHarness ──> public debug interfaces of production systems
itch.io Web export ──> production scene tree, excluding DevHarness
```

`GameFlow` is the authoritative global state machine. `ScenarioManager` owns active-scenario lifecycle and selection. `RunnerController` owns shared player state and delegates directional-intent interpretation to a movement-mode component. Data resources configure systems without scenario-name branches in core gameplay.

## 2. Intended Repository / Scene Structure

| Path | Type | Responsibility and key dependencies |
|---|---|---|
| `project.godot`, `export_presets.cfg` | config | Compatibility renderer, main scene, input map, autoloads, single-threaded itch.io Web preset. |
| `main/Main.tscn` | scene | Root composition for presentation, frontend/run content, and overlay UI. |
| `autoload/` | scripts | `GameFlow`, `ScenarioManager`, `InputRouter`, `AudioManager`, `SaveManager`. |
| `core/` | scripts/resources | Enums, typed context, validators, shuffle bag, common helpers. |
| `data/definitions/` | resource scripts | Scenario, obstacle, character, transition, movement, camera, segment, pattern contracts. |
| `data/{scenarios,obstacles,characters,transitions,camera_profiles,movement_profiles}/` | resources | Editable content and tuning. |
| `gameplay/runner/` | scene/scripts | One `CharacterBody3D`, movement strategies, collision, cosmetic mount. |
| `gameplay/{track,obstacles,collectibles,transitions,scoring}/` | scenes/scripts | Shared streaming gameplay systems independent of art. |
| `scenarios/<id>/` | scenes/scripts | Scenario dressing, authored pattern libraries, special transition ride only. |
| `ui/` | scenes/scripts | Presentation root, shared HUD, menus, pause, game-over. |
| `dev/DevHarness.tscn` | scene | Direct system/scenario testing; never required by production flow. |
| `tests/cli/TestRunner.gd` | `SceneTree` script | Headless deterministic/smoke suites. |
| `art/`, `audio/` | assets | Replaceable primitives, simple materials, placeholder loops. |

Use lane X, height/depth Y, and forward `-Z`. Keep the runner near the origin while logical run distance advances and streamed world content moves toward it. This prevents long-run precision drift while remaining fully 3D.

## 3. Core Runtime Data Contracts

Use typed enums or `StringName` identifiers for intents, states, movement modes, obstacle classes, transition policies, and failure families. Shared systems compare those values, never scene names or visual asset identity.

Public interfaces:

- `InputRouter.intent_requested(intent)`; GUI-consumed pointer events suppress swipes.
- `RunnerController.request_left/right/up/down()`, `set_movement_mode(mode, profile)`, `reset_for_run()`, `set_invulnerable(enabled)`.
- `MovementMode.enter(runner, profile)`, `exit()`, `handle_intent(intent)`, `physics_step(delta)`, `get_capabilities()`.
- `GameFlow.request_transition(state)`, `start_new_run()`, `pause_run()`, `resume_run()`, `fail_run()`, `exit_run()`.
- `ScenarioManager.load_scenario(id)`, `unload_active_scenario()`, `begin_transition()`, `complete_transition()`.
- `TransitionRideController.start(context)`, `handle_intent(intent)`, `cancel()`, `completed` signal.

### `ScenarioDefinition`

Typed `Resource` with required spec fields: ID/display name, movement mode, base/max speed, lane spacing, segment/obstacle/collectible libraries, environment scene, camera profile, HUD-coordinate profile, transition definition, and minimum/guaranteed transition times. It also references a movement profile, failure family, optional scenario component scene, and development timing overrides. Its validation method reports invalid or incompatible references; the resource configures behavior but does not own lifecycle.

### `ObstacleDefinition`

Contains ID, one of the seven base obstacle classes, permitted movement modes, occupied lanes, motion/timing profile, collision profile, minimum reaction time, and replaceable scene. Runtime behavior derives from obstacle class and data, not mesh identity.

### `CharacterDefinition`

Contains ID, display name, mesh scene, portrait, and optional cosmetic skin data only. It contains no collision, movement, scoring, speed, obstacle, or scenario modifier.

### `TransitionDefinition`

Contains ID, source scenario, controller mode, transition scene, input mask, next-scenario policy, and optional transition camera. The scene implements the shared ride controller and emits completion; it never selects or loads the next scenario itself.

### Movement and camera profiles

Movement profile fields include mode, lane count/spacing, speed/acceleration, lateral duration/curve, jump/slide values, vertical offset/neutral return, allowed intents, bounds, and steering response. Camera profile includes FOV, follow distance, height, pitch, lateral look strength, aspect adjustment, and transition camera. All specified initial values remain resource-editable defaults.

### Track segment and pattern definitions

Segment definitions provide a replaceable scene, length, connection anchors, compatible modes, environment tags, and eligible patterns. Pattern definitions provide the required ID, length, difficulty, speed range, supported modes, reaction time, entrance/exit state sets, and typed obstacle/collectible placements. Placements use lane, vertical state, forward offset, rotation, and definition reference. Entrance/exit states are compact legal-state bitsets; movement modes expose reachability/capabilities to the validator.

## 4. Runtime Ownership Rules

- GameFlow owns all frontend, run, pause, transition, failure, retry, and island state transitions.
- ScenarioManager owns registration, active definition, loading, teardown, run-start choice, and shuffle selection.
- InputRouter owns device normalization; gameplay never reads raw keyboard input.
- RunnerController owns shared collision, forward distance, lane bounds, mode installation, and invulnerability.
- Movement modes own only interpretation of directional intent and their mode-local state.
- TrackGenerator owns segment/pool lifecycle, compatible pattern selection, and future solvability validation.
- Obstacle instances own class behavior; art is replaceable child content.
- RunStats owns score, distance, timer, and transition rewards.
- TransitionCoordinator owns readiness, token retry, generator suspension, protected handoff, and ride lifecycle.
- Transition scenes own authored presentation/path only.
- ShuffleBag owns no-repeat bag behavior. Production excludes Boulevard after its forced opening; DevHarness may cycle all nine.
- CharacterPresenter owns cosmetic replacement. HUD observes state and requests pause only; it never owns gameplay state.
- PresentationRoot owns game-frame policy and safe rectangles. CameraRig reads profiles but never affects spawning or reaction timing.
- Pause UI owns controls, while GameFlow owns simulation pause. Failure presentation selects/configures animation but collision authority stays shared.
- DevHarness calls public debug APIs. AudioManager owns bus values; SaveManager stays a minimal future boundary.

## 5. Task-by-Task Implementation Plan

Unless a task requires a rendered/manual check, finish it with:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 5
godot --headless --path . --script res://tests/cli/TestRunner.gd -- --suite=task_XX
```

Update `docs/TASK_STATUS.md` only after the task acceptance criteria and Global Definition of Done pass.

### Task 00 — Project Foundation

**Goal**  Create the Godot 4.7.2 Compatibility baseline without gameplay.

**Depends on**  Specifications only.

**Create / modify**  `project.godot`, `export_presets.cfg`, `main/Main.tscn`, autoload skeletons, required folders, `.gitignore`, and CLI test runner.

**Implementation**

1. Configure Compatibility rendering, 960×720 reference composition, main scene, GDScript, and empty typed autoload APIs.
2. Create a main composition root for future presentation, world, frontend, and overlay layers.
3. Add a Web export preset with initial safe settings; production itch.io export naming, packaging, and upload validation belong to Task 24.
4. Add a `SceneTree` test runner which can load the project/main scene and fail nonzero.

**Validation**  Run the common commands, confirm Godot 4.7.2, and check that the main scene displays a minimal placeholder with no parser or missing-resource errors.

**Acceptance**  Meet all Task 00 criteria.

**Do not implement yet**  Input, HUD, GameFlow screens, runner, scenarios, or final export hardening.

**Handoff state**  Valid empty project with stable directories, autoload boundaries, and CLI checks.

### Task 01 — Input Abstraction

**Goal**  Normalize desktop, optional gamepad, and swipe input into shared intents.

**Depends on**  Task 00.

**Create / modify**  InputMap configuration, `InputRouter`, swipe recognizer, and a development input scene with GUI exclusion control.

**Implementation**

1. Map arrows/WASD, pause/confirm/back, and conventional gamepad actions.
2. Emit typed intents from InputMap actions; do not expose raw keys to gameplay.
3. Detect one-finger unhandled swipes using configurable 6% shorter-usable-dimension distance.
4. Require touches to start/end outside handled GUI controls; cancel ambiguous multi-touch and resize/focus-lost gestures.

**Validation**  Test mappings, swipe direction/threshold, UI exclusion, and keyboard/touch equivalence manually and in CLI tests.

**Acceptance**  Meet all Task 01 criteria.

**Do not implement yet**  Runner movement, virtual D-pad, final HUD.

**Handoff state**  One reusable intent stream for every later consumer.

### Task 02 — Responsive UI Foundation

**Goal**  Establish adaptive presentation and one profile-driven HUD tree.

**Depends on**  Tasks 00–01.

**Create / modify**  `PresentationRoot`, game frame, safe-area helper, shared `HUD.tscn`, profile selector, layout test scene.

**Implementation**

1. Put world and HUD inside a centered 4:3 game frame on desktop; pillarboxes contain no required information.
2. Use actual safe usable size in mobile-flex mode, selected by touch/mobile capability plus available space and overridable in development.
3. Select FULL/MEDIUM/COMPACT by fit against component minimum sizes, never orientation/device name alone.
4. Use anchors and containers; hidden optional controls must have no layout reservation.
5. Preserve a 56×56 logical pause target and consume HUD touch input before swipe recognition.

**Validation**  Resize/render at 960×720, wide desktop, tablet, landscape phone, narrow phone, and safe-inset simulations.

**Acceptance**  Meet all Task 02 criteria; score/time/pause placeholders always remain.

**Do not implement yet**  Functional score/time, pause behavior, final decorative loops.

**Handoff state**  Shared responsive shell ready for UI and gameplay.

### Task 03 — GameFlow State Machine

**Goal**  Create authoritative placeholder frontend/run flow.

**Depends on**  Tasks 00–02.

**Create / modify**  `GameFlow.gd`, placeholder frontend/selection/pause/failure/retry screens, state tests.

**Implementation**

1. Define the specified normal states and reserve transition branch states for Task 08.
2. Implement one allowed-transition table and reject illegal transitions diagnostically.
3. Route placeholder controls and confirm/back/pause intents through GameFlow APIs.
4. Implement retry target Boulevard, selected-character session retention, exit-to-island, and session-only intro-seen state.

**Validation**  Automate legal/illegal transitions, retry YES/NO, pause/resume, and exit; traverse manually with keyboard/touch.

**Acceptance**  Meet all Task 03 criteria; GameFlow alone changes global state.

**Do not implement yet**  Runner, actual scenario loading, characters, settings, failure animation, intro presentation.

**Handoff state**  Every required placeholder state is traversable through stable APIs.

### Task 04 — RUN Movement

**Goal**  Implement the one shared runner and RUN strategy.

**Depends on**  Tasks 01 and 03.

**Create / modify**  Runner scene/controller, movement-mode base, RUN mode, tuning resources, runner test scene.

**Implementation**

1. Use one `CharacterBody3D` with capsule, cosmetic mount, lane/vertical state, and logical forward distance.
2. Advance distance automatically while future track content later scrolls toward the near-origin runner.
3. Implement deterministic three-lane movement, jump arc, and timed slide with safe interruption/reset behavior.
4. Forward InputRouter intents through `request_*`; keep tuning in resources and enforce bounds.

**Validation**  Test lane limits, repeated/opposing input, jump/slide completion/reset, and frame-rate variation; inspect feel manually.

**Acceptance**  Meet all Task 04 criteria; no scenario-name branch exists in controller/mode code.

**Do not implement yet**  Other modes, obstacles, scoring, or scenario dressing.

**Handoff state**  Extensible runner and movement contract.

### Task 05 — Seven Obstacle Primitives

**Goal**  Implement all seven graybox mechanics through a shared data-driven framework.

**Depends on**  Tasks 03–04.

**Create / modify**  Obstacle definition/base, seven placeholder scenes, spawning test scene.

**Implementation**

1. Select behavior by obstacle class with visual scenes as replaceable children.
2. Implement BLOCK, HURDLE, OVERHEAD, CROSSER, SWEEPER, GAP, and GATE using typed hit events and deterministic timing.
3. Route hits to RunnerController/GameFlow; only invulnerability suppresses a failure.
4. Keep crossers abstract capsules/dummies; scenario art later supplies avoidance presentation.

**Validation**  Spawn each independently, prove its intended response succeeds, verify collision failure, inspect collision shapes.

**Acceptance**  Meet all Task 05 criteria and preserve mesh-independent behavior.

**Do not implement yet**  Generator, scenario variants, final art.

**Handoff state**  Seven reusable mechanics with shared failure behavior.

### Task 06 — Segment and Pattern Generator

**Goal**  Stream an endless authored-procedural, solvable graybox track.

**Depends on**  Tasks 04–05.

**Create / modify**  Segment/pattern resources, generator, pool manager, finite-state validator, graybox library, soak scene.

**Implementation**

1. Maintain active ahead/behind segments and fully reset/recycle passed nodes.
2. Filter patterns by mode capability, speed, reaction time, and entrance state.
3. Validate active-tail-plus-candidate over 2–3 seconds using lane/posture finite-state bitsets.
4. Reject unsupported required actions and select a safe authored fallback if necessary.
5. Use seeded deterministic selection in tests and weighted eligible selection at runtime.

**Validation**  Test valid/impossible combinations, mode exclusions, speed bounds, and 10+ minute simulated soak with no holes/bounded pools.

**Acceptance**  Meet all Task 06 criteria; at least one legal state survives the complete validated window.

**Do not implement yet**  Pickups, tokens, scenarios, unimplemented mode behavior.

**Handoff state**  Long-running reusable generation foundation.

### Task 07 — Collectibles and Score

**Goal**  Add normal pickups, layouts, score, timer, and reset behavior.

**Depends on**  Tasks 03, 04, and 06.

**Create / modify**  Collectible base/pool, pattern resources, `RunStats`, HUD binding stubs.

**Implementation**

1. Implement one-shot pooled pickup triggers with no miss penalty.
2. Author all required layouts: STRAIGHT, ARC_UP/DOWN, LEFT_TO_RIGHT, RIGHT_TO_LEFT, ZIGZAG, JUMP_ARC, LANE_GUIDE, TRANSITION_RIDE_LINE.
3. Configure defaults of 10 points/meter and 100/pickup.
4. Advance active-run timer only and format `HH:MM:SS`; reset metrics/pickups only on fresh run.

**Validation**  Test pickup idempotence, pattern paths, time pause/reset behavior, score reset, and missed pickups.

**Acceptance**  Meet all Task 07 criteria.

**Do not implement yet**  Token/reward completion, final HUD animation.

**Handoff state**  Stable metrics and pooled collectible system.

### Task 08 — Transition Framework + DevHarness

**Goal**  Add shared transition lifecycle, shuffle bag, and direct testing surface.

**Depends on**  Tasks 03–07.

**Create / modify**  Transition definition/coordinator/token/base ride controller, shuffle bag, DevHarness, dev fixture scenarios.

**Implementation**

1. Activate GameFlow ready/token/ride/next states.
2. Schedule a validator-approved token after minimum time; at guaranteed time restrict selection to safe opportunities.
3. Retry shortly after a missed token with conservative safe content.
4. On collection, synchronously enable invulnerability, suspend normal generation, recycle unsafe pending content, and start the ride.
5. On completion, load target scenario, install mode/camera/HUD, create safe runway, resume normal play, then remove invulnerability.
6. Implement seeded shuffle tests and no immediate repeat on refill.
7. Add harness controls for speed, obstacles, collectible patterns, ready/token/death, invulnerability, and collision visualization.

**Validation**  Test timing, reachable token, missed retry, collection ordering, protected period, generator suspension, shuffle refill, fixture handoff.

**Acceptance**  Meet all Task 08 criteria; fixtures stay under `dev/` and out of production registry.

**Do not implement yet**  Production scenario transitions or later modes.

**Handoff state**  Scenario-neutral transition pipeline and harness.

### Task 09 — Boulevard

**Goal**  Implement opening RUN sidewalk corridor and curbside transition.

**Depends on**  Task 08.

**Create / modify**  Boulevard definition, environment/patterns, camera profile, transition controller.

**Implementation**

1. Keep three lanes wholly on sidewalk; disguise limits with primitive buildings, curb, and furniture.
2. Use weaving-oriented shared obstacle patterns that never require traffic entry.
3. Implement invulnerable curbside collectible route, lateral steering, scripted trash-can jump, and fall.
4. Handoff to development target until another production scenario is ready.

**Validation**  Verify boundaries, pattern solvability, input mask, authored sequence, cleanup, handoff.

**Acceptance**  Meet all Task 09 criteria.

**Do not implement yet**  SNOWBOARD/Sierra or final art.

**Handoff state**  Complete graybox opening scenario on shared systems.

### Task 10 — Sierra Nevada

**Goal**  Add SNOWBOARD and mountain/train transition.

**Depends on**  Tasks 08–09.

**Create / modify**  Snowboard mode/profile, Sierra definition/environment/patterns, train transition.

**Implementation**

1. Implement looser carve/lateral tuning, jump, and crouch as a strategy under the common runner.
2. Author snow/natural-gate patterns filtered by its capabilities.
3. Add deterministic three-position train roof, tunnel, collectible line, exit jump, and standard handoff.

**Validation**  Test capabilities, filtering, roof positions, tunnel teardown, repeated transitions.

**Acceptance**  Meet all Task 10 criteria.

**Do not implement yet**  SWIM/Bay or standalone snowboard controller.

**Handoff state**  Alternate movement mode proven without duplicate input/player architecture.

### Task 11 — San Francisco Bay

**Goal**  Add SWIM underwater gameplay and shark/wave transition.

**Depends on**  Task 08 and the mode-extension foundation.

**Create / modify**  Swim mode/profile, Bay definition/environment/vertical patterns, wave transition.

**Implementation**

1. Model temporary rise/dive with configurable offsets and neutral return.
2. Preserve lateral lane changes while depth changes and clamp swim volume.
3. Expose vertical states to generator validation.
4. Implement invulnerable surface/wave ride with shark placeholder, lateral pickups, launch.

**Validation**  Test repeated/opposing depth intents, neutral return, simultaneous lateral motion, bounds, patterns, immunity.

**Acceptance**  Meet all Task 11 criteria.

**Do not implement yet**  FLY, final underwater art, extra swim mechanics.

**Handoff state**  Shared lane-plus-temporary-depth mode.

### Task 12 — Sequoia

**Goal**  Implement forest RUN profile and mining-cart transition.

**Depends on**  Tasks 08–11.

**Create / modify**  Sequoia definition, forest patterns, mining-cart ride.

**Implementation**

1. Reuse RUN unchanged with forest-specific tuning/library.
2. Author timing-focused crossers/sweepers.
3. Implement three deterministic cart rail positions and rail switching in the shared transition interface.
4. Fully unload cave/cart before normal scenario resume.

**Validation**  Assert no runner modifications, test switch bounds/timing, repeated teardown.

**Acceptance**  Meet all Task 12 criteria.

**Do not implement yet**  New player controller or Filming Sets.

**Handoff state**  Data-driven scenario identity and reusable ride steering.

### Task 13 — Filming Sets

**Goal**  Implement backlot RUN and ordered multi-set ride.

**Depends on**  Task 12.

**Create / modify**  Filming Sets definition/patterns, multi-stage transition scenes/controller.

**Implementation**

1. Reuse RUN with clutter/crosser pattern rhythm.
2. Implement fixed stage order: space/action, non-explicit glamorous/romantic, Da Vinci-style workshop, exit door.
3. Keep one runner/context through all stages; limit steering by TransitionDefinition.

**Validation**  Test stage order, one player instance, input mask, exit handoff, repeated cleanup.

**Acceptance**  Meet all Task 13 criteria.

**Do not implement yet**  Final recreation/copyrighted imagery or CAR.

**Handoff state**  Multi-stage authored ride support.

### Task 14 — Golden Gate

**Goal**  Add CAR traffic gameplay, ramps, and cable ride.

**Depends on**  Tasks 08 and 13.

**Create / modify**  Car mode/profile and cosmetic mount, Golden Gate resources/patterns, cable transition.

**Implementation**

1. Keep common runner body and attach only a cosmetic car.
2. Support left/right traffic lanes and declared ramps; never require Down for survival.
3. Declare CAR capabilities so invalid crouch/slide patterns are excluded.
4. Implement automatic cable ride with Left/Right disabled and Up/Down authored actions.

**Validation**  Test filtering, lane bounds, ramps, disabled lateral cable input, vertical input, cleanup.

**Acceptance**  Meet all Task 14 criteria.

**Do not implement yet**  Vehicle physics/braking or final traffic art.

**Handoff state**  Vehicle presentation remains within shared runner architecture.

### Task 15 — Hollywood

**Goal**  Add fully 3D FLY and aerial-screw ride.

**Depends on**  Tasks 08, 11, and 14.

**Create / modify**  Fly mode/profile, Hollywood resources/aerial patterns, aerial-screw transition.

**Implementation**

1. Reuse temporary vertical states with FLY bounds/tuning.
2. Combine lateral lanes and altitude states inside 3D flight volume.
3. Use 3D collision/transforms only; never screen-coordinate logic.
4. Implement four-intent climb/descent aerial-screw ride and shared handoff.

**Validation**  Test all intent combinations, neutral return, bounds, 3D collision, generator compatibility, handoff.

**Acceptance**  Meet all Task 15 criteria.

**Do not implement yet**  Free-flight physics, final aerial art, Grass.

**Handoff state**  Four-direction 3D movement through the single runner.

### Task 16 — Grass

**Goal**  Add visibility-focused RUN and super-jump transition.

**Depends on**  Task 15.

**Create / modify**  Grass definition, occlusion-safe patterns/dressing, super-jump ride.

**Implementation**

1. Reuse RUN unchanged.
2. Keep decorative occluders separate from collision and enforce a configurable obstacle-readability corridor.
3. Prevent dense grass within required-obstacle reaction envelope.
4. Implement mostly authored super-jump without vehicle mode.

**Validation**  Run readability probes/debug rays through camera profiles, verify solvability, test ride handoff.

**Acceptance**  Meet all Task 16 criteria.

**Do not implement yet**  Grass shaders/final density or Earthquake.

**Handoff state**  Decorative visibility constraints protect fair gameplay.

### Task 17 — Earthquake

**Goal**  Add damaged-city dynamic hazards and high-speed car transition.

**Depends on**  Task 16.

**Create / modify**  Earthquake resources/dynamic hazard components, car/ramp/donut/ejection ride.

**Implementation**

1. Build damaged-road gaps/gates and timed moving hazards from shared classes.
2. Include dynamic event activation in validator slices and retain reaction time.
3. Implement fixed invulnerable stages: car entry, high-speed run, ramp, donut, ejection, fall.
4. Use TransitionRideController; do not switch normal RUN gameplay into CAR.

**Validation**  Test timed hazards at speed limits, deterministic stages, immunity, cleanup, repeated transitions.

**Acceptance**  Meet all Task 17 criteria.

**Do not implement yet**  Destruction physics, free car control, final city effects.

**Handoff state**  All nine graybox scenario mechanics exist.

### Task 18 — Scenario Runtime Hardening

**Goal**  Stabilize all scenario visits, selection, teardown, and reset.

**Depends on**  Tasks 09–17.

**Create / modify**  Production registry, ScenarioManager lifecycle checks, expanded DevHarness controls.

**Implementation**

1. Register/validate all nine definitions.
2. Force Boulevard on new run, then use an eight-item bag and prevent immediate post-refill repeat.
3. Centralize teardown of segments, obstacles, pickups, transitions, environment, timers, camera, and scenario components.
4. Reset runner mode/profile and local state atomically during handoff.
5. Add explicit DevHarness sequential/random all-nine cycling independent of production bag policy.

**Validation**  Run repeated full cycles; inspect duplicate prevention, stale nodes/timers, pool bounds, mode correctness, restart behavior.

**Acceptance**  Meet all Task 18 criteria.

**Do not implement yet**  Characters/settings/final menus/export polish.

**Handoff state**  Reliable long-session nine-scenario runtime.

### Task 19 — Characters

**Goal**  Add four mechanically identical cosmetic selections.

**Depends on**  Tasks 03, 04, and 18.

**Create / modify**  Character resources/scenes, CharacterPresenter, selection and pause swap bindings.

**Implementation**

1. Keep collision, movement, stats, and animation interface on runner.
2. Swap only cosmetic child/portrait from definition.
3. Retain selection on retry and allow pause-time swap without score/time/state reset.

**Validation**  Compare all mechanics/collision values, swap across scenarios/modes, verify no run reset.

**Acceptance**  Meet all Task 19 criteria.

**Do not implement yet**  Abilities, different hitboxes, final likenesses, disk save.

**Handoff state**  Cosmetic-only character system.

### Task 20 — Pause and Settings

**Goal**  Complete pause, audio settings, cosmetic swap, and exit flow.

**Depends on**  Tasks 18–19.

**Create / modify**  Pause overlay/controller, AudioManager bus bindings, session settings model.

**Implementation**

1. Freeze gameplay process domain while pause UI/input remains active.
2. Preserve exact runner/generator/scenario/timer/transition state.
3. Bind master/music/effects sliders to buses.
4. Route swap and exit through existing CharacterPresenter/GameFlow APIs and block underlying swipe input.

**Validation**  Pause in movement states and normal play; test exact resume, sliders, swap, exit.

**Acceptance**  Meet all Task 20 criteria.

**Do not implement yet**  Persistent settings, advanced options, failure UI.

**Handoff state**  Pause is reliable shared state, not scenario behavior.

### Task 21 — Failure and Game Over

**Goal**  Implement both failure families and common lava/retry flow.

**Depends on**  Tasks 03, 18, and 20.

**Create / modify**  Failure coordinator, floor-fall/launch scenes, lava game-over, failure-family definition fields.

**Implementation**

1. Pick floor fall or launch from ScenarioDefinition, never scenario-name chains.
2. Stop gameplay/control/generation, then run presentation.
3. Converge on one lava screen with primitive bandmates, GAME OVER, YES/NO.
4. YES resets run/bag/metrics and starts Boulevard; NO returns to island without forced intro replay.

**Validation**  Force both families in harness and representative scenarios; test one-shot failure, cleanup, YES/NO, pause/input exclusion.

**Acceptance**  Meet all Task 21 criteria.

**Do not implement yet**  Final animation/impact art or intro artwork.

**Handoff state**  Every collision completes full fail/retry/island flow.

### Task 22 — Intro Presentation

**Goal**  Replace placeholder frontend with full graybox first-session sequence.

**Depends on**  Tasks 03, 19, and 21.

**Create / modify**  Loading, island attract, title, alicorn, character-select presentation scenes.

**Implementation**

1. Keep sequence in existing GameFlow states.
2. Present loading, indefinite rotating island, title transition, placeholder alicorn, character select.
3. Support confirm from keyboard/touch/gamepad without event leakage.
4. Use session-only `intro_seen`; returning run goes to island, with debug/config replay override.

**Validation**  Test initial ordering, indefinite wait, each input source, return path, forced replay.

**Acceptance**  Meet all Task 22 criteria.

**Do not implement yet**  Copyrighted logos/video/likenesses or final cinematics.

**Handoff state**  Complete placeholder frontend journey.

### Task 23 — Final HUD Behavior

**Goal**  Bind functional HUD content and finalize responsive behavior.

**Depends on**  Tasks 02, 07, 18, and 20.

**Create / modify**  HUD presenters, placeholder loops, coordinate profile/generator, final layout tests.

**Implementation**

1. Bind read-only RunStats score/time and GameFlow pause request.
2. Add square placeholder band loop and scenario-selected decorative loop.
3. Generate decorative scenario-range X/Y/Z values, never real player transforms.
4. Enforce FULL all, MEDIUM hides scenario and conditionally coordinates, COMPACT hides both; score/time/pause always remain.
5. Recompute safely after viewport/safe-area changes without recreating gameplay.

**Validation**  Inspect profile layouts at representative sizes, live resize, safe insets, touch targets, and corridor readability.

**Acceptance**  Meet all Task 23 and responsive UI specification criteria.

**Do not implement yet**  Final HUD art, orientation-only layouts, separate HUD scenes.

**Handoff state**  One fully functional adaptive HUD.

### Task 24 — Web Hardening

**Goal**  Produce, package, upload, and validate the full Compatibility-rendered MVP on itch.io.

**Depends on**  Tasks 00–23.

**Create / modify**  Final Web preset/bootstrap, itch.io ZIP packaging/validation script or checklist, performance cleanup, hosted-browser checklist, production dev exclusion.

**Implementation**

1. Configure a single-threaded production Web export named `index.html`; DevHarness and fixtures must be unreachable in production flow. Do not require `SharedArrayBuffer`, GDExtension support, PWA header workarounds, or cross-origin isolation.
2. Keep generated companion filenames unchanged and all references relative with exact case. Audit the archive against itch.io's current limits: at most 1,000 extracted files, 500 MB total, 200 MB per file, and 240 characters per full path.
3. Package the contents of `build/web/` at the ZIP root so `index.html` is not nested under a parent directory.
4. Configure the itch.io project as an HTML Game: desktop 960 × 720 embed, click-to-play enabled, scrollbars disabled, and the itch.io fullscreen overlay disabled by default to avoid the bottom-right pause button. Enable Mobile Friendly only after mobile acceptance passes; mobile will launch into a dynamic fullscreen viewport.
5. Handle iframe focus, browser tab suspension/resume, touch cancellation, safe areas, live resize/orientation, and post-gesture audio startup/resume without advancing or corrupting run state.
6. Profile long cycles; cap pools, remove avoidable allocations/hitches, keep lighting/material counts low, and keep startup/package size well below hosting ceilings.
7. Test locally over HTTP, then upload to an itch.io draft/restricted page and retest logged out/incognito on desktop and real or emulated mobile.
8. Complete the hosted path across all nine scenarios, transitions, failure, retry, and island.

**Validation**

```powershell
New-Item -ItemType Directory -Force build/web
godot --headless --path . --export-release "Web" build/web/index.html
New-Item -ItemType Directory -Force build/itch
Compress-Archive -Path build/web/* -DestinationPath build/itch/californication-web.zip -Force
```

Verify `index.html` is at the archive root, inspect file/path/size limits, serve the unpacked build locally, and inspect the browser console. Upload the same ZIP to an itch.io draft/restricted page and repeat desktop iframe, mobile fullscreen, keyboard, touch, focus/resume, audio, and full-flow acceptance there.

**Acceptance**  Meet all Task 24 and Global Definition of Done criteria, including a clean hosted run on itch.io with no missing-file, case, absolute-path, mixed-content, or cross-origin-isolation error.

**Do not implement yet**  Final art, unsupported renderer features, unrequested mechanics/deployment.

**Handoff state**  Production itch.io HTML5 ZIP and verified project-page configuration for the complete graybox MVP.

## 6. Scenario Implementation Matrix

| Scenario | Normal mode / track | Special transition | Controls | Specific components | Shared dependencies |
|---|---|---|---|---|---|
| Boulevard | RUN / sidewalk | Curbside, trash jump/fall | L/R + authored jump | Sidewalk/curb dressing | RUN, generator, token, ride base |
| Sierra Nevada | SNOWBOARD / snow path | Train roof/tunnel/jump | L/R | Snowboard profile, roof positions | Strategies, lanes, pools |
| San Francisco Bay | SWIM / underwater | Shark wave/launch | L/R | Depth profile, wave route | Vertical states, ride base |
| Sequoia | RUN / forest | Mining cart/cave | L/R | Timed patterns, rails | RUN, moving obstacles |
| Filming Sets | RUN / backlot | Ordered set traversal | Authored/limited steering | Stage sequencer | Transition stage interface |
| Golden Gate | CAR / traffic bridge | Cable grind | U/D only | Car mount, cable controller | Runner, ramps, input mask |
| Hollywood | FLY / aerial corridor | Aerial screw | L/R/U/D | Flight volume, aerial ride | Vertical states, 3D collision |
| Grass | RUN / tall-grass trail | Super jump | Mostly authored | Readability constraints | RUN, camera, ride base |
| Earthquake | RUN / damaged street | Car/ramp/donut/ejection | L/R + authored ramp | Timed hazards/stages | Obstacles, validator, ride base |

## 7. Movement Mode Plan

`RunnerController` is the only gameplay player body. It owns collision, lane, common state, forward progress/speed, invulnerability, cosmetic mount, and mode installation. A mode receives intent and uses protected runner movement operations while reporting capabilities: supported intents, lane-change time, posture/vertical states, jump/gap capability, transition durations, and bounds.

- RUN: lane change, jump, slide.
- SNOWBOARD: looser carve, jump, crouch.
- SWIM: lane change plus temporary rise/dive and neutral return.
- CAR: traffic lane change plus declared ramp actions; Down is not survival-critical.
- FLY: lane and temporary altitude changes with neutral return.
- TRANSITION_RIDE: configured ride controller/input mask; never a second player architecture.

All mode tuning is data-driven. Mode switch always exits/cleans the old strategy before installing/resetting the new one.

## 8. Track Generation and Solvability Plan

- Stream pooled segments around a near-origin runner, using logical distance and bounded ahead/behind ranges.
- Fully reset signals, timers, transforms, collision, and local state when recycling nodes.
- Filter authored patterns by mode capability, speed, reaction time, entrance state, and scenario library.
- Represent legal state as `(lane, posture_or_vertical_state)` bitsets. Modes supply reachability over time.
- Convert forward offsets to event time from current/worst-case speed; propagate legal state through event slices across 2–3 seconds.
- Candidate plus active tail must retain at least one state after full window. The first response must meet declared reaction time.
- SWIM/FLY depth and CAR restrictions come from capability data, never scenario conditions.
- If no difficult candidate passes, use an authored empty/lane-guide recovery pattern. Never relax reaction time.
- Use deterministic seeds for tests and ordinary run seeds in production.

## 9. Transition Framework Plan

1. At scenario minimum time, ScenarioManager asks TransitionCoordinator for `TRANSITION_READY`.
2. Generator creates a validated safe token approach; after guaranteed time it prioritizes only safe opportunities.
3. A missed token reports passage and schedules another safe opportunity shortly afterward.
4. Collecting token synchronously grants invulnerability before collision processing, suspends generation, and clears unsafe queued content.
5. The configured ride receives runner/input/scoring/camera context and only allowed inputs.
6. Ride pickups receive transition pickup scoring; completion receives configurable default +500.
7. ScenarioManager tears down source, selects/loads target, installs mode/profile/camera/HUD, prepares a safe runway, resumes RUNNING, then removes invulnerability.

Each scenario contributes a data-selected ride scene/controller. It cannot bypass the shared selection, lifecycle, or cleanup logic.

## 10. Responsive UI Implementation Plan

- Root `Control` contains pillarbox background and game frame.
- Desktop uses a centered 960×720 logical 4:3 `SubViewport` in `AspectRatioContainer`; the itch.io desktop embed is configured to the same 960 × 720 size.
- Mobile-flex uses the safe usable rectangle; automatic frame mode uses touch/mobile capability plus actual space, with development override. itch.io mobile launches are click-to-play and use a dynamic fullscreen viewport.
- FULL/MEDIUM/COMPACT selection is fit-based. Orientation can trigger recalculation but never determine density alone.
- Use one HUD tree and containers/anchors. Hidden controls reserve no space.
- FULL shows all; MEDIUM hides scenario loop and keeps coordinates only if comfortable; COMPACT hides coordinates and scenario loop.
- Score, timer, pause never disappear; band square is final cosmetic removal. Pause hitbox is at least 56×56 logical pixels.
- Convert safe rect into game-frame coordinates. Consumed GUI touches never become swipes. Keep itch.io's optional bottom-right fullscreen overlay disabled by default so it cannot cover the pause control; if enabled later, add a hosting-overlay safe inset first.
- Camera profiles may raise/pull back on narrow aspects to preserve three-lane readability. Spawn/validation uses path distance, not camera frame entry.

## 11. DevHarness and Testing Strategy

`DevHarness.tscn` hosts production services behind debug controls, never copies gameplay behavior.

| Task availability | Harness controls |
|---|---|
| 04 | RUN selection and speed |
| 05 | Every obstacle and collision visibility |
| 07 | Collectible patterns and RunStats |
| 08 | Ready/token/death/invulnerability and fixture rides |
| 09–17 | Implemented scenario/transition selection |
| 10–15 | Implemented movement-mode selection |
| 18 | Sequential/random all-nine cycling and cleanup counters |
| 19–21 | Character, pause, failure family |
| 23 | Forced HUD profile/safe-area preview |

Display GameFlow state, scenario, mode, speed, legal-state mask, pools, invulnerability, score, and time. CLI suites cover deterministic contracts/solvability/lifecycle; rendered harness checks cover feel, visibility, touch, collisions, and ride presentation.

## 12. CLI Validation Strategy

Installed Godot is `4.7.2.stable.official.ed1daf0bf`. Use project import, bounded main-scene smoke runs, `SceneTree` suites, rendered DevHarness checks, and `--debug-collisions` where needed. `--check-only` applies with `--script` and is not a substitute for project import/main-scene validation. Web output must be served via HTTP. Final acceptance must also run from itch.io because its iframe, CDN subdirectory, filename case rules, and mobile fullscreen launch are not reproduced completely by localhost.

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 5
godot --headless --path . --script res://tests/cli/TestRunner.gd -- --suite=task_XX
godot --path . --scene res://dev/DevHarness.tscn --resolution 960x720
godot --path . --scene res://dev/DevHarness.tscn --debug-collisions
godot --headless --path . --export-release "Web" build/web/index.html
Compress-Archive -Path build/web/* -DestinationPath build/itch/californication-web.zip -Force
```

## 13. Performance Strategy for Web

- Remain Compatibility-rendered throughout development.
- Keep the itch.io export single-threaded; do not rely on `SharedArrayBuffer` or cross-origin-isolation headers.
- Pool/recycle segments, obstacles, collectibles, tokens, and recurring environment objects with bounded counts.
- Avoid per-frame allocations, repeat loading, and repeated signal connections.
- Use primitive/shared materials, low material count, simple collision, limited dynamic lights/shadows, and no expensive post-processing.
- Disable processing/physics outside active ranges and use logical distance to avoid drift.
- Clean all scenario timers/signals/cameras/references at handoff.
- Safely cancel touch state and recompute layout on browser resize/orientation/focus changes.
- Profile long mobile-class cycles before increasing visual density. Do not introduce Forward+-only or compute-shader features.
- Keep exact-case, relative asset paths and remain within itch.io's extracted archive ceilings (1,000 files, 500 MB total, 200 MB per file, 240-character paths), while treating those limits as ceilings rather than performance goals.

## 14. Save / Persistent Data Boundary

The MVP has no specification requirement for durable browser/reload persistence; do not build a save system yet. In particular, do not rely on itch.io iframe access to IndexedDB/`user://`, which can be restricted by browser privacy settings.

Per-run reset: score, distance, time, active scenario/bag, seed/segments/pools, movement/transition state, invulnerability, failure state.

Session-only: selected character, `intro_seen`, current audio slider values, development overrides. `SaveManager` remains a skeleton until a persistence requirement is approved.

## 15. Known Risks

| Risk | Mitigation |
|---|---|
| Mobile Web performance | Compatibility-first assets, pools, simple materials, long-session profiling. |
| Swipe/UI conflict | Unhandled swipe processing, GUI consumption, gesture-origin tracking. |
| Aspect-ratio advantage | Camera clamps; all reaction/generation uses path distance. |
| Transition leaks | Atomic lifecycle teardown and repeated-cycle pool/node/timer checks. |
| Unsolvable sequences | Active-tail finite-state validation and safe fallback patterns. |
| Scenario state leakage | Reset mode, runner, timers, generator, camera, HUD data, local components at handoff. |
| Separate mode architectures | One runner body plus strategy interface and shared-contract tests. |
| Task-order pressure | Dev-only fixtures/capability data; no premature production implementation. |
| Human/animal collision tone | Shared abstract hazards with scenario near-collision presentation. |
| Browser focus/resize | Cancel gestures, preserve GameFlow, recompute presentation independently. |
| itch.io path/case failures | Use generated filenames unchanged, relative references, exact case, and test the uploaded ZIP rather than localhost alone. |
| itch.io iframe/mobile launch differences | Test desktop embed plus mobile fullscreen on a draft/restricted page before enabling Mobile Friendly. |
| Web thread/header incompatibility | Ship the Godot single-threaded export and avoid `SharedArrayBuffer`/cross-origin-isolation dependencies. |

## 16. Implementation Order Summary

| Task | Main deliverable | Depends on | Good stopping point |
|---|---|---|---|
| 00 | Project/CLI foundation | specs | Main scene launches |
| 01 | Shared input intents | 00 | Desktop/touch equivalent |
| 02 | Responsive shell | 00–01 | Profiles resize correctly |
| 03 | GameFlow | 00–02 | Placeholder flow traversable |
| 04 | RUN runner | 01, 03 | Lane/jump/slide deterministic |
| 05 | Seven obstacles | 03–04 | Each primitive avoids/fails |
| 06 | Validated generator | 04–05 | 10-minute soak passes |
| 07 | Score/collectibles | 03–06 | Reset/pattern checks pass |
| 08 | Transition/harness | 03–07 | Fixture round trip passes |
| 09 | Boulevard | 08 | Opening transition handoff |
| 10 | Sierra/SNOWBOARD | 08–09 | Train ride passes |
| 11 | Bay/SWIM | 08, 10 | Neutral-depth ride passes |
| 12 | Sequoia | 08–11 | Cart ride passes |
| 13 | Filming Sets | 12 | Ordered stages pass |
| 14 | Golden Gate/CAR | 08, 13 | Traffic/cable checks pass |
| 15 | Hollywood/FLY | 08, 11, 14 | 3D aerial checks pass |
| 16 | Grass | 15 | Readability/jump passes |
| 17 | Earthquake | 16 | Dynamic/ride passes |
| 18 | Lifecycle hardening | 09–17 | Repeated cycles pass |
| 19 | Characters | 03–04, 18 | Cosmetic swap passes |
| 20 | Pause/settings | 18–19 | Exact freeze/resume passes |
| 21 | Failure/game over | 03, 18, 20 | Both families converge |
| 22 | Intro | 03, 19, 21 | First/return paths pass |
| 23 | Functional HUD | 02, 07, 18, 20 | All profiles pass |
| 24 | itch.io Web release | 00–23 | Uploaded desktop/mobile browser matrix passes |

Assumptions and defaults:

- Existing gameplay-feel values remain configurable defaults, never hard-coded permanence.
- Placeholder/reference art never determines mechanics.
- Development fixtures remain under `res://dev/` and are excluded from production registration.
- itch.io is the production Web host; release artifacts use a root-level `index.html`, relative exact-case paths, and Godot's single-threaded Web export.
- `TASK_STATUS.md` remains unchanged when this plan is added and is updated only after numbered task acceptance.
- A task never begins adjacent task work merely to prove itself.
