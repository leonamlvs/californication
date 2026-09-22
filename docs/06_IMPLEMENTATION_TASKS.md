# Implementation Tasks and Acceptance Criteria

Each task must be independently completable and commit-worthy.

Do not begin the next task merely to prove the current task works.

## Global Definition of Done

Every task is incomplete unless:

- `godot` can launch/check the project without GDScript parser errors;
- no new missing resources exist;
- previously completed behavior still works;
- no unrelated system was rewritten;
- new tuning constants are exposed as data/config where appropriate;
- scenario-specific behavior is not hard-coded into the core runner unless it applies globally;
- a direct debug/test path exists;
- the spec/task status is updated.

---

## 00 — Project Foundation

Implement:
- Godot 4.7.2 project structure;
- Compatibility renderer;
- main scene;
- autoload skeletons;
- folders;
- basic web export settings.

Acceptance:
- project opens;
- main scene runs;
- CLI command `godot` can run the project/check scripts;
- no parser errors.

---

## 01 — Input Abstraction

Implement:
- input actions;
- keyboard;
- swipe detection;
- optional gamepad mapping;
- shared gameplay intent events.

Acceptance:
- Left/Right/Up/Down can be triggered from desktop input;
- touch swipes trigger same actions;
- touching UI does not generate gameplay swipe;
- gameplay controller reads input actions/intents, not raw keys.

---

## 02 — Responsive UI Foundation

Implement:
- HUD root;
- FULL / MEDIUM / COMPACT profiles;
- safe area handling;
- desktop centered 4:3 presentation;
- mobile responsive viewport behavior;
- placeholder panels.

Acceptance:
- desktop remains 4:3 and unstretched;
- large viewport shows FULL;
- constrained viewport correctly drops to MEDIUM/COMPACT;
- hidden panels do not reserve empty space;
- score/time/pause never disappear.

---

## 03 — GameFlow State Machine

Implement placeholder screens/states:

```text
BOOT
LOADING
ISLAND_ATTRACT
TITLE_CINEMATIC
CHARACTER_SELECT
RUN_START
RUNNING
PAUSED
FAILURE_TRANSITION
LAVA_GAME_OVER
TRY_AGAIN
```

Acceptance:
- developer can traverse the whole flow using placeholder buttons/inputs;
- YES starts new run state;
- NO returns to island;
- pause/resume state transition works.

---

## 04 — RUN Movement

Implement:
- automatic forward movement;
- three lanes;
- lane change;
- jump;
- slide;
- reusable tuning resource.

Acceptance:
- player cannot occupy invalid lane;
- lane changes feel deterministic;
- jump/slide cannot leave controller in invalid state;
- controller contains no scenario-name branches.

---

## 05 — Seven Obstacle Primitives

Implement:
- BLOCK;
- HURDLE;
- OVERHEAD;
- CROSSER;
- SWEEPER;
- GAP;
- GATE.

Acceptance:
- each class can be spawned independently;
- intended avoidance action succeeds;
- collision causes run failure;
- classes use shared data contract.

---

## 06 — Segment and Pattern Generator

Implement:
- reusable track segments;
- authored pattern library;
- recycling/pooling;
- compatibility filtering;
- solvability/reaction validation.

Acceptance:
- graybox track can run for 10+ minutes;
- no generation holes;
- no invalid movement-mode patterns;
- validated patterns always retain at least one legal survival path.

---

## 07 — Collectibles and Score

Implement:
- normal collectible;
- collectible patterns;
- distance score;
- pickup score;
- run timer;
- reset behavior.

Acceptance:
- patterns work across all three lanes and jump paths;
- score/time reset on new run;
- missed pickup has no penalty;
- time displays HH:MM:SS.

---

## 08 — Transition Framework + DevHarness

Implement:
- `TRANSITION_READY`;
- Transition Token logic;
- immediate invulnerability;
- normal-generator suspension;
- transition controller;
- shuffle bag;
- DevHarness controls.

Acceptance:
- configured timer makes scenario transition-ready;
- safe token opportunity appears;
- missing token produces another opportunity;
- collecting token starts Transition Ride;
- normal gameplay resumes after transition;
- DevHarness can force token/transition/death.

---

## 09 — Boulevard

Implement:
- RUN profile;
- sidewalk-only corridor;
- graybox boundary dressing;
- curbside transition;
- trash-can-style scripted jump/fall.

Acceptance:
- normal movement never requires entering traffic lane;
- transition is invulnerable;
- transition exits cleanly into another registered scenario.

---

## 10 — Sierra Nevada

Implement:
- SNOWBOARD mode;
- snow-path lane behavior;
- train-roof transition;
- tunnel sequence.

Acceptance:
- snowboard uses shared input contract;
- movement feels distinct without a separate standalone controller;
- train has three usable roof positions;
- transition returns cleanly to normal gameplay.

---

## 11 — San Francisco Bay

Implement:
- SWIM mode;
- temporary rise/dive;
- neutral-depth return;
- underwater corridor;
- shark/wave transition.

Acceptance:
- Up/Down reliably return to neutral depth;
- lane changes remain valid while changing depth;
- transition completes without normal obstacle damage.

---

## 12 — Sequoia

Implement:
- RUN scenario profile;
- forest path;
- timed environmental obstacle patterns;
- mining-cart transition.

Acceptance:
- common RUN controller works unchanged;
- mining cart supports three rail positions;
- rail switching is deterministic;
- transition exits correctly.

---

## 13 — Filming Sets

Implement:
- RUN backlot;
- film-set obstacle patterns;
- scripted multi-set transition.

Acceptance:
- transition visits required placeholder set stages in order;
- transition does not create a second player controller;
- exit door hands control back to normal gameplay.

---

## 14 — Golden Gate

Implement:
- CAR mode;
- traffic-lane movement;
- ramp support;
- cable transition.

Acceptance:
- car uses common input interface;
- Down is not required for normal survival;
- cable transition disables normal Left/Right;
- Up/Down work as defined;
- transition ends cleanly.

---

## 15 — Hollywood

Implement:
- FLY mode;
- lateral lanes;
- temporary rise/drop;
- neutral-altitude return;
- aerial-screw transition.

Acceptance:
- fully 3D aerial movement;
- never depends on 2D/2.5D logic;
- player stays inside permitted flight volume;
- all four directional intents work;
- transition hands off cleanly.

---

## 16 — Grass

Implement:
- RUN profile;
- visibility-focused corridor;
- super-jump transition.

Acceptance:
- decorative occlusion never creates unavoidable hazards;
- required obstacles remain readable;
- super-jump transition works without a vehicle controller.

---

## 17 — Earthquake

Implement:
- RUN profile;
- dynamic hazards;
- damaged-road gaps/gates;
- high-speed car transition;
- ramp/donut/ejection placeholder sequence.

Acceptance:
- moving environment respects reaction-time rules;
- transition is invulnerable;
- ramp sequence is authored and deterministic;
- transition completes correctly.

---

## 18 — Scenario Runtime Hardening

Implement:
- all scenario definitions registered;
- shuffle-bag cycling;
- scenario cleanup/unload;
- state reset between visits.

Acceptance:
- DevHarness can cycle all 9 scenarios repeatedly;
- no immediate duplicate scenario;
- no stale obstacles/segments from prior scenario;
- player movement mode always matches current scenario.

---

## 19 — Characters

Implement:
- CharacterDefinition;
- four placeholder characters;
- character selection;
- cosmetic swap during pause.

Acceptance:
- all characters have identical gameplay stats/collision;
- selecting/swapping character does not reset current run unless explicitly starting a new run;
- no scenario behavior depends on character identity.

---

## 20 — Pause and Settings

Implement:
- pause overlay;
- resume;
- master/music/effects volume placeholders;
- character swap;
- exit run to island.

Acceptance:
- gameplay simulation freezes;
- UI remains usable;
- resume restores exact gameplay state;
- exit returns to island;
- character swap is cosmetic.

---

## 21 — Failure and Game Over

Implement two failure-transition families:

1. floor opens / player falls;
2. player is launched/kicked toward screen when floor-fall is inappropriate.

Both lead to:
- lava game-over scene;
- bandmates as placeholders;
- `GAME OVER`;
- `TRY AGAIN? YES / NO`.

Acceptance:
- scenario chooses valid failure-transition family;
- both converge on same Game Over logic;
- YES creates a fresh run;
- NO returns to island.

---

## 22 — Intro Presentation

Implement placeholders for:
- music-video-style loading screen;
- rotating island attract screen;
- title transition;
- RHCP/logo-title placeholder;
- flying alicorn placeholder;
- character select entry.

Acceptance:
- first-session sequence occurs in correct order;
- island waits indefinitely for input;
- keyboard/touch can continue;
- returning from a run does not require replaying the full intro unless configured.

---

## 23 — Final HUD Behavior

Implement functional:
- band-loop placeholder;
- coordinate generator;
- scenario-loop placeholder;
- score;
- time;
- pause;
- profile switching.

Acceptance:
- FULL layout matches agreed hierarchy;
- MEDIUM removes scenario panel;
- COMPACT removes coordinates and scenario panel;
- band square remains where space allows;
- viewport resizing selects highest fitting profile;
- gameplay corridor remains readable.

---

## 24 — Web Hardening

Implement:
- production web export;
- itch.io upload ZIP with `index.html` at archive root;
- single-threaded export without a `SharedArrayBuffer`/cross-origin-isolation dependency;
- relative-path and case-sensitivity audit;
- itch.io desktop embed and mobile-fullscreen configuration;
- browser startup;
- touch testing;
- resize/orientation handling;
- browser focus loss/resume and audio-unlock handling;
- performance cleanup;
- production exclusion/disablement of DevHarness.

Acceptance:
- web build starts successfully;
- the ZIP satisfies itch.io file-count, path-length, total-size and per-file limits;
- an uploaded itch.io draft/restricted page starts without missing-file, case, path, or cross-origin errors;
- desktop keyboard works;
- touch swipes work;
- pause works;
- resize/orientation changes do not corrupt game state;
- itch.io's 960 × 720 desktop embed preserves centered 4:3 presentation;
- itch.io mobile fullscreen launch selects a valid responsive HUD and safe area;
- leaving and returning to the browser tab does not advance simulation or corrupt state;
- audio begins only after a valid user gesture and resumes correctly after focus changes;
- all nine scenarios can be reached;
- full fail/retry/island flow works in browser;
- no feature depends on non-Compatibility rendering.
