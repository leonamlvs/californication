# MVP Implementation Plan

This document describes how Tasks 00–28 should be executed incrementally for an itch.io HTML5 release. `docs/06_IMPLEMENTATION_TASKS.md` remains the source of truth for task boundaries, acceptance criteria, and the Global Definition of Done.

The specification audit found no unresolved design contradiction. Where task ordering exposes an unfinished dependency, use development-only fixtures rather than implementing later production content early. Production begins in Boulevard, then selects from the eight-scenario shuffle bag; DevHarness can explicitly cycle all nine scenarios.

## 1. System Dependency Map

```text
GameFlow
├── FrontendCoordinator
│   ├── IslandIntro / IslandAttract
│   ├── LogoReveal / LogoCarousel
│   ├── PlayerSelectPresenter
│   ├── RunIntroController
│   └── CinematicTransitionFX
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
└── pause / failure UI

PresentationRoot ──> desktop 4:3 or mobile flexible frame + safe-area HUD
DevHarness ──> public debug interfaces of production systems
itch.io Web export ──> production scene tree, excluding DevHarness
```

`GameFlow` is the authoritative global state machine. The frontend is one continuous real-time 3D presentation whose logical stages are coordinated beneath GameFlow rather than a sequence of unrelated menu screens. `ScenarioManager` owns active-scenario lifecycle and selection. `RunnerController` owns shared player state and delegates directional-intent interpretation to a movement-mode component. Data resources configure systems without scenario-name branches in core gameplay.

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
| `scenarios/<id>/` | scenes/scripts | Scenario dressing, authored pattern libraries, and one scripted real-time 3D transition cinematic. |
| `frontend/{island,logo_reveal,player_select,run_intro}/` | scenes/scripts | Continuous 3D frontend choreography, carousel, and Boulevard camera handoff. |
| `presentation/cinematic_fx/` | scenes/scripts/resources | Reusable Compatibility-safe blur/FOV/fade transition effect and quality profiles. |
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
- `ScenarioTransitionController.start(context)`, `cancel()`, development-only `force_complete()`, and `completed` signal. It has no intent-handling API.

### `ScenarioDefinition`

Typed `Resource` with required spec fields: ID/display name, movement mode, base/max speed, lane spacing, segment/obstacle/collectible libraries, environment scene, camera profile, HUD-coordinate profile, transition definition, and minimum/guaranteed transition times. It also references a movement profile, failure family, optional scenario component scene, and development timing overrides. Its validation method reports invalid or incompatible references; the resource configures behavior but does not own lifecycle.

### `ObstacleDefinition`

Contains ID, one of the seven base obstacle classes, permitted movement modes, occupied lanes, motion/timing profile, collision profile, minimum reaction time, and replaceable scene. Runtime behavior derives from obstacle class and data, not mesh identity.

### `CharacterDefinition`

Contains ID, display name, gameplay mesh scene, portrait, frontend presentation scene, idle animation key, instrument/category label (`Vocals`, `Guitar`, `Bass`, or `Drums`), and decorative values for category, Strength, Stamina, Agility, Charisma, and Rhythm. These values drive frontend labels and animation targets only. It contains no collision, movement, scoring, speed, obstacle, or scenario modifier.

### `CinematicFXProfile`

Contains blur center, strength, sample/quality level, FOV start/end, overlay color/opacity, fade timing, and total duration. `CinematicTransitionFX` consumes the profile through one public play/cancel contract. The preferred implementation is a low-sample Compatibility `CanvasItem` screen-texture effect; low-quality mobile and FOV/overlay-only fallbacks are mandatory. The exact Godot 4.7 shader syntax must be verified when Task 22 is implemented, and this effect is never enabled during active gameplay.

### `TransitionDefinition`

Contains ID, source scenario, transition scene, next-scenario policy, optional transition camera, and configurable `transition_bonus_score` with MVP default `1000`. The scene implements the shared non-interactive cinematic controller and emits completion; it never handles gameplay input, awards score, or selects/loads the next scenario itself.

### Movement and camera profiles

Movement profile fields include mode, lane count/spacing, speed/acceleration, lateral duration/curve, jump/slide values, vertical offset/neutral return, allowed intents, bounds, and steering response. Camera profile includes FOV, follow distance, height, pitch, lateral look strength, aspect adjustment, and transition camera. All specified initial values remain resource-editable defaults.

### Track segment and pattern definitions

Segment definitions provide a replaceable scene, length, connection anchors, compatible modes, environment tags, and eligible patterns. Pattern definitions provide the required ID, length, difficulty, speed range, supported modes, reaction time, entrance/exit state sets, and typed obstacle/collectible placements. Placements use lane, vertical state, forward offset, rotation, and definition reference. Entrance/exit states are compact legal-state bitsets; movement modes expose reachability/capabilities to the validator.

## 4. Runtime Ownership Rules

- GameFlow owns all frontend, run, pause, transition, failure, retry, and island state transitions.
- FrontendCoordinator maps GameFlow's logical frontend states onto one continuously rendered 3D presentation; it never owns global state.
- IslandIntroController owns the one-shot close-vegetation-to-island pullback and uses authored scene-group/LOD swaps, FOV, and blur to imply cinematic scale without requiring a literal continuous world-scale camera path.
- IslandAttractController owns indefinite California-island rotation and waits for a state-approved keyboard/gamepad confirm or ordinary screen touch. It never restarts the intro automatically.
- LogoRevealController owns the blue sky/ocean handoff, extruded logo, circular `CALIFORNICATION` lettering, and alicorn pass. A visually continuous hidden scene-group swap is allowed during the blue frame.
- LogoCarouselController owns logo detents, Left/Right arrow activation, rotation lock, and at most one bounded queued step. Side character panels never select directly.
- PlayerSelectPresenter owns character/category/stat presentation and the reset-to-zero then animate-to-target sequence. Decorative values cannot affect gameplay.
- RunIntroController owns character confirmation, camera push/blur/front hold, Boulevard reveal, camera orbit to the runner, and the final readiness signal. Runner input and RunStats time remain disabled until readiness.
- CinematicTransitionFX owns reusable presentation-only blur/FOV/fade treatment, its low-quality mobile path, and graceful fallback; it is not a gameplay post-process.
- ScenarioManager owns registration, active definition, loading, teardown, run-start choice, and shuffle selection.
- InputRouter owns device normalization; gameplay never reads raw keyboard input.
- RunnerController owns shared collision, forward distance, lane bounds, mode installation, and invulnerability.
- Movement modes own only interpretation of directional intent and their mode-local state.
- TrackGenerator owns segment/pool lifecycle, compatible pattern selection, and future solvability validation.
- Obstacle instances own class behavior; art is replaceable child content.
- RunStats owns score, distance, timer, and the configurable one-shot Transition Token bonus (default `+1000`).
- TransitionCoordinator owns readiness, token retry, atomic input lock/invulnerability/generator suspension, bonus award and centered `BONUS` overlay, scripted-cinematic lifecycle, and protected handoff.
- Transition scenes own authored real-time 3D presentation only. They have no lanes, gameplay controls, collectibles, obstacles, or failure conditions.
- ShuffleBag owns no-repeat bag behavior. Production excludes Boulevard after its forced opening; DevHarness may cycle all nine.
- CharacterPresenter owns cosmetic replacement. HUD observes state and requests pause only; it never owns gameplay state.
- PresentationRoot owns game-frame policy and safe rectangles. CameraRig reads profiles but never affects spawning or reaction timing.
- Pause UI owns the responsive four-portrait selector, `SFX LEVEL`, `MUSIC LEVEL`, and `BACK`; GameFlow owns simulation pause. Failure presentation selects/configures animation but collision authority stays shared.
- DevHarness calls public debug APIs. AudioManager owns bus values; SaveManager stays a minimal future boundary.

Frontend visual continuity is an authored contract, not a requirement that every stage share one physical node hierarchy. The blue sky/ocean frame and full-screen transition effects may conceal deterministic scene-group swaps, provided the camera, color, motion, and logo pose remain visually continuous.

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
3. Add a Web export preset with initial safe settings; production itch.io export naming, packaging, and upload validation belong to Task 28.
4. Add a `SceneTree` test runner which can load the project/main scene and fail nonzero.

**Validation**  Run the common commands, confirm Godot 4.7.2, and check that the main scene displays a minimal placeholder with no parser or missing-resource errors.

**Acceptance**  Meet all Task 00 criteria.

**Do not implement yet**  Input, HUD, GameFlow screens, runner, scenarios, or final export hardening.

**Handoff state**  Valid empty project with stable directories, autoload boundaries, and CLI checks.

**Post-change audit**  No retrofit is required for the completed Task 00. Its Compatibility renderer, 960×720 reference frame, resizable single-threaded Web preset, root-level `index.html` export path, and production/dev separation remain compatible with the itch.io and scripted-transition specifications. Hosted click-to-play/project-page settings still belong to Task 28.

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

**Post-change audit**  No retrofit is required for the completed Task 01. Pause navigation and discrete audio adjustment reuse the existing directional/confirm/back intents. Transition input locking is owned by Task 08 consumers, not by a new device-input path. Frontend ordinary touch confirmation, visible arrow clicks, carousel input locking, and run-intro gating are state/controller responsibilities built on the same input stream and handled GUI events. Existing GUI consumption plus resize/focus-loss cancellation is the required itch.io iframe/mobile behavior.

### Task 02 — Responsive UI Foundation

**Goal**  Establish adaptive presentation for both the continuous 3D frontend and one profile-driven HUD tree.

**Depends on**  Tasks 00–01.

**Create / modify**  `PresentationRoot`, game frame, safe-area helper, frontend safe-composition guide, shared `HUD.tscn`, profile selector, layout test scene.

**Implementation**

1. Put world and HUD inside a centered 4:3 game frame on desktop; pillarboxes contain no required information.
2. Use actual safe usable size in mobile-flex mode, selected by touch/mobile capability plus available space and overridable in development.
3. Select FULL/MEDIUM/COMPACT by fit against component minimum sizes, never orientation/device name alone.
4. Use anchors and containers; hidden optional controls must have no layout reservation.
5. Preserve a 56×56 logical pause target and consume HUD touch input before swipe recognition.
6. Define a frontend camera-safe region and layout anchors for the island silhouette, logo ring, center character, side panels, stats, title, and arrows so mandatory content remains visible in desktop 4:3 and mobile-flex frames.

**Validation**  Resize/render HUD and frontend composition guides at 960×720, wide desktop, tablet, landscape phone, narrow phone, and safe-inset simulations.

**Acceptance**  Meet all Task 02 criteria; score/time/pause placeholders always remain.

**Do not implement yet**  Functional score/time, pause behavior, final decorative loops.

**Handoff state**  Shared responsive shell ready for frontend presentation, UI, and gameplay.

### Task 03 — Expanded GameFlow State Foundation

**Goal**  Create the authoritative logical state graph for the continuous frontend and run flow.

**Depends on**  Tasks 00–02.

**Create / modify**  `GameFlow.gd`, placeholder stage controls for the continuous frontend, pause/failure/retry placeholders, and state tests.

**Implementation**

1. Define `LOADING → ISLAND_INTRO → ISLAND_ATTRACT → LOGO_REVEAL → CHARACTER_SELECT_ENTER → CHARACTER_SELECT_ACTIVE → CHARACTER_CONFIRMED → RUN_INTRO → RUNNING`, plus pause/failure/game-over states, and reserve scenario-transition branch states for Task 08.
2. Implement one allowed-transition table and reject illegal transitions diagnostically.
3. Route placeholder controls and confirm/back/pause intents through GameFlow APIs, with per-state entry-consumption/input gating so one event cannot advance two stages.
4. `ISLAND_ATTRACT` waits indefinitely for a state-approved keyboard/gamepad confirm or ordinary screen touch. `CHARACTER_SELECT_ACTIVE` accepts selection commands only; confirmation advances to `CHARACTER_CONFIRMED`.
5. `RUN_INTRO` does not enter `RUNNING` until the future presentation controller reports camera settled and gameplay ready.
6. Implement retry to `RUN_INTRO` with Boulevard as the prepared target, selected-character session retention, exit-to-`ISLAND_ATTRACT`, and session-only `intro_seen` state.

**Validation**  Automate legal/illegal transitions, indefinite island wait, no event leakage, selection versus confirmation, run-intro readiness gate, retry YES/NO, pause/resume, and exit; traverse placeholders with keyboard, gamepad if available, and touch.

**Acceptance**  Meet all Task 03 criteria; GameFlow alone changes global state.

**Do not implement yet**  Runner, actual scenario loading, characters, settings, failure animation, or final frontend choreography.

**Handoff state**  Every logical frontend/run state is independently testable while still permitting one continuous rendered presentation later.

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
2. Author all required normal-gameplay layouts: STRAIGHT, ARC_UP/DOWN, LEFT_TO_RIGHT, RIGHT_TO_LEFT, ZIGZAG, JUMP_ARC, and LANE_GUIDE.
3. Configure defaults of 10 points/meter and 100/pickup.
4. Advance active-run timer only and format `HH:MM:SS`; reset metrics/pickups only on fresh run.

**Validation**  Test pickup idempotence, pattern paths, time pause/reset behavior, score reset, and missed pickups.

**Acceptance**  Meet all Task 07 criteria.

**Do not implement yet**  Token bonus/cinematic behavior, final HUD animation.

**Handoff state**  Stable metrics and pooled collectible system.

### Task 08 — Scenario Transition Framework + DevHarness Base

**Goal**  Add shared transition lifecycle, shuffle bag, and direct testing surface.

**Depends on**  Tasks 03–07.

**Create / modify**  Transition definition/coordinator/token/base scripted-cinematic controller, shared `BONUS` overlay, shuffle bag, DevHarness, dev fixture scenarios.

**Implementation**

1. Activate GameFlow `TRANSITION_READY`, `TOKEN_COLLECTED`, `SCENARIO_TRANSITION`, and `NEXT_SCENARIO` states. `SCENARIO_TRANSITION` is not a movement mode.
2. Schedule a validator-approved token after minimum time; at guaranteed time restrict selection to safe opportunities.
3. Retry shortly after a missed token with conservative safe content.
4. On collection, atomically lock gameplay input, stop runner motion, enable invulnerability, suspend normal generation, recycle unsafe pending content, award `transition_bonus_score` once (default `1000`), show centered `BONUS`, visibly update the ordinary upper-right score, and start the scripted cinematic. Do not use a combined `BONUS +1000!` popup.
5. Forward no gameplay intents during the cinematic and disable gameplay collisions, pickups, hazards, and failure.
6. On completion, load the target scenario, install mode/camera/HUD, create a safe runway, resume normal play, hide `BONUS`, then unlock input and remove invulnerability.
7. Implement seeded shuffle tests and no immediate repeat on refill.
8. Add harness controls for speed, obstacles, collectible patterns, ready/token/death, invulnerability, cinematic completion/skip, bonus idempotence, quick cycling of registered fixture scenarios, and collision visualization. Task 18 expands cycling to all nine production scenarios.

**Validation**  Test timing, reachable token, missed retry, atomic collection ordering, single bonus award, centered overlay lifetime, input lock, absence of cinematic gameplay entities/failure, protected period, generator suspension, shuffle refill, and fixture handoff.

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
3. Implement an input-locked real-time 3D curbside cinematic with a deterministic trash-can jump and fall; add no transition collectibles or gameplay hazards.
4. Handoff to development target until another production scenario is ready.

**Validation**  Verify boundaries, pattern solvability, gameplay-input lock, authored sequence, cleanup, and handoff.

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
3. Script the fall onto a train roof, tunnel sequence, and jump away as an automatic cinematic with standard handoff.

**Validation**  Test capabilities/filtering for normal gameplay, cinematic input lock/stage order, tunnel teardown, and repeated transitions.

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
4. Implement an invulnerable, input-locked surface/shark-wave/launch cinematic with no pickups or hazards.

**Validation**  Test repeated/opposing depth intents, neutral return, simultaneous lateral motion, bounds, patterns, immunity.

**Acceptance**  Meet all Task 11 criteria.

**Do not implement yet**  FLY, final underwater art, extra swim mechanics.

**Handoff state**  Shared lane-plus-temporary-depth mode.

### Task 12 — Sequoia

**Goal**  Implement forest RUN profile and mining-cart transition.

**Depends on**  Tasks 08–11.

**Create / modify**  Sequoia definition, forest patterns, mining-cart cinematic.

**Implementation**

1. Reuse RUN unchanged with forest-specific tuning/library.
2. Author timing-focused crossers/sweepers.
3. Implement a deterministic authored mining-cart cave route through the shared scripted-cinematic interface; there is no player rail switching.
4. Fully unload cave/cart before normal scenario resume.

**Validation**  Assert no runner modifications, verify authored route timing/input lock, and repeat teardown.

**Acceptance**  Meet all Task 12 criteria.

**Do not implement yet**  New player controller or Filming Sets.

**Handoff state**  Data-driven scenario identity and reusable scripted-cinematic staging.

### Task 13 — Filming Sets

**Goal**  Implement backlot RUN and ordered multi-set cinematic.

**Depends on**  Task 12.

**Create / modify**  Filming Sets definition/patterns, multi-stage transition scenes/controller.

**Implementation**

1. Reuse RUN with clutter/crosser pattern rhythm.
2. Implement fixed stage order: space/action, non-explicit glamorous/romantic, Da Vinci-style workshop, exit door.
3. Keep one runner/presentation context through all stages and keep gameplay input locked.

**Validation**  Test stage order, one player instance, input lock, exit handoff, and repeated cleanup.

**Acceptance**  Meet all Task 13 criteria.

**Do not implement yet**  Final recreation/copyrighted imagery or CAR.

**Handoff state**  Multi-stage authored cinematic support.

### Task 14 — Golden Gate

**Goal**  Add CAR traffic gameplay, ramps, and scripted cable cinematic.

**Depends on**  Tasks 08 and 13.

**Create / modify**  Car mode/profile and cosmetic mount, Golden Gate resources/patterns, cable transition.

**Implementation**

1. Keep common runner body and attach only a cosmetic car.
2. Support left/right traffic lanes and declared ramps; never require Down for survival.
3. Declare CAR capabilities so invalid crouch/slide patterns are excluded.
4. Script leaving the car, landing on a snowboard, grinding the main cable, and launching away with gameplay input locked.

**Validation**  Test normal CAR filtering/lane bounds/ramps, cinematic input lock and stage order, and cleanup.

**Acceptance**  Meet all Task 14 criteria.

**Do not implement yet**  Vehicle physics/braking or final traffic art.

**Handoff state**  Vehicle presentation remains within shared runner architecture.

### Task 15 — Hollywood

**Goal**  Add fully 3D FLY and scripted aerial-screw cinematic.

**Depends on**  Tasks 08, 11, and 14.

**Create / modify**  Fly mode/profile, Hollywood resources/aerial patterns, aerial-screw transition.

**Implementation**

1. Reuse temporary vertical states with FLY bounds/tuning.
2. Combine lateral lanes and altitude states inside 3D flight volume.
3. Use 3D collision/transforms only; never screen-coordinate logic.
4. Implement an input-locked authored aerial-screw craft climb/descent and shared handoff.

**Validation**  Test all intent combinations during normal FLY gameplay, neutral return, bounds, 3D collision, generator compatibility, cinematic input lock, and handoff.

**Acceptance**  Meet all Task 15 criteria.

**Do not implement yet**  Free-flight physics, final aerial art, Grass.

**Handoff state**  Four-direction 3D movement through the single runner.

### Task 16 — Grass

**Goal**  Add visibility-focused RUN and super-jump transition.

**Depends on**  Task 15.

**Create / modify**  Grass definition, occlusion-safe patterns/dressing, scripted giant-jump cinematic.

**Implementation**

1. Reuse RUN unchanged.
2. Keep decorative occluders separate from collision and enforce a configurable obstacle-readability corridor.
3. Prevent dense grass within required-obstacle reaction envelope.
4. Implement the fully authored, input-locked giant jump without a vehicle mode.

**Validation**  Run readability probes/debug rays through camera profiles, verify solvability, and test cinematic handoff.

**Acceptance**  Meet all Task 16 criteria.

**Do not implement yet**  Grass shaders/final density or Earthquake.

**Handoff state**  Decorative visibility constraints protect fair gameplay.

### Task 17 — Earthquake

**Goal**  Add damaged-city dynamic hazards and high-speed car transition.

**Depends on**  Task 16.

**Create / modify**  Earthquake resources/dynamic hazard components, scripted car/ramp/donut/midair-exit cinematic.

**Implementation**

1. Build damaged-road gaps/gates and timed moving hazards from shared classes.
2. Include dynamic event activation in validator slices and retain reaction time.
3. Implement fixed invulnerable stages: car entry, high-speed run, ramp, donut, ejection, fall.
4. Use `ScenarioTransitionController`; do not switch normal RUN gameplay into CAR or accept gameplay input during the cinematic.

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

### Task 19 — Character Data and Presentation

**Goal**  Add four mechanically identical characters with reusable gameplay and frontend presentation data.

**Depends on**  Tasks 03, 04, and 18.

**Create / modify**  Character resources, gameplay cosmetic scenes, frontend presentation scenes, face portraits, CharacterPresenter, and pause-HUD portrait bindings.

**Implementation**

1. Keep collision, movement, gameplay statistics, and gameplay animation interface on the runner.
2. Add category and decorative category/Strength/Stamina/Agility/Charisma/Rhythm values to each definition. They drive frontend labels and bars only and are tested not to alter mechanics.
3. Provide a stable-scale frontend presentation scene and idle animation key separately from the gameplay cosmetic child where useful.
4. Swap only visual/portrait references in gameplay. Retain selection on retry and allow pause-time immediate swap without score/time/state reset; pause portraits expose faces only and no names, statistics, cards, or descriptions.

**Validation**  Compare all mechanics/collision values, prove decorative values cannot enter gameplay calculations, validate presentation references/scales, swap across scenarios/modes, verify no run reset, and verify pause selection moves focus directly to `BACK`.

**Acceptance**  Meet all Task 19 criteria.

**Do not implement yet**  Logo carousel, animated stat UI, abilities, different hitboxes, final likenesses, or disk save.

**Handoff state**  Cosmetic-only character system ready for both gameplay and the later 3D carousel.

### Task 20 — Pause and Settings

**Goal**  Complete pause, audio settings, cosmetic swap, and exit flow.

**Depends on**  Tasks 18–19.

**Create / modify**  Responsive pause HUD/controller, four-portrait column, AudioManager bus bindings, discrete session audio settings model.

**Implementation**

1. Freeze gameplay process domain while pause UI/input remains active.
2. Preserve exact runner/generator/scenario/timer/transition state.
3. Keep Score and Time upper-right with a vertical column of four face portraits below; focused portrait uses only a rounded green/yellow outline.
4. Expose only `SFX LEVEL`, `MUSIC LEVEL`, and `BACK`; map the two audio values to approximately ten discrete steps. An internal Master bus is allowed, but no Master control or audio submenu is player-facing.
5. Implement deterministic navigation: Up/Down through portraits, Confirm applies the face and focuses `BACK`, Left from the portrait section reaches `SFX LEVEL`, and Confirm enters/exits Left/Right audio adjustment.
6. Support direct touch activation, consume all pause GUI events, and reflow from the safe usable rectangle so all four portraits and mandatory controls remain accessible with touch-safe targets.
7. Route swap and exit through existing CharacterPresenter/GameFlow APIs. Optional gameplay Coordinates/Scenario/Band panels may hide behind pause when space requires it.

**Validation**  Pause in movement states and normal play; test exact resume, roughly ten-step SFX/Music controls, specified keyboard/gamepad focus path, direct touch, immediate cosmetic swap/focus-to-`BACK`, no input leakage, exit, and small safe-area layouts containing every mandatory control.

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
4. YES resets run/bag/metrics, prepares Boulevard, and enters `RUN_INTRO`; NO returns to `ISLAND_ATTRACT` without replaying the one-shot island pullback.

**Validation**  Force both families in harness and representative scenarios; test one-shot failure, cleanup, YES/NO, pause/input exclusion.

**Acceptance**  Meet all Task 21 criteria.

**Do not implement yet**  Final animation/impact art or intro artwork.

**Handoff state**  Every collision completes full fail/retry/island flow.

### Task 22 — CinematicTransitionFX

**Goal**  Build the reusable presentation-only transition treatment before frontend choreography depends on it.

**Depends on**  Tasks 02–03.

**Create / modify**  `CinematicTransitionFX`, `CinematicFXProfile`, a Compatibility shader/material path, low-quality and FOV/overlay fallbacks, and a rendered test scene.

**Implementation**

1. Expose blur center, strength, sample/quality level, FOV start/end, overlay color/opacity, fade timing, duration, play, cancel, and completion.
2. Prefer a `CanvasItem` screen-texture shader with low fixed sample counts and bounded cost. Verify the exact Godot 4.7 Compatibility shader syntax during implementation rather than relying on older examples.
3. Supply a cheaper mobile profile and a deterministic FOV/overlay-only fallback when screen sampling is unavailable or over budget.
4. Guarantee cleanup after completion/cancel and enforce that the effect cannot remain active after GameFlow enters `RUNNING`.

**Validation**  Render each quality path, test resize/safe-area changes, cancellation, fallback selection, cleanup, and a guard proving active gameplay never retains the effect.

**Acceptance**  Meet all Task 22 criteria with bounded Compatibility-renderer cost and graceful degradation.

**Do not implement yet**  Island/logo/carousel/Run Intro choreography or active-gameplay post-processing.

**Handoff state**  Reusable frontend transition treatment with a safe itch.io/mobile fallback.

### Task 23 — Loading, Island Intro, and Island Attract

**Goal**  Implement the one-shot close-vegetation pullback and indefinite rotating-island attract stage.

**Depends on**  Tasks 03 and 22.

**Create / modify**  Loading presentation, California-island scene, close palms/vegetation and city/landscape groups, IslandIntroController, IslandAttractController, and frontend camera path.

**Implementation**

1. Run `LOADING → ISLAND_INTRO` automatically, starting among close palms/vegetation and pulling back through authored road/city/landscape groups to the California-shaped island.
2. Fake cinematic scale with deterministic scene-group or LOD swaps, FOV change, and the shared blur effect. Do not require a literal one-shot world-scale mesh/camera path.
3. Set readable placeholder proportions: characters around 1.7–1.8 m, cars around 4–5 m, palms around 8–12 m, while the island uses cinematic presentation scale.
4. Enter `ISLAND_ATTRACT`, rotate indefinitely, and wait for one keyboard/gamepad confirm or ordinary screen touch. Never loop `ISLAND_INTRO` while waiting.
5. Support DevHarness entry at intro start and directly at attract, plus a replay-intro development override.

**Validation**  Test automatic loading handoff, authored swap continuity, exact one-shot behavior, indefinite wait, all confirm sources, input debouncing, supported aspect/safe-area composition, replay override, and mobile quality profile.

**Acceptance**  Meet all Task 23 criteria; placeholder scale reads consistently even though the island pullback is an authored illusion.

**Do not implement yet**  Logo/alicorn, carousel, final vegetation/city art, or final loading branding.

**Handoff state**  First-session island reveal and reusable returning-session attract stage.

### Task 24 — Logo/Alicorn Reveal and Player Select Entry

**Goal**  Continue from island attract through the blue handoff, logo/alicorn reveal, and arrival at the same logo's selection orientation.

**Depends on**  Task 23.

**Create / modify**  Extruded placeholder logo, circular 3D `CALIFORNICATION` lettering, alicorn placeholder/path, LogoRevealController, and logo presentation rig.

**Implementation**

1. On attract confirmation, move through ocean/sky until a near-solid blue frame can conceal a deterministic scene-group swap when needed.
2. Reveal the extruded logo and circular lettering as real 3D geometry, then stage the alicorn approach/pass without replacing the logo with a separate menu prop.
3. Rotate the same logo to its player-selection entry detent and finish in `CHARACTER_SELECT_ENTER` with stable pivot and panel anchors.
4. Maintain camera/color/motion continuity across any hidden swap and consume the initiating input so it cannot also select or confirm a character.

**Validation**  Verify object identity/continuity, hidden-swap seam, alicorn path, stable logo pivot/detents, safe composition, no input leakage, and direct DevHarness entry/skip.

**Acceptance**  Meet all Task 24 criteria; the result reads as one continuous 3D sequence rather than a cut to a generic menu.

**Do not implement yet**  Selectable character panels, stat animation, confirmation zoom, final copyrighted branding, or final creature art.

**Handoff state**  Logo rig parked at a deterministic carousel-ready orientation.

### Task 25 — 3D Logo Carousel and Decorative Player Select

**Goal**  Turn the existing logo into the complete four-character 3D selection carousel.

**Depends on**  Tasks 19 and 24.

**Create / modify**  LogoCarouselController, four panel anchors, visible arrows, PlayerSelectPresenter, animated decorative stat display, and carousel tests.

**Implementation**

1. Attach one character presentation panel to each logo face/anchor; rotating the logo brings a panel to the center detent.
2. Accept Left/Right intents and clicks/taps on visible arrow controls only. Clicking/tapping a side character panel never selects it.
3. Lock navigation while rotating and permit at most one bounded queued step; normalize every completed rotation to an exact detent to prevent drift.
4. On detent arrival, show `PLAYER SELECT`, display name/category, reset category plus Strength/Stamina/Agility/Charisma/Rhythm values to zero, then animate them to CharacterDefinition targets.
5. Confirm only the centered stable character, record the session selection, and advance to `CHARACTER_CONFIRMED` exactly once.

**Validation**  Test wraparound, rapid/opposing inputs, arrow clicks, rejected side-panel clicks, queue bound, detent normalization, stat reset/replay, decorative-only mechanics invariance, confirmation debounce, touch hitboxes, and safe composition.

**Acceptance**  Meet all Task 25 criteria; selection is a 3D logo rotation, never a replacement panel/card menu.

**Do not implement yet**  Boulevard camera handoff, gameplay abilities, final likenesses, or final logo art.

**Handoff state**  Robust cosmetic selection that feeds the existing session character value.

### Task 26 — Character Confirmation and Run Intro

**Goal**  Continue character confirmation directly into Boulevard and enable gameplay only after the camera settles behind the runner.

**Depends on**  Tasks 04, 09, 22, and 25.

**Create / modify**  RunIntroController, selected-character confirmation pose, Boulevard presentation/runway anchors, camera choreography, and readiness tests.

**Implementation**

1. From `CHARACTER_CONFIRMED`, push the camera toward the selected character with shared blur/FOV treatment, hold a readable front view, and reveal Boulevard behind them.
2. Prepare Boulevard and its safe initial runway through ScenarioManager while RunnerController stays disabled and RunStats time does not advance.
3. Move the camera around to the normal behind-runner profile, wait for the camera and scenario readiness barriers, then signal GameFlow to enter `RUNNING`.
4. Enable gameplay input, forward movement, generation, and timer only after `RUNNING`; keep all choreography outside RunnerController.
5. Use the same route after retry YES, without replaying the island/logo/carousel sequence.

**Validation**  Prove no runner movement, generator hazard, swipe action, or timer progress occurs early; verify character/Boulevard continuity, camera settle barrier, one-time enable ordering, retry path, interruption cleanup, supported aspects, and DevHarness shortcuts.

**Acceptance**  Meet all Task 26 criteria; the first active frame is a ready, safe Boulevard run viewed from the normal gameplay camera.

**Do not implement yet**  Final cinematic polish, custom per-character mechanics, or gameplay-camera logic inside the runner.

**Handoff state**  Continuous frontend-to-gameplay handoff with deterministic activation timing.

### Task 27 — Final HUD Behavior

**Goal**  Bind functional HUD content and finalize responsive behavior.

**Depends on**  Tasks 02, 07, 18, 20, and 26.

**Create / modify**  HUD presenters, placeholder loops, coordinate profile/generator, final layout tests.

**Implementation**

1. Bind read-only RunStats score/time and GameFlow pause request.
2. Add square placeholder band loop and scenario-selected decorative loop.
3. Generate decorative scenario-range X/Y/Z values, never real player transforms.
4. Enforce FULL all, MEDIUM hides scenario and conditionally coordinates, COMPACT hides both; score/time/pause always remain.
5. Keep gameplay profiles separate from pause-overlay reflow. While paused, Score, Time, four portraits, `SFX LEVEL`, `MUSIC LEVEL`, and `BACK` never disappear; optional gameplay cosmetics may hide.
6. Keep gameplay HUD hidden throughout the frontend and `RUN_INTRO`; reveal it atomically when GameFlow enters `RUNNING`.
7. Recompute safely after viewport/safe-area changes without recreating frontend or gameplay.

**Validation**  Inspect profile and pause layouts at representative sizes, live resize, safe insets, touch targets, mandatory pause-control accessibility, frontend/Run Intro visibility gating, and corridor readability.

**Acceptance**  Meet all Task 27 and responsive UI specification criteria.

**Do not implement yet**  Final HUD art, orientation-only layouts, or separate HUD scenes.

**Handoff state**  One fully functional adaptive HUD coordinated with the completed frontend handoff.

### Task 28 — itch.io Web Hardening

**Goal**  Produce, package, upload, and validate the full Compatibility-rendered MVP on itch.io.

**Depends on**  Tasks 00–27.

**Create / modify**  Final Web preset/bootstrap, itch.io ZIP packaging/validation script or checklist, frontend/gameplay performance cleanup, hosted-browser checklist, production dev exclusion.

**Implementation**

1. Configure a single-threaded production Web export named `index.html`; DevHarness and fixtures must be unreachable in production flow. Do not require `SharedArrayBuffer`, GDExtension support, PWA header workarounds, or cross-origin isolation.
2. Keep generated companion filenames unchanged and all references relative with exact case. Audit the archive against itch.io's current limits: at most 1,000 extracted files, 500 MB total, 200 MB per file, and 240 characters per full path.
3. Package the contents of `build/web/` at the ZIP root so `index.html` is not nested under a parent directory.
4. Configure the itch.io project as an HTML Game: desktop 960 × 720 embed, click-to-play enabled, scrollbars disabled, and the itch.io fullscreen overlay disabled by default to avoid the bottom-right pause button. Enable Mobile Friendly only after mobile acceptance passes; mobile will launch into a dynamic fullscreen viewport.
5. Handle iframe focus, browser tab suspension/resume, touch cancellation, safe areas, live resize/orientation, and post-gesture audio startup/resume without advancing the frontend twice or corrupting run state.
6. Profile the continuous frontend as well as long scenario cycles. Bound scene-group residency, blur samples, texture/material counts, pool sizes, and transient allocations; verify the low-quality/fallback transition paths on mobile-class devices.
7. Test locally over HTTP, then upload to an itch.io draft/restricted page and retest logged out/incognito on desktop and real or emulated mobile.
8. Complete the hosted path from loading through island, logo, carousel, Run Intro, all nine scenarios/transitions, failure, retry, and return to island.

**Validation**

```powershell
New-Item -ItemType Directory -Force build/web
godot --headless --path . --export-release "Web" build/web/index.html
New-Item -ItemType Directory -Force build/itch
Compress-Archive -Path build/web/* -DestinationPath build/itch/californication-web.zip -Force
```

Verify `index.html` is at the archive root, inspect file/path/size limits, serve the unpacked build locally, and inspect the browser console. Upload the same ZIP to an itch.io draft/restricted page and repeat desktop iframe, mobile fullscreen, keyboard, touch, focus/resume, audio, continuous-frontend, fallback-effect, and full-flow acceptance there.

**Acceptance**  Meet all Task 28 and Global Definition of Done criteria, including a clean hosted run on itch.io with no missing-file, case, absolute-path, mixed-content, or cross-origin-isolation error.

**Do not implement yet**  Final art, unsupported renderer features, unrequested mechanics/deployment.

**Handoff state**  Production itch.io HTML5 ZIP and verified project-page configuration for the complete graybox MVP.

## 6. Scenario Implementation Matrix

| Scenario | Normal mode / track | Scripted transition cinematic | Transition input | Specific components | Shared dependencies |
|---|---|---|---|---|---|
| Boulevard | RUN / sidewalk | Curbside trash-can jump/fall | Locked | Sidewalk/curb dressing | RUN, generator, token, cinematic base |
| Sierra Nevada | SNOWBOARD / snow path | Fall onto train, tunnel, jump away | Locked | Snowboard profile, train staging | Strategies, lanes, pools |
| San Francisco Bay | SWIM / underwater | Surface, shark-wave, launch | Locked | Depth profile, wave route | Vertical states, cinematic base |
| Sequoia | RUN / forest | Mining-cart cave route | Locked | Timed patterns, authored cart route | RUN, moving obstacles |
| Filming Sets | RUN / backlot | Ordered set traversal and exit | Locked | Stage sequencer | Cinematic stage interface |
| Golden Gate | CAR / traffic bridge | Leave car, snowboard cable, launch | Locked | Car mount, cable sequence | Runner, ramps, cinematic base |
| Hollywood | FLY / aerial corridor | Aerial-screw craft and descent | Locked | Flight volume, aerial sequence | Vertical states, 3D collision |
| Grass | RUN / tall-grass trail | Giant jump | Locked | Readability constraints | RUN, camera, cinematic base |
| Earthquake | RUN / damaged street | Car/ramp/donut/midair exit | Locked | Timed hazards/stages | Obstacles, validator, cinematic base |

## 7. Movement Mode Plan

`RunnerController` is the only gameplay player body. It owns collision, lane, common state, forward progress/speed, invulnerability, cosmetic mount, and mode installation. A mode receives intent and uses protected runner movement operations while reporting capabilities: supported intents, lane-change time, posture/vertical states, jump/gap capability, transition durations, and bounds.

- RUN: lane change, jump, slide.
- SNOWBOARD: looser carve, jump, crouch.
- SWIM: lane change plus temporary rise/dive and neutral return.
- CAR: traffic lane change plus declared ramp actions; Down is not survival-critical.
- FLY: lane and temporary altitude changes with neutral return.

All mode tuning is data-driven. Mode switch always exits/cleans the old strategy before installing/resetting the new one.

`SCENARIO_TRANSITION` is a GameFlow state, not a movement mode. It locks gameplay input and runs a scripted cinematic through the shared transition controller without installing a new movement strategy.

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
4. Collecting the token atomically locks gameplay input, stops runner motion, grants invulnerability before collision processing, suspends generation, clears unsafe queued content, and enters `SCENARIO_TRANSITION`.
5. RunStats awards the configurable default `+1000` bonus exactly once on collection, and shared UI displays centered `BONUS` throughout the cinematic.
6. The configured scripted real-time 3D cinematic receives runner/character-presentation and camera context only. It advances automatically with no lanes, gameplay input, collectibles, obstacles, or failure.
7. ScenarioManager tears down the source, selects/loads the target, installs mode/profile/camera/HUD, and prepares a safe runway. GameFlow then resumes `RUNNING`, hides `BONUS`, unlocks input, and removes invulnerability.

Each scenario contributes a data-selected cinematic scene/controller. It cannot award score, accept gameplay choices, or bypass shared selection, lifecycle, and cleanup logic.

## 10. Responsive UI Implementation Plan

- Root `Control` contains pillarbox background and game frame.
- Desktop uses a centered 960×720 logical 4:3 `SubViewport` in `AspectRatioContainer`; the itch.io desktop embed is configured to the same 960 × 720 size.
- Mobile-flex uses the safe usable rectangle; automatic frame mode uses touch/mobile capability plus actual space, with development override. itch.io mobile launches are click-to-play and use a dynamic fullscreen viewport.
- The continuous 3D frontend uses the same safe game frame. Camera-safe guides preserve the California silhouette, logo/circular lettering, center character, side panels, `PLAYER SELECT`, stats, and visible arrow hitboxes across desktop and mobile-flex compositions.
- Frontend cameras may crop decorative vegetation, peripheral lettering, and side-panel depth before cropping the active character, title, or arrow controls. Safe-area changes trigger recomposition without restarting the current frontend stage or replaying an input.
- FULL/MEDIUM/COMPACT selection is fit-based. Orientation can trigger recalculation but never determine density alone.
- Use one HUD tree and containers/anchors. Hidden controls reserve no space.
- FULL shows all; MEDIUM hides scenario loop and keeps coordinates only if comfortable; COMPACT hides coordinates and scenario loop.
- Score, timer, pause never disappear; band square is final cosmetic removal. Pause hitbox is at least 56×56 logical pixels.
- Convert safe rect into game-frame coordinates. Consumed GUI touches never become swipes. Keep itch.io's optional bottom-right fullscreen overlay disabled by default so it cannot cover the pause control; if enabled later, add a hosting-overlay safe inset first.
- The pause HUD overlays frozen gameplay and reflows separately from FULL/MEDIUM/COMPACT. Score, Time, all four face portraits, `SFX LEVEL`, `MUSIC LEVEL`, and `BACK` are mandatory at every supported safe size; optional Scenario/Coordinates/Band panels may hide.
- Pause portraits form a vertical column below upper-right Score/Time where space permits and may reflow without hiding any portrait. Faces have no labels/cards/stats; only the focused face receives a rounded green/yellow outline.
- Keyboard/gamepad focus follows the specified portrait/audio/`BACK` paths, touch activates controls directly, and all pause GUI events suppress gameplay gestures.
- Camera profiles may raise/pull back on narrow aspects to preserve three-lane readability. Spawn/validation uses path distance, not camera frame entry.

## 11. DevHarness and Testing Strategy

`DevHarness.tscn` hosts production services behind debug controls, never copies gameplay behavior.

| Task availability | Harness controls |
|---|---|
| 04 | RUN selection and speed |
| 05 | Every obstacle and collision visibility |
| 07 | Collectible patterns and RunStats |
| 08 | Ready/token/death/invulnerability, one-shot bonus inspection, and fixture cinematic skip/completion |
| 09–17 | Implemented scenario/transition selection |
| 10–15 | Implemented movement-mode selection |
| 18 | Sequential/random all-nine cycling and cleanup counters |
| 19–21 | Character, pause, failure family |
| 22 | Cinematic effect quality/fallback controls and cleanup guard |
| 23 | Island intro/attract direct entry, replay, and stage skip |
| 24 | Logo reveal/alicorn direct entry and scene-swap inspection |
| 25 | Carousel character/detent, rotation speed, queued-step, and stat-animation controls |
| 26 | Run Intro direct entry, camera-step inspection, and readiness barriers |
| 27 | Forced HUD profile/safe-area preview |

Display GameFlow state, frontend stage, carousel detent/lock/queue, scenario, mode, speed, legal-state mask, pools, invulnerability, input-lock state, score, and time. CLI suites cover deterministic contracts/solvability/lifecycle; rendered harness checks cover feel, visibility, touch, collisions, pause reflow, frontend choreography, and cinematic presentation.

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
- Keep only the frontend scene groups required for the current/next choreography beat active. Use authored group swaps and simple LODs to imply island-scale travel without holding every close, city, landscape, and island asset at full detail simultaneously.
- Bound screen-texture blur samples, use the low-quality profile on mobile-class paths, and fall back to FOV/overlay fades rather than making the frontend dependent on an expensive effect.
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

Session-only: selected character, `intro_seen`, current discrete SFX/Music values, and development overrides. `intro_seen` skips the one-shot island pullback after return/exit but does not bypass the indefinite island attract stage. `SaveManager` remains a skeleton until a persistence requirement is approved.

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
| Frontend scale/performance | Use authored scene-group/LOD swaps, stable real-world placeholder proportions, bounded effect quality, and mobile fallback instead of a literal world-scale continuous camera path. |
| Frontend continuity seams | Hide deterministic swaps in the blue ocean/sky frame or full-screen effect and test camera/color/motion continuity frame by frame. |
| Carousel race/input leakage | State-owned input gates, exact detents, rotation lock, one bounded queued step, and consumed entry/confirm events. |
| Gameplay starts during Run Intro | Require scenario-ready plus camera-settled barriers before `RUNNING`; runner/generator/timer remain disabled before that state. |
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
| 10 | Sierra/SNOWBOARD | 08–09 | Train cinematic passes |
| 11 | Bay/SWIM | 08, 10 | Swim/cinematic checks pass |
| 12 | Sequoia | 08–11 | Cart cinematic passes |
| 13 | Filming Sets | 12 | Ordered stages pass |
| 14 | Golden Gate/CAR | 08, 13 | Traffic/cable checks pass |
| 15 | Hollywood/FLY | 08, 11, 14 | 3D aerial checks pass |
| 16 | Grass | 15 | Readability/jump passes |
| 17 | Earthquake | 16 | Dynamic/cinematic checks pass |
| 18 | Lifecycle hardening | 09–17 | Repeated cycles pass |
| 19 | Character data/presentation | 03–04, 18 | Cosmetic and decorative-only invariants pass |
| 20 | Pause/settings | 18–19 | Exact freeze/resume passes |
| 21 | Failure/game over | 03, 18, 20 | Both families converge |
| 22 | CinematicTransitionFX | 02–03 | Quality/fallback/cleanup checks pass |
| 23 | Loading/island intro/attract | 03, 22 | One-shot pullback and indefinite attract pass |
| 24 | Logo/alicorn/select entry | 23 | Continuous reveal reaches carousel detent |
| 25 | 3D logo carousel/select | 19, 24 | Detents, arrows, queue, and decorative stats pass |
| 26 | Character confirmation/Run Intro | 04, 09, 22, 25 | Gameplay enables only after camera settles |
| 27 | Functional HUD | 02, 07, 18, 20, 26 | All profiles and state gates pass |
| 28 | itch.io Web release | 00–27 | Uploaded desktop/mobile browser matrix passes |

Assumptions and defaults:

- Existing gameplay-feel values remain configurable defaults, never hard-coded permanence.
- Placeholder/reference art never determines mechanics.
- Development fixtures remain under `res://dev/` and are excluded from production registration.
- itch.io is the production Web host; release artifacts use a root-level `index.html`, relative exact-case paths, and Godot's single-threaded Web export.
- `TASK_STATUS.md` remains unchanged when this plan is added and is updated only after numbered task acceptance.
- A task never begins adjacent task work merely to prove itself.
