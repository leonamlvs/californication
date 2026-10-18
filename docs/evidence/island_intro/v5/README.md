# 23.V5 production integration evidence

Date: 2026-10-18. Revision: `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720`
plus the uncommitted V0-V5 working changes. V5 is complete; V6 is not started.

## Reproduce

```powershell
python tools/validate_island_production.py
node tools/smoke_web.mjs
python tools/finalize_island_production_evidence.py
node tools/serve_production_web.mjs
```

Open http://127.0.0.1:8066/index.html for the normal game. Native: `godot --path .`.

## Evidence

- `baseline-before/`: fresh V4 validation/browser results before integration.
- `validation/results.json`: thirteen successful Godot, regression, production-flow,
  export and pack checks with exact commands, exit codes and durations. Adjacent
  logs retain diagnostic output; `package.json` lists exact companion hash/files/bytes.
- `browser/results.json`, `console.json`: exported game checks and runtime output.
  The named PNGs show loading, actual video, held error, overlap, island in desktop
  and portrait, blue logo boundary, Player Select, gameplay and return to island.
- `integrity.json`: revision, authoritative clip hash, runtime source hashes, and
  byte-identical comparison against approved island/atlas/water assets.

The screenshot audit found and fixed old ocean geometry overlapping the logo's
blue plane. Browser focus, Retry, loading visibility and viewport sizing fixes
are detailed in the main handoff. Browser error is injected; tab focus loss is
real. Buffering and gesture holds also have deterministic production-controller
coverage; V4 records the adapter's browser buffering/autoplay-refusal cases.

Tools: Godot 4.7.2, Python 3.14, Node 24.19.0, Edge 155.0.4283.45;
accelerated AMD Radeon RX 7600. These are functional checks and desktop visual
inspection. Actual phone performance and visual review 3 are pending V6.
Existing explicit V2/V4 visual approvals remain authoritative.

Non-blocking CLI diagnostic: Task 23's immediate test-process shutdown reports
four audio ObjectDB instances (two `AudioStreamWAV` and two playback objects).
A verbose rerun identifies the shared Music/SFX objects; no parser/resource
errors or browser runtime errors occur. This is not a video-resource leak.
