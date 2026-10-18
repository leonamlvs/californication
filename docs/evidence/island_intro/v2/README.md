# 23.V2 evidence — island and camera

**V2 complete; user visual review 1 approved on 2026-10-16.** See [the explicit approval](APPROVAL.md). The artifacts below retain their capture-time status. Captured against baseline HEAD `fc03f6ffb2cb1678dd0e9afbe9b184d8f0a88720` plus uncommitted V0/V1/V2 changes.

Start with [the visual review](review/index.html), [the implementation handoff](../../../ISLAND_INTRO_HANDOFF.md), and [study instructions](../../../../dev/island_scene/README.md).

## Evidence

- `baseline-before/`: V1 was rebuilt and all its CLI/native/browser/pack checks passed before V2 edits.
- `reference/`: native source frames 180–199, land mask, traced coast, and contact sheet. Frames 180–190 are decoded from the exact approved clip; 191–199 from the original with its nonzero-first-PTS correction. Original hashes are preserved in V0.
- `reference-measurements.json`: coastline and adjacent-frame affine fits, mean-singular-value scale, camera target, roll, fit scores, and tool versions. Metric terrain and projection assumptions are documented separately.
- `asset-manifest.json`: island/atlas/editable-source hashes, sizes, triangle count, bounds, and generator version.
- `validation/`: final command arrays, exit codes, all nine CLI/native/pack checks, and isolated import/export/generation logs.
- `browser/`: five functional exported-Edge checks and rendered desktop/phone-size layouts. These use SwiftShader and do not establish physical-device performance.
- `review/`: full reveal comparison slider, matched pullback stills, live camera MP4, rotation sheet, and clay geometry view.
- `comparison-metrics.json`: full reveal pixel differences, with explicit limits on interpretation.
- `review-commands.json`: exact FFmpeg command for the camera MP4.
- `integrity.json`: evidence and implementation snapshot hashes; not an assertion that future mutable documents stay byte-identical.

## Results and interpretation

The island is one closed mesh with 10,766 triangles, one 2048x2048 atlas, and a beach edge below the flat water plane. Geometry/camera checks passed at 14 measured camera samples and 73 rotation angles. Source and development assets are excluded from the fresh production resource pack. Existing Task 23/24 acceptance passes; production behavior is unchanged.

The full-reveal projection closely reproduces source color (land mean absolute RGB difference approximately 1.84/255). This is expected when reference pixels are projected onto relief. It does not validate unseen terrain, the original camera's physical parameters, or seamless handoff. Heights, projection/elevation, scale, and final settling are editable authored choices.

Earlier close-up frames retain visible coast/atlas differences and source softness/streaking. V4 must assess those under live blur and the actual blend. V2 uses a frozen ocean plate; V3 must replace its wave detail and anchor the deep-water pattern to world coordinates. No V3, V4, or production integration was started.

All relevant reproduction commands and dependency setup are in the study README. The saved assets and reference bundle permit another session to continue without `.godot`, generated build caches, or the complete original video. Recomputing original-video measurement frames requires the original source hash recorded in V0.
