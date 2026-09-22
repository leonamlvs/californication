# Architecture

## Project structure

### Implemented foundation after Tasks 00–01

- `project.godot` targets Godot 4.7 Compatibility at a 960×720 reference viewport and registers `GameFlow`, `ScenarioManager`, `InputRouter`, `AudioManager`, and `SaveManager` autoloads.
- `main/Main.tscn` is intentionally still a passive graybox composition with `World`, `FrontendLayer`, and `OverlayLayer`; it contains no frontend state implementation yet.
- `export_presets.cfg` provides a preliminary single-threaded Web preset at `build/web/index.html`, excludes `ref/` and `build/`, disables extension/PWA dependencies, and lets the canvas follow its host viewport. Final itch.io packaging remains Task 28.
- `InputRouter` emits StringName intents for left/right/up/down/pause/confirm/back, normalizes keyboard and runtime-registered conventional gamepad input, recognizes one-finger unhandled swipes at a configurable 6% threshold, and cancels gestures on GUI consumption, multi-touch, resize, or focus loss.
- `dev/InputHarness.tscn` demonstrates intent output and GUI swipe exclusion. `tests/cli/TestRunner.gd` contains the completed Task 00/01 deterministic checks.

The new frontend requirements build on these boundaries. They require no Task 00/01 rewrite: frontend touch-to-confirm and arrow taps are state-owned GUI/frontend actions, carousel input gating belongs to its controller, and run/cinematic input locking belongs to the consuming state rather than a second device-input system.

Recommended structure:

```text
res://
  autoload/
    GameFlow.gd
    ScenarioManager.gd
    AudioManager.gd
    SaveManager.gd

  data/
    scenarios/
    characters/
    obstacles/
    transitions/
    camera_profiles/

  gameplay/
    runner/
    track/
    obstacles/
    collectibles/
    transitions/

  frontend/
    island/
    logo_reveal/
    player_select/
    run_intro/

  presentation/
    cinematic_fx/

  scenarios/
    boulevard/
    sierra_nevada/
    san_francisco_bay/
    sequoia/
    filming_sets/
    golden_gate/
    hollywood/
    grass/
    earthquake/

  ui/
    hud/
    menus/
    pause/
    game_over/

  dev/
    DevHarness.tscn

  art/
    characters/
    environments/
    obstacles/
    pickups/
    ui/
    vfx/

  audio/
```

## Game flow

Single authoritative state machine:

```text
BOOT
→ LOADING
→ ISLAND_INTRO
→ ISLAND_ATTRACT
→ LOGO_REVEAL
→ CHARACTER_SELECT_ENTER
→ CHARACTER_SELECT_ACTIVE
→ CHARACTER_CONFIRMED
→ RUN_INTRO
→ RUNNING
↔ PAUSED
→ FAILURE_TRANSITION
→ LAVA_GAME_OVER
→ TRY_AGAIN
    YES → RUN_INTRO
    NO  → ISLAND_ATTRACT
```

The earlier planning names map as follows: `TITLE_CINEMATIC` becomes the more precise `LOGO_REVEAL`; `CHARACTER_SELECT` is split into enter/active/confirmed stages; and the former `RUN_START` bootstrap occurs beneath `CHARACTER_CONFIRMED → RUN_INTRO`. Task 03 has not implemented these states yet, so it should use the precise names directly rather than add compatibility aliases.

The frontend stages form one visually continuous real-time 3D sequence, even when scene groups change internally. They are not unrelated menus joined by generic hard cuts.

Transition Tokens temporarily branch from `RUNNING`:

```text
RUNNING
→ TRANSITION_READY
→ TOKEN_COLLECTED
→ SCENARIO_TRANSITION
→ NEXT_SCENARIO
→ RUNNING
```

`Exit Run` from pause returns to `ISLAND_ATTRACT`.

Changing character during pause is an immediate cosmetic swap within the pause HUD. It never leaves `PAUSED`, resets no run state, and moves focus directly to `BACK` after selection.

## Frontend presentation ownership

- `GameFlow` authorizes every frontend state transition but does not contain camera choreography.
- `FrontendCoordinator` mounts/unmounts frontend scene groups and preserves visual continuity across hidden handoffs.
- `IslandIntroController` owns the one-shot vegetation-to-island pullback. It may use staged geometry/LOD group swaps, camera/FOV changes, and transition blur; it never repeats while the attract state waits.
- `IslandAttractController` owns slow indefinite island rotation and accepts confirm from keyboard/gamepad or any ordinary screen touch. A consumed touch advances only once and cannot leak into the next state.
- `LogoRevealController` owns island departure, the blue sky/ocean handoff, logo/letter assembly, alicorn approach/pass, and rotation of the same logo into the Player Select angle.
- `LogoCarouselController` owns four indexed logo detents. Left/Right or the visible arrow Controls request one detent rotation. Character display panels are presentation surfaces, not clickable character choices. Rotation locks input or safely queues a bounded request until the next detent is exact.
- `PlayerSelectPresenter` owns name/category/stat display, stat reset/count-up animation, selection idle presentation, and confirm request. Decorative stats never enter gameplay configuration.
- `RunIntroController` owns the selected-character push-in, brief front hold, Boulevard reveal, camera orbit/past movement, third-person camera settlement, and seamless presentation-to-runner handoff. It alone authorizes runner input and timer start after settlement; none of this choreography belongs in `RunnerController`.
- `CinematicTransitionFX` is a reusable short-lived presentation component for radial/zoom blur, FOV kick, and fade. It is disabled outside authored transitions and provides a cheap no-screen-sampling fallback.

An internal handoff from `IslandFrontend` to `LogoCharacterSelectFrontend` is allowed during the mostly blue sky/ocean frame, but the user must not perceive a loading cut. If frontend and gameplay use separate character instances, `CharacterPresenter` preserves the same definition and matched pose/transform across the `RUN_INTRO` handoff.

## Run restart

`TRY AGAIN = YES` means:

- same selected character;
- score reset;
- run timer reset;
- new run starts immediately;
- starts from Boulevard for the MVP;
- does not respawn where the player crashed.

## Scenario management

Normal run start:

```text
Boulevard
```

After Boulevard, use a shuffle bag containing:

```text
Sierra Nevada
San Francisco Bay
Sequoia
Filming Sets
Golden Gate
Hollywood
Grass
Earthquake
```

Consume every item once before refilling.

On refill, never allow the current scenario to immediately repeat.

Expose a setting later so forced Boulevard opening can be disabled.

## Data-driven contracts

### ScenarioDefinition

Must contain at least:

```text
id
display_name
movement_mode
base_speed
max_speed
lane_spacing
segment_library
obstacle_library
collectible_patterns
environment_scene
camera_profile
hud_coordinate_profile
transition_definition
minimum_transition_time
guaranteed_transition_time
```

Scenario-specific code must be isolated. Do not add `if scenario == ...` chains inside the core runner.

### ObstacleDefinition

```text
id
obstacle_class
allowed_movement_modes
occupied_lanes
movement_pattern
collision_profile
minimum_reaction_time
scene
```

### CharacterDefinition

```text
id
display_name
mesh_scene
portrait
optional_skin_data
instrument_category
decorative_category_value
decorative_strength
decorative_stamina
decorative_agility
decorative_charisma
decorative_rhythm
frontend_presentation_scene
idle_animation_key
```

All playable characters share:

- collision;
- movement;
- speed;
- mechanics;
- scoring;
- animation interface.

Only presentation changes.

The instrument/category label is character-configured (for example VOCALS, GUITAR, BASS, or DRUMS). All six displayed values are decorative Player Select data: the category value plus five common stats. Validation may reject missing presentation references, but runner, scenario, scoring, obstacle, and transition systems cannot read these fields.

### CinematicFXProfile

```text
radial_blur_strength
radial_blur_center
sample_quality
fov_kick
fade_amount
duration
mobile_sample_quality
fallback_policy
```

The preferred implementation is a Compatibility-compatible fullscreen CanvasItem/ColorRect-style shader using screen-texture sampling. Exact Godot 4.7.2 shader syntax and APIs must be verified when its task begins. The fallback combines camera/FOV motion and a lightweight overlay when screen sampling is unsupported or too expensive.

### TransitionDefinition

```text
id
source_scenario
transition_scene
next_scenario_policy
optional_camera_profile
transition_bonus_score = 1000
```

The transition scene implements a shared scripted-cinematic contract. It receives the existing runner/selected-character presentation and camera context, plays in real time without player control, and emits completion. It cannot select the next scenario, award its own score, or enable gameplay collision/failure.

## Runner architecture

Use one `RunnerController`.

It delegates movement behavior to a movement-mode component/state.

Required public intent interface:

```text
request_left()
request_right()
request_up()
request_down()
set_movement_mode(mode)
```

Keyboard, gamepad and touch all feed the same input actions.

Gameplay code must never check raw keyboard keys directly.

## Required movement modes

```text
RUN
SNOWBOARD
SWIM
CAR
FLY
```

`SCENARIO_TRANSITION` is a `GameFlow` state, not a movement mode. No transition installs a second controller or interprets directional gameplay input.

## Scenario-transition ownership

- `TransitionCoordinator` owns readiness, safe token opportunities, missed-token retry, one-shot bonus award, the centered `BONUS` overlay, generator suspension, cinematic lifecycle, and protected handoff. The shared overlay reads `BONUS`; it does not render a large `BONUS +1000!` message.
- Token collection synchronously stops runner control, locks gameplay input, enables invulnerability, stops normal generation, and awards the configurable transition bonus (default `+1000`) before the cinematic begins.
- `ScenarioTransitionController` exposes `start(context)`, `cancel()`, a development-only completion/skip hook, and a `completed` signal. It exposes no gameplay-intent handler.
- During `SCENARIO_TRANSITION`, obstacles, pickups, player failure, and gameplay choices are disabled. Cinematics are real-time 3D sequences, not pre-rendered video and not playable lanes.
- `ScenarioManager` alone selects and loads the next scenario after the cinematic completes and keeps the runner protected until the target safe runway is ready.

## Pause ownership

Pause is one responsive HUD overlay over frozen gameplay, not a separate pause character-select screen.

- `GameFlow` owns whether gameplay simulation is paused; the pause HUD remains active.
- `CharacterPresenter` applies one of four cosmetic portraits immediately. The selector shows faces only: no names, stats, cards, descriptions, or submenu.
- `AudioManager` exposes player-facing `SFX LEVEL` and `MUSIC LEVEL` controls in roughly ten discrete steps. An internal Master bus may exist, but there is no player-facing Master control.
- The pause HUD owns deterministic keyboard/gamepad focus and touch hit targets; it never mutates score, elapsed time, scenario, runner mechanics, or generator state.

## Browser constraints

Assume Compatibility renderer from the beginning.

The production host is itch.io. Use Godot's single-threaded Web export by default. Do not make the MVP depend on `SharedArrayBuffer`, cross-origin-isolation headers, GDExtensions, or threaded Web APIs. This is the most compatible Godot Web configuration for itch.io and mobile Safari-class browsers.

Avoid gameplay dependencies on:

- Forward+;
- compute shaders;
- expensive post-processing;
- many dynamic lights;
- heavy realtime shadows;
- high material counts.

Pool or recycle:

- track segments;
- obstacles;
- collectibles;
- recurring environment objects.

### itch.io distribution contract

- Export with `index.html` as the entry point and do not rename the generated companion files.
- Package the contents of the Web export directory at the ZIP root; `index.html` must not be hidden inside a parent folder.
- Use relative URLs only. File/path case must match exactly because itch.io hosting is case-sensitive.
- Keep the upload self-contained. Any external request must use HTTPS and must not be required for core gameplay.
- Keep within itch.io's current extracted limits: no more than 1,000 files, 500 MB total, 200 MB per file, and 240 characters per full path. Treat these as ceilings, not performance targets.
- Let Godot's canvas resize with its host window. itch.io mobile launches use a dynamic fullscreen viewport.
- Use click-to-play so startup does not consume resources before consent and so the first in-game confirm/tap can unlock browser audio.
- Validate the final ZIP on an uploaded itch.io draft/restricted page, not only through localhost, including logged-out/incognito desktop and real or emulated mobile runs.

Source: [itch.io HTML5 upload documentation](https://itch.io/docs/creators/html5) and [Godot 4.7 Web export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).

## Development harness

`DevHarness.tscn` must eventually expose:

- frontend shortcuts for `ISLAND_INTRO`, `ISLAND_ATTRACT`, `LOGO_REVEAL`, `CHARACTER_SELECT_ACTIVE`, and `RUN_INTRO`;
- Player Select character/detent and stat-animation inspection;
- cinematic-effect quality/fallback controls;
- scenario selector;
- movement-mode selector;
- speed control;
- spawn each obstacle class;
- spawn collectible pattern;
- force `TRANSITION_READY`;
- spawn Transition Token;
- trigger/skip the scripted scenario transition and inspect the one-shot bonus;
- cycle currently registered scenarios quickly (all nine once Task 18 registers production content);
- force death;
- toggle invulnerability;
- collision/debug visualization.

DevHarness must not be required by production flow.
