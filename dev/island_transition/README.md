# Island transition preview — Task 23.V4

Isolated browser/native video-to-island handoff. **Visual review 2 is pending.** Production integration belongs to V5; running the normal game still shows its existing presentation.

## Run and reproduce

From the repository root:

```powershell
python tools/build_island_transition_preview.py --web
node tools/serve_island_transition.mjs
```

Open http://127.0.0.1:8065/index.html for the interactive preview, or http://127.0.0.1:8065/review/index.html for the recorded review (available after capture). Native preview: `godot --path build/island-transition-preview/project`.

The toolbar offers Pause, Play, Replay, Attract, and Fullscreen. Fullscreen includes the canvas and HTML video. The attract prompt is presentation only here: production continuation/input routing is V5. The preview uses real InputRouter/GameFlow autoloads but does not change GameFlow state. `?capture=1` hides the toolbar.

```powershell
python tools/validate_island_transition.py
node tools/test_island_transition_web.mjs
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/capture_island_transition_review.py
python tools/finalize_island_transition_evidence.py
```

Capture requires the same isolated OpenCV installation described in `../island_scene/README.md`. Run through Blender for its DLL environment. The finalizer requires successful validation and browser results, and preserves compact evidence outside ignored build caches. Building requires Godot and the V1 native preview media; the builder creates that media if absent. Node and Edge are required for browser checks, FFmpeg for the review recording.

## Ownership and timing

- `IslandTransitionPreview.gd` coordinates V1 playback, the unchanged V3 live study, and shared CinematicTransitionFX inside the live SubViewport. Its first two rendered frames warm the scene/effect behind the poster before playback starts.
- `IslandPresentationClock.gd` samples presented media time during video playback, then advances a controller clock from the exact video endpoint. Pauses, buffering, errors, and lost focus hold the complete presentation. The first resumed tick ignores elapsed inactive time. Retry resets both media and presentation clocks, including a previously paused host.
- `IslandHandoffProfile.gd` / `handoff.tres` contain the smoothstep video blend and live blur envelope, referencing the approved V2 camera profile. Video is fully visible through 3.3033 s, blends to zero at 3.470133333 s, and is released after settling at 4.137066667 s. The camera reaches the reveal at 3.737066667 s and retains its settled pose during indefinite rotation.
- `live_blur.tres` sets radial strength 0.22, center (0.5, 0.5), 12 desktop / 4 mobile samples, and softness LOD 3.5. Envelope knots are `(3.3033,.65), (3.4367667,.85), (3.5035,1), (3.6036,.65), (3.7370667,.15), (3.90,0), (4.1370667,0)`.
- `live_soft_blur.gdshader` softens the live screen with mipmap sampling and applies radial blur. The video is never blurred again. The opt-in shader/profile leaves legacy cinematic profiles on their original shader. External sampling passes no camera to shared FX; the live study exclusively owns camera/FOV. See [Godot screen-reading shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) for screen mipmap behavior.
- `preview_controls.js` owns browser focus/visibility listeners and toolbar commands. Exit aborts listeners, cancels FX, and releases video. DOM toolbar focus does not incorrectly pause the canvas presentation.

The common centered 4:3 rectangle drives both video crop and live view across resize/orientation/fullscreen. The approved source is copied byte-for-byte as the external `index.island-intro.mp4`; SHA-256 `3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866`. Native OGV is development-only. Preview source, editable assets, and references remain excluded from production packs.

## Evidence and limits

Final evidence: `docs/evidence/island_intro/v4/`. Eleven CLI/native/package checks and twelve browser checks pass. The recording is a real exported-browser screencast, encoded with original wall-clock frame timing; it is not an offline composite. Autoplay refusal, buffering, and media error cases are injected; tab focus loss is exercised with a real second tab.

The recorded desktop browser used accelerated AMD Radeon RX 7600 rendering. rAF cadence during screencasting is not GPU frame time or target-device performance acceptance. Android/iPhone validation remains V6. Island reconstruction and water remain the approved authored approximations. Explicit user visual approval is required to complete V4; production loading/input/logo boundaries and companion packaging are V5.
