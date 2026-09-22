# Californication Runner — MVP Spec Pack

Working title for a non-commercial fan endless-runner inspired by the *Californication* music video.

## Goal

Build a **feature-complete graybox MVP** in Godot 4.7.2 Stable that already contains the intended game architecture:

- all 9 scenarios;
- all movement modes;
- all 9 scripted scenario-transition cinematics;
- continuous real-time 3D island intro / logo reveal / Player Select / run-intro flow;
- pause / failure / retry flow;
- adaptive browser UI;
- desktop 4:3 presentation;
- responsive mobile/tablet presentation;
- primitive 3D art only.

Final art is intentionally out of scope for the MVP. Every visual asset must be replaceable without changing gameplay logic.

## Technical baseline

- Engine: Godot 4.7.2 Stable
- Language: GDScript
- Renderer: Compatibility
- Target: itch.io HTML5 browser release, desktop and mobile
- Godot CLI command: `godot`
- 3D only. Never design gameplay as 2D or 2.5D.
- Visual target later: Dreamcast / PS2-era 3D, with GTA San Andreas as a useful fidelity reference.
- Gameplay target: readable 3-lane endless runner with a Subway Surfers / Minion Rush feel.

## Core design rule

**Consistent controls, changing world.**

The presentation and movement style may change by scenario, but input remains built around:

- left;
- right;
- up;
- down;
- pause;
- confirm;
- back.

Gameplay logic must not depend on the final art, character identity, obstacle model, or copyrighted content.

Transition Tokens do not begin a playable movement mode. They stop normal gameplay, lock gameplay input, award a configurable `+1000` transition bonus, show a centered `BONUS` overlay, and play the source scenario's non-interactive real-time 3D cinematic before the next scenario begins.

The frontend is also a continuous real-time 3D presentation. A one-shot vegetation-to-island pullback reaches an indefinite rotating-island attract state; after confirmation, an extruded logo and circular lettering reveal an alicorn, the same logo rotates edge-on into the four-position Player Select carousel, and confirming a character flows through a camera-driven `RUN_INTRO` into Boulevard. Reference captures under `ref/start screen transition/` define choreography and composition only, never final assets.

## Documents

1. `01_ARCHITECTURE.md` — systems, state machines, data contracts.
2. `02_GAMEPLAY.md` — runner rules, movement modes, obstacles, scoring, generation.
3. `03_SCENARIOS.md` — all 9 scenarios and their transitions.
4. `04_UI_RESPONSIVE.md` — HUD layout and viewport behavior.
5. `05_ASSETS.md` — placeholder assets and replacement contracts.
6. `06_IMPLEMENTATION_TASKS.md` — ordered tasks with acceptance criteria.
7. `07_IMPLEMENTATION_PLAN.md` — dependency-aware execution plan and handoff contract for Tasks 00–28.

## MVP definition

The MVP is complete when the full game loop and all scenario mechanics work with graybox visuals and the production HTML5 ZIP can be played from an itch.io project page using desktop and touch controls.

Do not add final models, textures, music-video recreations, shaders, or polish before the system they belong to is complete.
