# V4 — video/live handoff evidence

Recorded 2026-10-17. **Implementation is ready; visual review 2 is pending.** Last fully completed milestone remains V3. See [handoff](../../../ISLAND_INTRO_HANDOFF.md) and [preview instructions](../../../../dev/island_transition/README.md).

## Review

- [Recorded review page](review/index.html): actual exported-browser capture at normal speed, overlap contact sheet, and live preview link.
- Local served review: http://127.0.0.1:8065/review/index.html (run `node tools/serve_island_transition.mjs`).
- [Recording metadata](recording-metadata.json): 677 captured browser frames, approximately 7.049 seconds, eight sampled overlap/settling frames, rendering backend, and exact FFmpeg encoding command.
- [Browser results](browser/results.json): twelve passing checks, Edge 155.0.4283.45, accelerated AMD Radeon RX 7600 / ANGLE D3D11.
- [CLI/native/package results](validation/results.json): eleven passing checks, exact command arrays, exit codes, and adjacent logs. Native rendered attract is `validation/native-attract.png`.
- `baseline-before/` preserves the successful V3 resume checks: eleven CLI/native/package and eight browser checks before V4 edits.
- [Preservation](preservation.json) verifies approved V2 geometry/atlas/editable source and V3 live study/camera/water resources remain byte-identical. [Integrity](integrity.json) records current HEAD and implementation/evidence hashes. [Commands](commands.json) reproduce this milestone.

## Checks and interpretation

CLI coverage includes root import/startup, Tasks 22/23/24/26, deterministic handoff clock/FX contracts, native playback-to-attract capture, fresh production export, existing content audit, and source isolation. The production pack contains 387 resources and excludes the new development preview.

Browser coverage includes source-speed playback through attract/release, real composed recording, synchronized pause, portrait/landscape/wide resize, containing-element fullscreen, buffering, real tab focus loss during blend, retained media error/Retry, rejected autoplay/start, direct attract, presented-clock fallback, exact MP4 bytes/range serving, and no runtime errors. Media stall/error/autoplay refusal are injected reproducible cases; actual phone browser behavior remains V6.

The recording uses CDP screencast timestamps and the real browser composition, without substituting or offline blending footage. `browser/recording.json` retains frame timestamps and presentation trace; individual JPEG capture frames are reproducible ignored build outputs. The durable MP4 and eight PNG samples preserve the review. Nonblack sample assertions are coarse diagnostics; they do not prove seamlessness. The sampled images were inspected for framing, retained image, softened live coastline, and settling.

Initial inspection prompted live-only mipmap softening (LOD 3.5) alongside radial blur (strength 0.22). Camera knots, footage speed/duration, island assets, water palette, and water phase were preserved. Final controller tuning is documented in the preview README. Retry was corrected to clear the paused presentation clock before replay.

Recorded rAF intervals during overlap and steady attract have approximately 4.20 ms median / 4.30 ms p95 on this instrumented accelerated desktop browser. These are browser callback intervals with capture overhead, **not GPU frame times, delivered game FPS, or V6 performance acceptance**. Actual Android/iPhone measurements and visual review 3 remain pending. No pixel-perfect reconstruction or user approval is claimed.

## Resume

Review the actual recording at normal speed. Record explicit user approval or tune V4 from concrete feedback. Do not begin V5 until this milestone's visual gate is satisfied and V5 is requested. The current normal game presentation is unchanged; V5 connects the approved result to loading, continuation input, and the logo sequence.
