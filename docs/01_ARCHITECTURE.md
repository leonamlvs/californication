# Architecture

## Project structure

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
→ ISLAND_ATTRACT
→ TITLE_CINEMATIC
→ CHARACTER_SELECT
→ RUN_START
→ RUNNING
↔ PAUSED
→ FAILURE_TRANSITION
→ LAVA_GAME_OVER
→ TRY_AGAIN
    YES → RUN_START
    NO  → ISLAND_ATTRACT
```

Transition Tokens temporarily branch from `RUNNING`:

```text
RUNNING
→ TRANSITION_READY
→ TOKEN_COLLECTED
→ TRANSITION_RIDE
→ NEXT_SCENARIO
→ RUNNING
```

`Exit Run` from pause returns to `ISLAND_ATTRACT`.

Changing character during pause is cosmetic only and returns to `PAUSED`.

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
```

All playable characters share:

- collision;
- movement;
- speed;
- mechanics;
- scoring;
- animation interface.

Only presentation changes.

### TransitionDefinition

```text
id
source_scenario
controller_mode
transition_scene
allowed_inputs
next_scenario_policy
```

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
TRANSITION_RIDE
```

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

- scenario selector;
- movement-mode selector;
- speed control;
- spawn each obstacle class;
- spawn collectible pattern;
- force `TRANSITION_READY`;
- spawn Transition Token;
- force death;
- toggle invulnerability;
- collision/debug visualization.

DevHarness must not be required by production flow.
