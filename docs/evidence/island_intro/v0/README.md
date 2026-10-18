# Task 23.V0 reference and baseline evidence

This bundle supports [the island plan](../../../ISLAND_INTRO_PLAN.md) and [handoff](../../../ISLAND_INTRO_HANDOFF.md). Everything beneath `docs/evidence/island_intro/` is excluded from Godot import/export by its parent `.gdignore`.

## Sources and integrity

- `reference/island-intro.mp4`: byte-identical copy of the user-supplied `.ref/island-intro/island-intro.mp4`, 3,883,069 bytes. This is the authoritative footage for later promotion into the approved runtime companion asset.
- Intro SHA-256: `3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866`.
- Original `.ref/music-video.mp4` SHA-256: `b09cdb326cf1e62574c3aea75b1be4f599c4b48baf517fb03da25d1886ba366a`. The full original is not duplicated in this bundle.
- `reference-manifest.json`: metadata, measured frame matches, all 15 asset hashes, and exact FFmpeg/FFprobe argument arrays. The reference media occupy 7,494,390 bytes with the recorded tool versions.

The clip has 104 frames at 30000/1001 fps, no audio, limited-range BT.709 H.264/yuv420p, and a 960x720 active picture at `(160, 0)` in the 1280x720 encoded image. Its final displayed frame starts at 3.436767 s; the container duration is 3.470133 s.

## Frame-number correction

The original starts at PTS 0.033367 s; the supplied clip starts at PTS 0. Earlier comparison output used constant-frame-rate padding, so the approved plan's source labels 88-191 are **timeline slots**. They correspond to **native zero-based original decode indices 87-190**. Do not shift the approved playback timing or trim the supplied clip to compensate.

| Reference | Native frame | Original PTS | Relative intro time |
|---|---:|---:|---:|
| Clip first frame | Original 87 / clip 0 | 2.936267 s | 0 s |
| Blend start | Original 186 / clip 99 | 6.239567 s | 3.303300 s |
| Clip last frame | Original 190 / clip 103 | 6.373033 s | 3.436767 s |
| First continuation frame | Original 191 | 6.406400 s | 3.470133 s |
| Full-reveal timeline slot 200 | Original 199 | 6.673333 s | 3.737067 s |
| Neighboring full-island reference | Original 200 | 6.706700 s | 3.770433 s |

The capture script checks ten sampled matches across the clip against the original's first nine seconds, using 64x48 grayscale active-picture comparisons. Sample MSE values are below 0.44 on an 8-bit luma scale. This supports correspondence; it is not a claim of identical encoded pixels.

## Preserved visual evidence

- `reference/clip_0000.png`: first-frame poster reference.
- `reference/clip_0098.png` through `clip_0103.png`: the frame before the blend and its final five frames.
- `reference/original_0193.png`: rapid live pullback reference.
- `reference/original_0199.png` and `original_0200.png`: fully framed island references.
- `reference/original_0205.png`, `original_0211.png`, `original_0223.png`: terrain, beach, cyan-water, and ripple references after the reveal.
- `reference/continuation-reference.mp4`: native original frames 191-223 inclusive, 33 frames / 1.101100 s, no audio. It preserves encoded framing and is re-encoded with libx264 CRF 12 for compact development viewing. It is **not** authorized runtime footage to append to the supplied clip.

PNGs are lossless decoded RGB crops of the active picture. Both MP4s retain encoded 1280x720 framing. These files are source evidence, not final island textures, a runtime poster, or approved visual implementation captures.

## Reproduce and validate

Run from the repository root:

```powershell
python tools/capture_island_intro_reference.py
```

The script requires the original two `.ref` videos and their exact recorded hashes, FFmpeg/FFprobe, and Python standard library only. It validates timing and mapping before extraction. Preserve existing evidence if the source hash changes; reconcile it against the plan instead of silently replacing the source. Regeneration with a different FFmpeg build can change encoded reference bytes; record the tool change and review the new manifest.

A new checkout without `.ref` can still begin 23.V1 using the preserved byte-identical clip. The preserved continuation and PNGs provide the required reference for the live tail and water. Re-running the complete source-matching procedure requires the original music video; obtain it only if additional source analysis is needed.

Godot baseline commands:

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --quit-after 90
godot --headless --path . tests/cli/Task23Test.tscn
godot --headless --path . tests/cli/Task24Test.tscn
```

On this Windows installation, run Godot through `Start-Process -WindowStyle Hidden -PassThru`, wait for the process to finish, and inspect its exit code and `--log-file` output. The durable `validation/` directory records commands, logs, before/after results, and export-isolation evidence. Headless checks establish the existing baseline; they do not approve the new appearance or device performance.

To repeat the export-isolation checks from the repository root (the final two commands use a source script outside the exported pack):

```powershell
godot --headless --path . --export-pack Web .godot/island-intro-v0/baseline.pck
godot --headless --path . --main-pack .godot/island-intro-v0/baseline.pck --script (Join-Path (Get-Location) 'tests/cli/ExportAudit.gd')
godot --headless --path . --main-pack .godot/island-intro-v0/baseline.pck --script (Join-Path (Get-Location) 'docs/evidence/island_intro/v0/validation/check_reference_exclusion.gd')
```

Create `.godot/island-intro-v0` first on a fresh checkout. The actual recorded Windows argument strings and exit codes are in `validation/baseline-after.json`. Keep this V0 evidence snapshot intact when validating later milestones.

## V0 acceptance results

- Before and after: import, main startup, Task 23, and Task 24 passed with exit code 0.
- Fresh Web pack: export succeeded; both pack-content and reference-exclusion audits passed with 385 resources.
- Reference integrity: all 15 file hashes/sizes match the manifest; all 13 PNGs are 960x720. See `validation/reference-integrity.json`.
- Final clip/full-reveal PNGs were inspected for correct framing. These are source inspections; all three implementation visual reviews remain pending.
