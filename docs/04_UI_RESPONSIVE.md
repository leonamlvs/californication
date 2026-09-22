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

On itch.io mobile pages, launch is click-to-play and uses the device's dynamic fullscreen viewport regardless of the desktop embed dimensions. Mark the itch.io page as Mobile Friendly only after Task 24 verifies resize, safe areas, touch input, and performance on mobile browsers.

HUD chooses the richest profile that fits without:
- overlapping important gameplay;
- making text too small;
- shrinking cosmetic panels into useless thumbnails.

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
- Gameplay corridor remains unobstructed by cosmetic UI.
- The itch.io desktop iframe, mobile fullscreen launch, and live resize paths select valid layouts without obscuring pause or corrupting run state.
