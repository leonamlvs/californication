# UI and Responsive Presentation

## Design intent

The HUD should resemble the music video's game-like layout without sacrificing readability.

Desktop presentation intentionally preserves a 4:3 frame to evoke the source video and PS2-era presentation.

Mobile/tablet presentation uses available screen space instead of forcing desktop 4:3 when that would waste too much display area.

## Desktop viewport

Desktop browser:

- centered 4:3 gameplay presentation;
- do not horizontally stretch;
- wide displays use pillarboxing;
- pillarbox space contains no required gameplay information.

Reference logical composition:
- 960 × 720 or equivalent 4:3.

For the itch.io desktop page, use a 960 × 720 embed with click-to-play and scrollbars disabled. The game still owns the internal 4:3 presentation and pillarboxing. Keep itch.io's optional bottom-right fullscreen overlay disabled by default because it conflicts with the required bottom-right pause control; if that hosting choice changes later, reserve an overlay-safe inset before enabling it.

## Mobile/tablet viewport

Do not classify layout by orientation or device name alone.

Use actual safe usable viewport size.

Gameplay camera may adapt to the available aspect ratio.

On itch.io mobile pages, launch is click-to-play and uses the device's dynamic fullscreen viewport regardless of the desktop embed dimensions. Mark the itch.io page as Mobile Friendly only after Task 28 verifies resize, safe areas, touch input, and performance on mobile browsers.

HUD chooses the richest profile that fits without:
- overlapping important gameplay;
- making text too small;
- shrinking cosmetic panels into useless thumbnails.

## Frontend safe composition

Frontend cinematics use the same desktop 4:3 game frame and mobile safe usable rectangle, but they do not use gameplay HUD density profiles. Each authored camera stage declares a safe composition region for its important subject and overlay controls.

Across every supported aspect ratio:

- the vegetation focal point and island silhouette remain readable during the pullback;
- the rotating island remains fully framed at `ISLAND_ATTRACT`;
- the extruded logo, circular `CALIFORNICATION` letters, and alicorn are not unintentionally cropped;
- the same logo's depth and character-panel faces remain legible during `CHARACTER_SELECT_ENTER`;
- Player Select keeps the front character, name, category/stat labels and values, and both navigation arrows inside the safe region;
- `RUN_INTRO` keeps the selected character's face/body focal area visible until the third-person camera settles.

Camera distance, FOV, subject offsets, and overlay layout may adapt to usable space. State duration, carousel detents, selected character, stat targets, and the moment gameplay unlocks do not vary by aspect ratio. Do not choose composition solely from device name or orientation.

## Frontend interaction and Player Select

The Player Select object is the same extruded 3D logo shown in `LOGO_REVEAL`, viewed more edge-on so its side/depth faces become four character-display panels. It is not a generic red menu rectangle, a card grid, or a separate replacement object.

- Left/Right rotates the entire logo exactly one indexed character position.
- Touch/click activates the visible left/right arrow Controls and follows the same rotation request path.
- Tapping a visible side character panel does not select or rotate to it.
- While rotating, navigation input is locked or at most one bounded request is safely queued; the logo must always settle exactly on a valid detent.
- When a detent becomes front-facing, its idle character becomes active, name/category data updates, all six displayed values reset to `0.0`, and bars/numbers animate to configured decorative targets.
- Confirm is accepted only in `CHARACTER_SELECT_ACTIVE`; it enters `CHARACTER_CONFIRMED` once and suppresses input until `RUN_INTRO` completes.

The full Player Select and pause character selector deliberately share character identity data but not layout or behavior. Full Player Select uses the 3D logo, full-body idle character, name, and decorative stats. Pause uses four face portraits only.

## Cinematic transition effect

`CinematicTransitionFX` supplies short zoom/radial-blur, FOV-kick, and fade cues for the island pullback and `RUN_INTRO`. The preferred path is a Compatibility-compatible fullscreen CanvasItem effect with adjustable sample quality and a reduced mobile sample count. A camera/FOV/overlay fallback must preserve choreography if screen-texture sampling is too expensive or unsupported.

The effect is never active during ordinary frontend waiting, Player Select interaction, or gameplay. Resizing, losing focus, skipping via DevHarness, or leaving a state must restore its neutral values.

## HUD profiles

### FULL

Typical:
- desktop 4:3;
- large tablet / large viewport.

Visible:
- band square;
- coordinates;
- scenario animation panel;
- score;
- timer;
- pause.

Layout:

```text
TOP LEFT
Band square
Coordinates
Scenario panel

TOP RIGHT
Score
Timer

BOTTOM RIGHT
Pause
```

### MEDIUM

Typical:
- landscape phone;
- smaller tablet;
- constrained window.

Visible:
- band square;
- score;
- timer;
- pause;
- coordinates only if they still fit comfortably.

Hidden:
- scenario animation panel.

### COMPACT

Typical:
- small phone / narrow usable viewport.

Visible:
- band square;
- score;
- timer;
- pause.

Hidden:
- coordinates;
- scenario animation panel.

## Priority

Never remove:

1. Score
2. Timer
3. Pause

Identity element:
4. Band panel

Optional flavor:
5. Coordinates
6. Scenario animation panel

When space shrinks, remove optional flavor first.

The band square is the last cosmetic element to remove.

## HUD implementation rules

One HUD tree, not three unrelated HUD scenes.

Suggested structure:

```text
HUD
  BandPanel
  CoordinatePanel
  ScenarioPanel
  ScorePanel
  TimerPanel
  PauseButton
  PauseOverlay
    RunSummary
    CharacterPortraits
    SfxLevel
    MusicLevel
    BackButton
```

Profiles change:
- visibility;
- size constraints;
- anchors/containers;
- margins.

Do not implement mobile by scaling the whole desktop HUD down.

Hidden elements must not reserve layout space.

Do not select profiles using only platform checks such as Android/iOS.

Select based on actual safe viewport dimensions and minimum component sizes.

## Band panel

Square animated panel in upper-left.

MVP:
- placeholder looping animation.

Later:
- replaceable pre-rendered band animation.

## Coordinates

Decorative values only.

Format:

```text
X  -122.481
Y    37.816
Z    14.029
```

Values should vary within scenario-defined ranges.

Not tied to real player transform.

## Scenario panel

Secondary decorative loop whose content depends on scenario.

MVP:
- simple placeholder animation / color-coded loop.

## Score and time

Upper-right.

Score larger than time.

Time format:

```text
HH:MM:SS
```

## Pause

Lower-right.

Visual icon may be small, but touch hit area must be comfortably larger.

Initial target:
- at least ~56 × 56 logical UI pixels.

Must respect safe areas/notches.

## Pause HUD overlay

Pausing freezes gameplay exactly where it is and draws one responsive pause HUD over the frozen view. It is not a separate character-selection screen and does not unload or recreate gameplay.

Required pause content:

- `Score` and `Time` in the upper-right;
- a vertical column of all four face portraits directly below them;
- `SFX LEVEL`;
- `MUSIC LEVEL`;
- `BACK`.

The four pause portraits show faces only. Do not show character names, statistics, cards, descriptions, or a nested character submenu. The focused portrait has only a rounded green/yellow outline. Confirming or tapping a portrait immediately swaps the cosmetic character without changing score, time, movement state, scenario, generator state, or camera, then moves focus directly to `BACK`.

There is no player-facing Master volume control or sound submenu. `SFX LEVEL` and `MUSIC LEVEL` each expose approximately ten discrete settings. The internal audio implementation may still use Master, Music, and SFX buses.

Keyboard/gamepad focus behavior:

- Up/Down moves through the four portraits;
- Confirm on a portrait applies it and focuses `BACK`;
- Left from the character portrait section focuses `SFX LEVEL`;
- audio rows are focusable;
- Confirm enters audio adjustment, Left/Right changes the discrete level, and Confirm exits adjustment;
- ordinary directional navigation between audio rows and `BACK` remains predictable and reversible.

Touch directly activates portraits, audio controls, and `BACK` with no focus-mode prerequisite. Every control consumes its GUI event so it cannot create a gameplay swipe beneath the overlay.

`BACK` resumes from pause. The already-approved Exit Run action remains a separate pause action routed through GameFlow; it is not an audio submenu or a character-selection screen.

## Responsive pause rules

The pause layout reflows from actual safe usable space. All four portraits, both audio controls, Score, Time, and `BACK` are mandatory at every supported size and must retain touch-safe hit areas. On small screens the portrait column and audio controls may move to separate columns/rows or use scrolling only if all four portraits remain immediately discoverable and accessible.

Normal gameplay cosmetics may hide behind the pause HUD in this order: Scenario panel, Coordinates, then Band panel. The gameplay HUD's FULL/MEDIUM/COMPACT profiles remain unchanged; pause reflow is an overlay-specific layout decision and does not create separate gameplay HUD scenes.

## Camera adaptation

Camera presentation is allowed to vary by available aspect ratio, but gameplay fairness must not.

CameraProfile should contain at least:

```text
fov
follow_distance
height
pitch
lateral_look_strength
aspect_adjustment
transition_camera
```

Player and all three lanes must remain readable.

Different aspect ratios must not change reaction time.

Obstacle logic depends on distance along the runner path, not whether an object has entered the camera frame.

## Acceptance rules

- Desktop game remains centered 4:3 and unstretched.
- Large mobile/tablet screens may use FULL HUD when it fits.
- Smaller screens fall back to MEDIUM then COMPACT.
- Layout choice is space-driven.
- Required controls remain touch-safe.
- Pausing preserves the frozen game view and exposes all four portraits, both audio controls, Score, Time, and `BACK` at every supported safe size.
- Pause character selection is immediate and cosmetic-only; keyboard/gamepad focus moves to `BACK` after selection.
- Pause exposes no Master control, character details, cards, or nested character/audio submenu.
- Gameplay corridor remains unobstructed by cosmetic UI.
- Frontend subjects and Player Select controls remain within the safe composition region at desktop, tablet, landscape-phone, and narrow-phone test sizes.
- Player Select arrows remain touch-safe, side panels are not clickable choices, and carousel rotation cannot stop between character positions.
- `RUN_INTRO` cannot enable gameplay input or timer progression before the third-person camera reports settled.
- The itch.io desktop iframe, mobile fullscreen launch, and live resize paths select valid layouts without obscuring pause or corrupting run state.
