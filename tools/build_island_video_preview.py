"""Build an isolated Task 23.V1 preview without editing the production project.

python tools/build_island_video_preview.py --web
godot --path build/island-video-preview/project
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/island-video-preview"
PROJECT = OUTPUT / "project"
REFERENCE = ROOT / "docs/evidence/island_intro/v0/reference"
EXPECTED = "3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def godot(arguments, label):
    log = OUTPUT / (label + ".txt")
    result = subprocess.run(["godot", "--headless", "--path", str(PROJECT), *arguments, "--log-file", str(log)],
                            cwd=ROOT, capture_output=True, timeout=90)
    text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
    if result.returncode or "ERROR:" in text:
        raise RuntimeError(f"{label} failed:\n{text}\n{result.stderr.decode(errors='replace')}")
    print(label + ": PASS", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web", action="store_true", help="Also export the isolated Godot Web preview")
    parser.add_argument("--blender", default=shutil.which("blender") or "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe")
    args = parser.parse_args()
    source = REFERENCE / "island-intro.mp4"
    if digest(source) != EXPECTED:
        raise RuntimeError("Approved source clip hash differs")
    PROJECT.mkdir(parents=True, exist_ok=True)
    (ROOT / "build/.gdignore").write_text("", encoding="utf-8")
    paths = [
        "frontend/island/video/IslandVideoPlayback.gd", "frontend/island/video/island_video.js",
        "dev/island_video/IslandVideoPreview.gd", "dev/island_video/IslandVideoPreview.tscn",
    ]
    paths += [str(path.relative_to(ROOT)).replace("\\", "/") for path in (ROOT / "tests/cli").glob("IslandVideo*Test.*")]
    for relative in paths:
        destination = PROJECT / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, destination)
    media = PROJECT / "dev/island_video/media"
    media.mkdir(parents=True, exist_ok=True)
    native = media / "intro.ogv"
    # The installed Windows FFmpeg full build produces corrupt Theora; Blender's
    # local VSE encoder is verified instead. The browser clip is never transcoded.
    stamp = OUTPUT / "native-encoding.json"
    recipe = {"source_sha256": EXPECTED, "recipe": "blender-vse-theora-8000k-v1"}
    if not native.exists() or not stamp.exists() or json.loads(stamp.read_text()) != recipe:
        result = subprocess.run([
            args.blender, "--background", "--factory-startup", "--python",
            str(ROOT / "tools/encode_island_preview_blender.py"), "--", str(source), str(native),
        ], capture_output=True, timeout=60)
        (OUTPUT / "native-encoding.txt").write_bytes(result.stdout + result.stderr)
        result.check_returncode()
        stamp.write_text(json.dumps(recipe, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(REFERENCE / "clip_0000.png", media / "poster.png")
    shutil.copyfile(REFERENCE / "clip_0103.png", media / "last.png")
    (PROJECT / "project.godot").write_text('''config_version=5

[application]
config/name="Island Video Development Preview"
run/main_scene="res://dev/island_video/IslandVideoPreview.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=960
window/size/viewport_height=720

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0, 0, 0, 1)
''', encoding="utf-8")
    (PROJECT / "export_presets.cfg").write_text('''[preset.0]
name="Web Preview"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.js"
exclude_filter="tests/*,dev/island_video/media/intro.ogv*"
export_path="../web/index.html"

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''', encoding="utf-8")
    metadata = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-count_frames", "-show_entries",
        "stream=codec_name,codec_type,width,height,nb_read_frames,r_frame_rate:format=duration,size", "-of", "json", str(native),
    ]))
    streams = metadata["streams"]
    if len(streams) != 1 or streams[0]["codec_name"] != "theora" or streams[0]["nb_read_frames"] != "104":
        raise RuntimeError("Unexpected native preview encoding")
    (OUTPUT / "media-manifest.json").write_text(json.dumps({
        "source_sha256": EXPECTED, "native_sha256": digest(native), "native_metadata": metadata,
        "web_encoding": "byte-identical H.264 source; no transcoding", "native_encoding": "Blender VSE Theora; 8000 kbit/s target; no audio; 104 frames",
    }, indent=2) + "\n", encoding="utf-8")
    godot(["--editor", "--import", "--quit"], "preview-import")
    if args.web:
        web = OUTPUT / "web"
        web.mkdir(parents=True, exist_ok=True)
        godot(["--export-release", "Web Preview", str(web / "index.html")], "preview-web-export")
        shutil.copyfile(source, web / "index.island-intro.mp4")
        shutil.copyfile(REFERENCE / "clip_0000.png", web / "index.poster.png")
        assert digest(web / "index.island-intro.mp4") == EXPECTED
    print("ISLAND_VIDEO_PREVIEW_BUILD_PASS", flush=True)


if __name__ == "__main__":
    main()
