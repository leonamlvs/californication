# Island video development preview (23.V1)

This isolated project exercises the playback adapter. Production loading and the current island frontend remain unchanged. The live island, ocean, and seamless blend are later milestones.

## Build and preview

From the repository root, with Godot, Python, and FFprobe on PATH:

```powershell
python tools/build_island_video_preview.py --web
node tools/island_video_preview_server.mjs
```

Open `http://127.0.0.1:8063/index.html`. Play, Pause, Replay, Release, and Fullscreen are development controls. Release is terminal; reload the page to create another adapter.

For the native preview, run:

```powershell
godot --path build/island-video-preview/project
```

Use the generated project, which contains its own media and no game autoloads. Opening the template scene in the production project does not generate the OGV.

The builder reads the durable V0 copy and checks its SHA-256. It copies the approved H.264 bytes to `web/index.island-intro.mp4`, outside the PCK. The poster and final native still come from V0's decoded reference PNGs. All generated projects, packages, and native media live under ignored `build/island-video-preview/`.

Blender is needed only to create the native OGV; use `--blender "path/to/blender.exe"` if it is not on PATH or at the recorded Windows location. The installed FFmpeg 8.0 Windows full build produced a corrupt Theora stream, consistent with the [maintainer's Windows Theora issue](https://github.com/GyanD/codexffmpeg/issues/196). The builder uses Blender 4.2.2's VSE encoder instead and verifies all 104 frames with FFprobe. Native encoding is lossy and is not the visual fidelity authority. Browser playback uses the original clip.

## Adapter contract

`frontend/island/video/IslandVideoPlayback.gd` is a presentation-only `Control`. Add it to the scene tree before preparing it. The caller owns global state and the live scene.

| Interface | Behavior |
|---|---|
| `prepare(web_url, native_path, poster_path, final_frame_path="")` | Reset an existing instance and begin preparation. Web paths are URLs; native paths are Godot resource paths. The optional final-frame PNG supports the native end hold. |
| `play()` | Request playback once ready and focused. Does not replay an ended clip. |
| `pause()` | Freeze playback and clear the request to resume automatically. |
| `restart()` | Prepare again and request playback from the start; also used by Retry. |
| `set_focus_active(bool)` | Host pause gate, in addition to browser focus/visibility. |
| `set_picture_rect(Rect2)` | Shared picture rectangle in root viewport logical coordinates. Use `fit_picture(available)` for centered 4:3. |
| `set_opacity(float)` | Clamp to 0..1; hide at zero. |
| `snapshot()` | State, readiness, presented time, duration, error, frame/completion counts, backend, and rectangle. |
| `release()` | Unload media and remove presentation resources; idempotent and terminal. Create another instance to reuse. |

Signals: `prepared`, `state_changed`, `frame_presented`, `completed`, and `playback_failed`. Completion is emitted once per explicit playback. States are `idle`, `preparing`, `ready`, `playing`, `paused`, `buffering`, `gesture_required`, `ended`, `error`, and `released` (native development does not emulate network buffering or autoplay policy).

The Web bridge is `frontend/island/video/island_video.js`. It uses native HTML video, muted inline playback, `requestVideoFrameCallback` media time, and a `currentTime` fallback. The native backend uses `VideoStreamPlayer.stream_position`; its clock is a development approximation. The declared source duration is 104 * 1001 / 30000 seconds.

The adapter crops only the encoded side borders. Black fit space belongs to the host; the preview supplies it. The DOM layer follows the game canvas on resize, orientation, scroll, and fullscreen changes. Fullscreen must target a container that includes both canvas and overlay (the preview uses `document.documentElement`), because a canvas-only fullscreen target hides sibling DOM layers.

Web errors retain a valid frame or poster and show Retry. Autoplay refusal shows Play intro. Pointer, touch, key, and click events on those actions are consumed. Other space passes input to the host. V5 must coordinate the shared input consumption boundary and later-screen layout policy; this adapter never changes `GameFlow`.

## Validation

```powershell
python tools/build_island_video_preview.py --web
python tools/validate_island_video.py
node tools/test_island_video_web.mjs
```

The browser test accepts an optional Edge/Chromium executable path as its first argument. It uses no relaxed autoplay flag. Autoplay rejection and a media stall are injected; blocked-network failure, tab hiding, fullscreen, and mouse/touch actions use browser APIs. Native checks render on the local GPU. Headless Edge uses SwiftShader, so its results establish functional behavior only.

Current durable results: `docs/evidence/island_intro/v1/`. Fresh runs write logs/captures to `build/island-video-preview/validation/` and `web-checks/`. A browser failure writes `failure.json`; a later successful run writes `results.json` (timestamps distinguish runs).

## Integration work reserved for 23.V4/V5

- Connect live readiness, loading/poster presentation, coordinated water/camera/blur clocks, and endpoint continuation.
- Sample presented video time while playing; freeze the controller on buffering/focus loss. Do not advance from render delta while video is stalled. After `ended`, continue from `duration` using the controller clock.
- Include the bridge JS explicitly in the production pack; current production export excludes raw JS. Copy/audit the exact MP4 companion and poster during packaging. Native OGV stays excluded.
- Reuse the preview server's MIME/range handling in production browser tooling.
- Share the root viewport picture rectangle with live rendering and place fullscreen around both canvas and video.
- Coordinate start/retry/confirm consumption with existing shared input, one-shot intro policy, subsequent layout restoration, and blue logo boundary.
- Release media only after the completed handoff. The retained canvas is updated once per presented frame to survive errors; profile its cost on target phones in V6.

Actual Android Chrome and iPhone Safari playback/performance remain pending. No seamless-transition or visual approval claim is made by V1.
