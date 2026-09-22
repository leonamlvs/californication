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
