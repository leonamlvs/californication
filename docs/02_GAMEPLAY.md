# Gameplay Specification

## Core runner geometry

Initial tuning values; all must be data-driven.

```text
lanes: 3
lane spacing: 1.6 m center-to-center
player capsule radius: ~0.38 m
player standing height: ~1.7 m
starting speed: 10 m/s
initial maximum speed: 16 m/s
lane-change duration: 0.18 s
normal jump height: ~1.4 m
normal jump duration: ~0.72 s
slide duration: ~0.65 s
swim/fly vertical rise: ~1.2 m
swim/fly vertical drop: ~0.9 m
swim/fly return to neutral: ~0.75 s
minimum reaction time: 1.25 s absolute minimum
target reaction time: >= 1.5 s
```

These are starting values only. They must be editable without rewriting controller code.

## Inputs

Actions:

```text
move_left
move_right
move_up
move_down
pause
confirm
back
```

Desktop:
- arrows;
- WASD;
- optional gamepad.

Touch:
- full-screen swipe gestures;
- no virtual D-pad;
- UI areas must not emit gameplay swipes.

Initial minimum swipe distance:
- ~6% of the shorter usable viewport dimension.

## Movement modes

### RUN

- Left/Right: lane change.
- Up: jump.
- Down: slide.
- Automatic forward movement.

### SNOWBOARD

- Left/Right: carve / lane change.
- Up: jump.
- Down: crouch.
- Automatic forward movement.
- Feel may be looser/faster than RUN but uses same input contract.

### SWIM

- Left/Right: lane change.
- Up: rise temporarily, then return to neutral depth.
- Down: dive temporarily, then return to neutral depth.
- Automatic forward movement.

### CAR

- Left/Right: traffic lane change.
- Up: ramp/jump action only where supported.
- Down: no required gameplay action.
- Automatic forward movement.

Do not invent a duck/brake obstacle requirement merely to use Down.

### FLY

- Left/Right: aerial lane change.
- Up: rise temporarily, then settle.
- Down: descend temporarily, then settle.
- Automatic forward movement.

### TRANSITION_RIDE

Input is defined per transition.

Player is invulnerable immediately after Transition Token collection and remains so until normal gameplay resumes.

## Failure

One meaningful obstacle collision ends the run.

No stumble / second-chance mechanic in MVP.

NPC hazards should visually resolve as near-collisions / avoidance / loss of balance rather than treating people or animals as impact targets.

## Obstacle classes

Exactly seven base gameplay classes:

### BLOCK
Required response: leave the lane.

MVP mesh: tall rectangular prism.

### HURDLE
Required response: jump.

MVP mesh: low horizontal barrier.

### OVERHEAD
Required response: slide, dive, or go lower depending on movement mode.

MVP mesh: U-shaped overhead beam.

### CROSSER
Moves across the path. Required response: timing / lane movement.

MVP mesh: moving capsule/dummy.

### SWEEPER
Temporarily sweeps one or more lanes.

MVP mesh: pivoting beam.

### GAP
Missing traversable path.

Required response: jump or scenario-equivalent movement.

### GATE
Multiple lanes visually blocked with at least one safe opening.

MVP mesh: two tall blockers forming a passable lane.

`SEQUENCE` is not an obstacle class. It is an authored combination of obstacle classes.

## Obstacle rules

- Every spawned pattern must be solvable.
- At least one valid player state must survive the immediate future window.
- Validate roughly 2–3 seconds ahead.
- Respect minimum reaction time.
- Patterns must declare allowed movement modes.
- Never spawn required actions unavailable in the current mode.
- Never make final art determine collision behavior.

## Track generation

Use authored procedural generation, not fully random placement.

Build reusable segment/pattern definitions.

A pattern should declare:

```text
id
length
difficulty
minimum_speed
maximum_speed
allowed_movement_modes
minimum_reaction_time
entrance_state
exit_state
obstacle_layout
collectible_layout
```

Randomness chooses compatible valid patterns.

The visual environment may curve or disguise lanes, but the mechanical track remains readable and deterministic.

## Collectibles

Normal collectible: replaceable 3D symbol placeholder for MVP.

Suggested scoring:

```text
distance: 10 points per meter
normal collectible: +100
transition-ride collectible: +100
completed transition: +500
```

Missing a collectible has no penalty.

Required reusable patterns:

```text
STRAIGHT
ARC_UP
ARC_DOWN
LEFT_TO_RIGHT
RIGHT_TO_LEFT
ZIGZAG
JUMP_ARC
LANE_GUIDE
TRANSITION_RIDE_LINE
```

## Transition Token logic

Final appearance is undefined.

Behavior is fixed:

```text
unique from normal collectible
only spawns after scenario becomes transition-ready
approach must be safely reachable
collection immediately grants invulnerability
collection stops normal segment generation
collection starts the scenario transition
```

Initial timing:

```text
minimum scenario time before transition-ready: ~40 s
guaranteed token opportunity by: ~55 s
development override: ~15–20 s
```

If missed, another safe opportunity appears shortly afterward.

## Difficulty

Difficulty should primarily scale through:

- speed;
- pattern complexity;
- crossers/sweepers timing;
- shorter but still legal reaction windows;
- denser collectible paths.

Never increase difficulty by producing impossible layouts.
