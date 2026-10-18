"""Preserve Task 23.V0 references; does not generate runtime art or encode the intro.

Run from any directory: python tools/capture_island_intro_reference.py
Requires the two original .ref videos, FFmpeg, and FFprobe. Uses Python stdlib only.
"""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
CLIP = Path(".ref/island-intro/island-intro.mp4")
ORIGINAL = Path(".ref/music-video.mp4")
BUNDLE = Path("docs/evidence/island_intro/v0")
EXPECTED_CLIP_SHA256 = "3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866"
EXPECTED_ORIGINAL_SHA256 = "b09cdb326cf1e62574c3aea75b1be4f599c4b48baf517fb03da25d1886ba366a"
CLIP_FRAMES = (0, 98, 99, 100, 101, 102, 103)
ORIGINAL_FRAMES = (193, 199, 200, 205, 211, 223)
MATCH_FRAMES = (0, 45, 80, 90, 98, 99, 100, 101, 102, 103)
COMMANDS = []


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(arguments):
    arguments = [str(argument) for argument in arguments]
    COMMANDS.append(arguments)
    result = subprocess.run(arguments, cwd=ROOT, capture_output=True, check=True)
    return result.stdout


def probe(path, count_frames=True):
    return json.loads(run([
        "ffprobe", "-v", "error", *(["-count_frames"] if count_frames else []), "-show_entries",
        "format=duration,size:stream=codec_name,codec_type,width,height,"
        "r_frame_rate,avg_frame_rate,nb_frames,nb_read_frames,pix_fmt,"
        "sample_aspect_ratio,display_aspect_ratio,color_range,color_space,"
        "color_transfer,color_primaries", "-of", "json", path,
    ]))


def gray_frames(path, duration=None):
    arguments = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path]
    if duration is not None:
        arguments += ["-t", str(duration)]
    arguments += [
        "-vf", "crop=960:720:160:0,scale=64:48,format=gray",
        "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "gray", "pipe:1",
    ]
    raw = run(arguments)
    if len(raw) % 3072:
        raise RuntimeError("Incomplete decoded grayscale reference frame")
    return [raw[index:index + 3072] for index in range(0, len(raw), 3072)]


def capture(path, frame, destination):
    run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", path,
        "-vf", f"select=eq(n\\,{frame}),crop=960:720:160:0",
        "-fps_mode", "passthrough", "-frames:v", "1", "-update", "1", destination,
    ])


def main():
    for path, expected in ((CLIP, EXPECTED_CLIP_SHA256), (ORIGINAL, EXPECTED_ORIGINAL_SHA256)):
        if sha256(ROOT / path) != expected:
            raise RuntimeError(f"Source hash changed: {path}. Reconcile the approved reference first.")
    if not (ROOT / BUNDLE.parent / ".gdignore").is_file():
        raise RuntimeError("Reference directory must have .gdignore before capturing assets")

    clip_metadata = probe(CLIP)
    original_metadata = probe(ORIGINAL, count_frames=False)
    video = clip_metadata["streams"][0]
    if len(clip_metadata["streams"]) != 1 or video["codec_type"] != "video":
        raise RuntimeError("Expected one video stream and no audio")
    if (video["nb_read_frames"], video["r_frame_rate"], video["width"], video["height"]) != (
        "104", "30000/1001", 1280, 720,
    ):
        raise RuntimeError("Unexpected clip geometry or timing")

    clip_frames = gray_frames(CLIP)
    original_frames = gray_frames(ORIGINAL, 9)
    timestamps = json.loads(run([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-read_intervals", "0%+9",
        "-show_entries", "frame=best_effort_timestamp_time", "-of", "json", ORIGINAL,
    ]))["frames"]
    if abs(float(timestamps[0]["best_effort_timestamp_time"]) - 1001 / 30000) > 0.000001:
        raise RuntimeError("Original video's first presentation timestamp changed")
    matches = []
    for index in MATCH_FRAMES:
        scores = [
            sum((left - right) ** 2 for left, right in zip(clip_frames[index], reference)) / 3072
            for reference in original_frames
        ]
        source_index = min(range(len(scores)), key=scores.__getitem__)
        if source_index != index + 87 or scores[source_index] > 1.0:
            raise RuntimeError(f"Reference mapping changed at clip frame {index}")
        matches.append({
            "clip_frame_zero_based": index,
            "clip_seconds": index * 1001 / 30000,
            "original_frame_zero_based": source_index,
            "original_seconds": float(timestamps[source_index]["best_effort_timestamp_time"]),
            "original_timeline_slot": source_index + 1,
            "gray_64x48_mse": scores[source_index],
        })

    references = BUNDLE / "reference"
    (ROOT / references).mkdir(parents=True, exist_ok=True)
    preserved_clip = references / "island-intro.mp4"
    if (ROOT / preserved_clip).exists() and sha256(ROOT / preserved_clip) != EXPECTED_CLIP_SHA256:
        raise RuntimeError("Preserved clip differs; refusing to overwrite it")
    shutil.copyfile(ROOT / CLIP, ROOT / preserved_clip)

    assets = [preserved_clip]
    for label, path, frames in (("clip", CLIP, CLIP_FRAMES), ("original", ORIGINAL, ORIGINAL_FRAMES)):
        for frame in frames:
            destination = references / f"{label}_{frame:04d}.png"
            capture(path, frame, destination)
            assets.append(destination)

    continuation = references / "continuation-reference.mp4"
    run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", ORIGINAL,
        "-vf", "trim=start_frame=191:end_frame=224,setpts=PTS-STARTPTS",
        "-frames:v", "33", "-an", "-c:v", "libx264", "-crf", "12", "-preset", "medium",
        "-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709",
        "-color_trc", "bt709", "-color_primaries", "bt709",
        "-fps_mode", "passthrough", "-movflags", "+faststart", continuation,
    ])
    assets.append(continuation)
    continuation_metadata = probe(continuation)
    if continuation_metadata["streams"][0]["nb_read_frames"] != "33":
        raise RuntimeError("Continuation reference must have exactly 33 frames")

    manifest = {
        "milestone": "23.V0",
        "baseline_revision": run(["git", "rev-parse", "HEAD"]).decode().strip(),
        "clip": {"original_path": CLIP.as_posix(), "sha256": EXPECTED_CLIP_SHA256, "metadata": clip_metadata},
        "original_video": {"path": ORIGINAL.as_posix(), "sha256": EXPECTED_ORIGINAL_SHA256, "metadata": original_metadata},
        "active_picture": {"x": 160, "y": 0, "width": 960, "height": 720, "png_crop": "960:720:160:0"},
        "frame_indexing": "Zero-based native decode indices. Clip starts at PTS 0; original starts at PTS 0.033367. Original timeline slots are native index + 1. Use fps_mode passthrough to avoid CFR padding at the beginning.",
        "approved_plan_numbering_correction": "Approved reference slots 88-191 correspond to native original frames 87-190. Full-reveal timeline slot 200 is native frame 199 (PTS 6.673333); native frame 200 is also preserved as a nearby fully framed reference. Authored transition timings are unchanged.",
        "mapping_method": "Lowest mean squared error of cropped 64x48 grayscale decodes over the original first 9 seconds; verifies sampled correspondence, not identical encoded pixels.",
        "frame_matches": matches,
        "continuation": {
            "original_start_frame_inclusive": 191,
            "original_end_frame_inclusive": 223,
            "metadata": continuation_metadata,
            "purpose": "Development reference only; re-encoded at CRF 12. Never append to or replace the supplied runtime clip. PNGs are lossless decoded crops.",
        },
        "tools": {name: run([name, "-version"]).decode().splitlines()[0] for name in ("ffmpeg", "ffprobe")},
        "assets": [
            {"path": path.relative_to(BUNDLE).as_posix(), "bytes": (ROOT / path).stat().st_size, "sha256": sha256(ROOT / path)}
            for path in assets
        ],
        "commands": COMMANDS,
    }
    (ROOT / BUNDLE / "reference-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"REFERENCE_CAPTURE_PASS assets={len(assets)} bytes={sum(asset['bytes'] for asset in manifest['assets'])} matches={len(matches)}")


if __name__ == "__main__":
    main()
