# Asset Contract

## MVP art philosophy

Use primitive 3D meshes and simple materials.

The MVP proves:
- movement;
- gameplay;
- transitions;
- responsive presentation;
- browser behavior.

It does not prove final art style.

## itch.io package budget

The HTML5 build is distributed as an itch.io ZIP. The extracted archive must remain within itch.io's current limits: at most 1,000 files, 500 MB total, 200 MB for any single file, and 240 characters for any full path. These are upload ceilings, not target budgets.

Prefer shared materials, consolidated reusable resources, short paths and names, and a small startup payload. Avoid creating hundreds of one-off placeholder files when a parameterized scene/resource can serve the same purpose. Preserve exact filename case so Windows development does not hide failures that will occur on itch.io's case-sensitive hosting.

## Replaceability

Gameplay systems must not reference assets by visual meaning.

Example:

Bad:
```text
if collided_object.name == "Bench":
```

Good:
```text
obstacle.obstacle_class == BLOCK
```

A bench, boulder, parked car, studio camera or underwater rock may all later reuse `BLOCK`.

## Placeholder obstacle assets

Create one graybox asset per class:

```text
BLOCK      tall prism
HURDLE    low barrier
OVERHEAD  overhead U-frame
CROSSER   moving capsule
SWEEPER   pivoting beam
GAP       missing track region
GATE      blockers leaving safe opening
```

Use simple materials/colors for debugging only.

Never make mechanic recognition depend only on color.

## Placeholder characters

Create simple humanoid placeholders for four selectable characters.

All use:
- same root scale;
- same collision;
- same movement controller;
- same animation interface.

Character differences are cosmetic.

## Placeholder Transition Token

Final appearance intentionally undefined.

MVP token needs only:
- obvious difference from normal collectible;
- clear silhouette at speed;
- simple glow/animation;
- collision trigger.

Do not spend time polishing it.

## Final 3D asset contract

Use this convention unless deliberately revised later:

```text
Up: +Y
Forward: -Z
Scale: 1 Godot unit = 1 meter
Character origin: ground point between feet
Vehicle origin: centered near ground contact
Environment origin: modular snap/reference point
Preferred interchange format: GLB/glTF
Animation target: 30 fps unless a different rate is required
```

Character assets should share one humanoid skeleton where practical.

Keep:
- low material count;
- reusable textures;
- simple shaders;
- low-poly silhouette-first modeling.

## Naming examples

```text
chr_character_01.glb
chr_character_02.glb

obs_block_placeholder.tscn
obs_hurdle_placeholder.tscn

env_boulevard_segment_a.tscn
env_bay_segment_a.tscn

pup_transition_placeholder.tscn
col_collectible_placeholder.tscn
```

## Final-art direction later

Target:
- fully 3D;
- Dreamcast / PS2-era visual language;
- simple geometry;
- low-to-medium resolution textures;
- restrained lighting;
- deliberate fog;
- no forced PS1 pixelation;
- no modern glossy mobile-game UI.

The art system must allow all RHCP-specific imagery, likenesses, branding and video-inspired assets to be replaced without changing mechanics.
