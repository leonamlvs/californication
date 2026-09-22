# Implementation Tasks and Acceptance Criteria

Each task must be independently completable and commit-worthy. Do not begin the next task merely to prove the current task works.

Tasks 00 and 01 are completed. Their implementation has been audited against the current requirements and needs no immediate rewrite. Tasks 02–28 describe future work.

## Global Definition of Done

Every task is incomplete unless:

- `godot` can launch/check the project without GDScript parser errors;
- no new missing resources exist;
- previously completed behavior still works;
- no unrelated system was rewritten;
- new tuning constants are exposed as data/config where appropriate;
- scenario-specific behavior is not hard-coded into the core runner unless it applies globally;
- a direct debug/test path exists;
- relevant desktop/mobile layouts or performance paths are rendered manually when headless checks cannot prove them;
- the spec/task status is updated.

---

## 00 — Project Foundation

Implemented:

- Godot 4.7.2 Compatibility project and 960×720 reference viewport;
- passive main composition with world, frontend, and overlay layers;
- `GameFlow`, `ScenarioManager`, `InputRouter`, `AudioManager`, and `SaveManager` autoload boundaries;
- preliminary single-threaded, resizable Web export preset;
- CLI test runner and required folders/ignore rules.

Acceptance:

- project opens and main scene runs;
- CLI can import/run the project without parser or missing-resource errors;
- Web preset exports toward `build/web/index.html` without threads/extensions/PWA dependencies.

---

## 01 — Input Abstraction

Implemented:

- shared left/right/up/down/pause/confirm/back StringName intents;
- keyboard and conventional runtime gamepad mapping;
- one-finger unhandled swipe recognition using a configurable 6% threshold;
- GUI exclusion, multi-touch cancellation, and resize/focus-loss cancellation;
- development input harness and deterministic CLI checks.

Acceptance:

- desktop, optional gamepad, and touch use the same intent signal;
- UI-consumed touches do not become gameplay swipes;
- gameplay/frontend consumers read intents rather than raw device keys.

Future consumers own state-specific gating: touch-to-confirm, carousel rotation locking, `RUN_INTRO` locking, and scenario-transition locking do not require a second input system.

---

## 02 — Responsive UI Foundation

Implement:

- `PresentationRoot`, desktop 4:3 game frame, mobile-flex frame, and safe usable rectangle;
- one HUD tree with FULL/MEDIUM/COMPACT profiles and placeholder panels;
- a frontend safe-composition region independent of gameplay HUD density;
- layout test scene and debug overrides.

Acceptance:

- desktop remains centered 4:3 and unstretched;
- fit-based FULL/MEDIUM/COMPACT selection works at desktop, tablet, landscape-phone, and narrow-phone sizes;
- hidden panels reserve no space and score/time/pause placeholders never disappear;
- frontend test subjects and arrow placeholders remain inside the safe composition region;
- GUI touch targets cancel InputRouter gestures and pause keeps at least a 56×56 logical hitbox.

---

## 03 — Expanded GameFlow State Foundation

Implement the authoritative placeholder flow:

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
```

Reserve `TRANSITION_READY`, `TOKEN_COLLECTED`, `SCENARIO_TRANSITION`, and `NEXT_SCENARIO` for Task 08.

Acceptance:

- one transition table accepts every legal edge and rejects illegal edges diagnostically;
- placeholder controls can traverse every frontend stage without implementing its final presentation;
- Island Attract waits indefinitely and consumes one confirm/touch without leaking it forward;
- `CHARACTER_CONFIRMED` and `RUN_INTRO` keep gameplay input/timer disabled;
- retry retains selected character, resets the run, targets Boulevard, and enters `RUN_INTRO`;
- Exit Run and retry NO return to `ISLAND_ATTRACT` without replaying `ISLAND_INTRO` in the session;
- only GameFlow changes global state.

---

## 04 — RUN Movement

Implement one shared `CharacterBody3D` runner, automatic logical distance, three lanes, lane change, jump, slide, and resource-driven tuning.

Acceptance:

- lane/state bounds and frame-rate variation are deterministic;
- repeated/opposing input and state reset cannot strand the controller;
- controller contains no scenario-name branches;
- `RunnerController` contains no frontend or `RUN_INTRO` camera choreography.

---

## 05 — Seven Obstacle Primitives

Implement BLOCK, HURDLE, OVERHEAD, CROSSER, SWEEPER, GAP, and GATE through one data-driven obstacle contract.

Acceptance:

- each class spawns independently;
- intended avoidance succeeds and meaningful contact requests failure;
- behavior is independent of mesh identity;
- moving behavior is deterministic enough for future validation.

---

## 06 — Segment and Pattern Generator

Implement reusable track segments, authored pattern resources, pools, compatibility filtering, and future-window solvability/reaction validation.

Acceptance:

- graybox track simulates for 10+ minutes with bounded pools and no holes;
- unsupported-mode and impossible pattern combinations are rejected;
- the active tail plus candidate retains at least one complete legal survival path;
- safe fallback patterns never relax minimum reaction time.

---

## 07 — Collectibles and Score

Implement normal collectibles, required normal-gameplay layouts, distance/pickup score, run timer, pooling, and fresh-run reset.

Acceptance:

- layouts work across lanes and jump paths;
- distance defaults to 10 points/m and pickups to 100 points;
- collection is idempotent and misses have no penalty;
- timer advances only during active run simulation, formats `HH:MM:SS`, and resets only on a fresh run.

---

## 08 — Scenario Transition Framework + DevHarness Base

Implement:

- transition readiness and safe/retried Transition Token opportunities;
- atomic input lock, runner stop, invulnerability, generator suspension, and unsafe-tail cleanup;
- configurable `transition_bonus_score = 1000`, ordinary-score update, and centered `BONUS` overlay;
- shared non-interactive `ScenarioTransitionController` contract;
- shuffle bag and development fixture scenarios;
- production-service DevHarness with state/system shortcuts.

Acceptance:

- minimum/guaranteed timing, safe token placement, and missed-token retry pass deterministically;
- collection awards exactly once and enters `SCENARIO_TRANSITION`, never a movement mode;
- cinematic accepts no gameplay input and has no lanes, collectibles, obstacles, or failure;
- next scenario has a safe runway before control/vulnerability return;
- DevHarness can force ready/token/death, inspect bonus idempotence, skip/complete fixture cinematics, and expose a generic GameFlow state-jump API for later frontend shortcuts.

---

## 09 — Boulevard

Implement the opening RUN sidewalk corridor, Boulevard patterns/camera, and input-locked curbside trash-can jump/fall cinematic.

Acceptance:

- all normal lanes remain on the sidewalk;
- patterns are solvable and never require traffic entry;
- cinematic is invulnerable, non-interactive, and hands off cleanly to a registered fixture/target.

---

## 10 — Sierra Nevada

Implement SNOWBOARD strategy/profile, snow route/patterns, and scripted fall-onto-train/tunnel/jump-away cinematic.

Acceptance:

- snowboard uses the shared runner/input/capability contract;
- normal gameplay filtering matches its capabilities;
- cinematic stage order, input lock, teardown, and handoff pass.

---

## 11 — San Francisco Bay

Implement SWIM, temporary rise/dive with neutral return, underwater volume/patterns, and scripted surface/shark-wave/launch cinematic.

Acceptance:

- repeated/opposing vertical input and simultaneous lane changes remain bounded;
- vertical states participate in pattern validation;
- cinematic has no input, pickups, hazards, or normal damage.

---

## 12 — Sequoia

Implement forest RUN data/patterns and the authored mining-cart cave cinematic.

Acceptance:

- common RUN code remains unchanged;
- cart route is deterministic with no player rail switching;
- cave/cart content unloads before normal play resumes.

---

## 13 — Filming Sets

Implement backlot RUN data and fixed multi-stage cinematic: space/action, non-explicit glamorous/romantic, Da Vinci-style workshop, exit door.

Acceptance:

- stages occur in order using one selected-character presentation context;
- input remains locked and no second player controller is created;
- exit and repeated cleanup are reliable.

---

## 14 — Golden Gate

Implement CAR strategy/profile, traffic/ramp patterns, and scripted leave-car/snowboard-cable/launch cinematic.

Acceptance:

- normal CAR uses the shared runner and never requires Down for survival;
- incompatible crouch/slide patterns are filtered;
- cinematic accepts no Up/Down/Left/Right gameplay control and cleans up fully.

---

## 15 — Hollywood

Implement fully 3D FLY lane/altitude gameplay and scripted aerial-screw craft/descent cinematic.

Acceptance:

- all four directional intents work during normal FLY gameplay only;
- player stays in the 3D flight volume and no 2D/2.5D logic is used;
- cinematic is authored, non-interactive, and hands off cleanly.

---

## 16 — Grass

Implement visibility-focused RUN data, occlusion-safe dressing constraints, and scripted giant-jump cinematic.

Acceptance:

- decoration never hides required hazards inside the reaction envelope;
- camera-profile readability probes pass;
- cinematic requires neither vehicle mode nor gameplay input.

---

## 17 — Earthquake

Implement deterministic dynamic damaged-city hazards and the scripted car/ramp/giant-donut/midair-exit cinematic.

Acceptance:

- dynamic events remain valid at minimum/maximum speeds;
- cinematic is invulnerable, input-locked, deterministic, and fully cleaned up;
- normal RUN is not switched into CAR for the cinematic.

---

## 18 — Scenario Runtime Hardening

Implement all-nine production registration, forced Boulevard opening, eight-scenario post-opening shuffle bag, centralized teardown, visit reset, and all-nine DevHarness cycling.

Acceptance:

- every bag entry is exhausted before refill and refill cannot immediately repeat current scenario;
- repeated all-nine cycles leak no nodes/timers/content and keep pool counts bounded;
- runner mode/profile always matches active scenario;
- fresh run restarts at Boulevard without changing DevHarness cycling policy.

---

## 19 — Character Data and Presentation

Implement:

- four mechanically identical CharacterDefinitions and primitive character scenes;
- display name, instrument/category label and value, decorative STRENGTH/STAMINA/AGILITY/CHARISMA/RHYTHM values;
- frontend presentation scene/idle key and pause face portrait;
- CharacterPresenter selection and pause-safe cosmetic replacement APIs.

Acceptance:

- collision, runner profile, movement, score, difficulty, and scenario behavior are identical for all four;
- decorative stats cannot be consumed by gameplay systems;
- selected identity persists through retry and swaps without resetting the current run;
- presentation/gameplay instances, if separate, can bind the same definition and matched cosmetic identity.

Do not implement the 3D Player Select carousel in this task.

---

## 20 — Pause and Settings

Implement the frozen-game pause HUD, resume/exit, four-face immediate cosmetic selector, and approximately ten-step `SFX LEVEL`/`MUSIC LEVEL` controls.

Acceptance:

- gameplay freezes and resumes exactly;
- all four faces, Score, Time, audio rows, and `BACK` remain accessible/touch-safe at supported sizes;
- pause shows no names, stats, cards, descriptions, character submenu, Sound submenu, or player-facing Master row;
- portrait focus uses only a rounded green/yellow outline;
- Up/Down navigates faces, Confirm swaps then focuses `BACK`, Left from faces reaches `SFX LEVEL`, and Confirm enters/exits Left/Right audio adjustment;
- touch directly activates controls and never leaks a swipe;
- this UI remains distinct from full frontend Player Select.

---

## 21 — Failure and Game Over

Implement data-selected floor-fall and launch-toward-screen failure families, shared lava Game Over, and YES/NO retry flow.

Acceptance:

- both families are one-shot and converge on the same Game Over logic;
- YES retains character, resets run/bag/metrics, targets Boulevard, and enters `RUN_INTRO`;
- NO returns to `ISLAND_ATTRACT` without replaying Island Intro;
- generation/control cleanup and pause/input exclusion pass.

---

## 22 — CinematicTransitionFX

Implement a reusable short-lived cinematic presentation component and data profile for radial/zoom blur, center, sample quality, FOV kick, fade, and duration.

Acceptance:

- exact shader/API choices are verified against Godot 4.7.2 Compatibility before implementation;
- preferred fullscreen CanvasItem/screen-texture effect renders correctly on desktop Web-class Compatibility;
- reduced mobile sample quality is selectable and profiled;
- a camera/FOV/overlay fallback preserves timing when blur is disabled or too expensive;
- completion, cancellation, resize, focus loss, and state exit restore neutral material/camera state;
- effect cannot remain active during Player Select waiting or normal gameplay;
- DevHarness can preview profiles, quality levels, and fallback directly.

---

## 23 — Loading, Island Intro, and Island Attract

Implement:

- loading presentation;
- one-shot close-vegetation → vegetation area → city/roads/vehicles → landscape → California-island pullback;
- fake-scale group/LOD swaps and authored camera/FOV/effect cues;
- slow indefinite rotating-island attract state;
- keyboard/gamepad confirm and any ordinary screen-touch continuation;
- DevHarness shortcuts to Island Intro and Island Attract.

Acceptance:

- intro pullback plays once and never loops at the attract screen;
- island rotates/waits indefinitely without advancing itself;
- touch/confirm advances once without event leakage;
- substitutions are hidden by composition/effect and final asset groups remain replaceable;
- desktop/mobile safe composition keeps the focal subject and island readable;
- leaving the island reaches a mostly blue sky/ocean handoff frame suitable for hidden scene-group loading.

---

## 24 — Logo/Alicorn Reveal and Player Select Entry

Implement:

- visually continuous blue-frame handoff from island frontend;
- extruded red logo and circular 3D `CALIFORNICATION` letters;
- logo/text reveal and 3D rotation;
- alicorn approach, camera pass, and departure;
- continued rotation of the same logo to reveal its depth/character-panel faces;
- camera move into `CHARACTER_SELECT_ENTER` and placeholder active composition;
- DevHarness shortcut to Logo Reveal.

Acceptance:

- no visible loading/hard cut occurs between island departure and logo reveal;
- alicorn approaches from distance, fills/passes the camera, and leaves the logo visible;
- the exact same logo instance/assembly becomes the selector object rather than being swapped for a generic red panel;
- extrusion and panel anchors remain readable across supported safe compositions;
- sequence ends at a stable first carousel detent without implementing full selection behavior.

---

## 25 — 3D Logo Carousel and Decorative Player Select

Implement:

- four indexed character detents on the existing logo object;
- Left/Right and visible touch/click arrow navigation;
- rotation input lock or bounded safe queue;
- full-body idle character, name, category label, and six decorative values;
- values/bars resetting to `0.0` and animating to configured targets on focus;
- confirm into `CHARACTER_CONFIRMED`;
- DevHarness shortcut/detent/stat controls.

Acceptance:

- each request settles exactly one character position with no half-rotated state;
- side character panels are not clickable choices; only arrows/direct intents rotate;
- character name/category/model update only when the new detent is front-facing;
- all stat values visibly reset and count/grow to their CharacterDefinition targets;
- stats remain presentation-only under automated dependency checks;
- keyboard, gamepad, and touch arrows share behavior and remain safe at supported sizes;
- confirm is one-shot and locks further selection input.

---

## 26 — Character Confirmation and Run Intro

Implement the `CHARACTER_CONFIRMED → RUN_INTRO → RUNNING` choreography:

- Player Select UI fades/disappears;
- camera pushes rapidly toward the selected front-facing character using CinematicTransitionFX;
- character fills frame and holds briefly from the front;
- Boulevard resolves behind the same selected identity;
- camera moves around/past the character and settles at the gameplay CameraRig;
- gameplay HUD establishes, effect clears, timer starts, then runner input unlocks;
- DevHarness shortcut to Run Intro and deterministic skip/complete hook.

Acceptance:

- no hard cut or character-identity discontinuity is visible;
- `RunnerController` contains no run-intro choreography;
- input and timer remain disabled until camera settlement is reported;
- separate presentation/gameplay instances, if used, match definition, pose/transform handoff, and appearance;
- resize/focus loss/skip restores a valid settled or safely cancelled state;
- full and fallback effects meet desktop/mobile Web performance budgets.

---

## 27 — Final HUD Behavior

Implement functional band/scenario loops, decorative coordinates, score, time, pause binding, gameplay profiles, and final pause reflow integration.

Acceptance:

- FULL/MEDIUM/COMPACT match the visibility hierarchy and choose the richest fitting profile;
- Score/Time/Pause never disappear during gameplay and the corridor stays readable;
- coordinates use scenario ranges rather than player transform;
- pause preserves its mandatory controls while optional cosmetics may hide;
- live resize/safe-inset changes recreate neither gameplay nor frontend state;
- `RUN_INTRO` establishes the HUD before starting timer/input.

---

## 28 — itch.io Web Hardening

Implement final Compatibility Web export, itch.io ZIP/package audit, hosted project-page configuration/checklist, performance fixes, and production exclusion of DevHarness/fixtures/references.

Acceptance:

- root-level `index.html`, unchanged companion filenames, relative exact-case paths, and itch.io extracted limits pass;
- export remains single-threaded and does not require `SharedArrayBuffer`, cross-origin isolation, GDExtensions, or PWA workarounds;
- uploaded draft/restricted page passes desktop 960×720 embed and mobile fullscreen launch;
- keyboard, touch, safe areas, resize/orientation, focus suspension/resume, and audio unlock/resume work;
- Island Intro through Player Select and Run Intro retain safe composition and acceptable load/frame cost on mobile-class browsers;
- cinematic blur quality/fallback is profiled and no effect remains active in gameplay;
- all nine scenarios/transitions, pause, failure, retry, island return, and frontend shortcuts' production exclusion pass;
- no feature depends on non-Compatibility rendering.
