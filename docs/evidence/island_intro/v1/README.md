# 23.V1 evidence — video playback

Captured 2026-10-16 against HEAD `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720` plus the uncommitted V0/V1 changes described in the [handoff](../../../ISLAND_INTRO_HANDOFF.md). V0 is preserved separately.

## Evidence contents

- `baseline-before/`: import, main startup, Task 23/24 logs and commands before V1 edits.
- `validation/`: final Godot command arrays, exit codes, elapsed times, and logs. Includes contract/rendered playback, unchanged Task 23/24, fresh production export/content/isolation, and isolated-preview JS/media audit.
- `native/`: rendered poster, paused desktop/portrait, and completed-frame captures on AMD Radeon RX 7600.
- `browser/`: 15 functional checks and Edge version in `results.json`; layout, retained-frame, gesture, failure, and fullscreen PNGs. Chromium uses SwiftShader; no performance claim. The Godot toolbar is development UI, not production presentation.
- `build/`: preview import/export logs, source/native hashes, FFprobe decoded-frame metadata, and encoding recipe.
- `integrity.json`: SHA-256 and byte sizes of this evidence snapshot and implementation sources.

## Reproduce

```powershell
python tools/build_island_video_preview.py --web
python tools/validate_island_video.py
node tools/test_island_video_web.mjs
```

The builder uses the durable exact V0 MP4 and reference PNGs. Blender creates the native OGV; FFprobe verifies all 104 frames. Browser bytes are copied without transcoding. See [preview usage and contract](../../../../dev/island_video/README.md).

All ten final Godot/build checks pass. Browser cases cover exact source bytes/HTTP ranges, normal autoplay/source speed, pause, three layouts, host focus, injected buffering, one-shot completion, mid-play error retention/retry, release, real tab visibility/fullscreen, injected autoplay rejection with consumed mouse input, real network block with consumed touch retry, and currentTime fallback. The new tests found and resolved native completion-signal ordering; tab tests observe native HTML media while Godot's hidden render loop is suspended.

Screen sizes/DPR emulate layout, not physical phones. Actual Android/iPhone behavior and hardware performance remain pending. Source/framing inspection is not approval of seamless visual continuity; V2/V4/V6 visual gates remain open. No live island or production integration was started.

The parent `.gdignore` keeps this evidence out of runtime imports. Generated OGV, PCK/WASM, browser profiles, and duplicate MP4 files remain under ignored `build/` and are intentionally not copied here.
