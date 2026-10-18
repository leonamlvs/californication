"""Build/export V4 in an isolated project; production startup stays unchanged."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/island-transition-preview'
PROJECT=OUT/'project'
EXPECTED='3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866'


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--web',action='store_true');args=parser.parse_args()
    PROJECT.mkdir(parents=True,exist_ok=True)
    native=ROOT/'build/island-video-preview/project/dev/island_video/media'
    if not (native/'intro.ogv').exists(): subprocess.run(['python','tools/build_island_video_preview.py'],cwd=ROOT,check=True)
    files=[]
    for directory in ['dev/island_scene','dev/island_transition','frontend/island/video','presentation/cinematic_fx']:
        files+=list((ROOT/directory).rglob('*'))
    files += [ROOT/'autoload/GameFlow.gd',ROOT/'autoload/InputRouter.gd',ROOT/'data/definitions/CinematicFXProfile.gd']
    files += list((ROOT/'tests/cli').glob('IslandHandoff*'))
    for source in files:
        if not source.is_file():continue
        destination=PROJECT/source.relative_to(ROOT);destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,destination)
    shutil.copytree(native,PROJECT/'dev/island_video/media',dirs_exist_ok=True)
    (PROJECT/'project.godot').write_text('''config_version=5
[application]
config/name="Island Video to Live Transition"
run/main_scene="res://dev/island_transition/IslandTransitionPreview.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[autoload]
InputRouter="*res://autoload/InputRouter.gd"
GameFlow="*res://autoload/GameFlow.gd"
[display]
window/size/viewport_width=960
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0,0,0,1)
''',encoding='utf-8')
    (PROJECT/'export_presets.cfg').write_text('''[preset.0]
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
''',encoding='utf-8')
    def run(arguments,name):
        log=OUT/(name+'.txt')
        command=['godot','--headless','--path',str(PROJECT),*arguments,'--log-file',str(log)]
        result=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=90)
        content=log.read_text(encoding='utf-8',errors='replace')
        if result.returncode or 'ERROR:' in content:raise RuntimeError(content)
        print(name+': PASS',flush=True)
    run(['--editor','--import','--quit'],'import')
    if args.web:
        web=OUT/'web';web.mkdir(exist_ok=True)
        run(['--export-release','Web Preview',str(web/'index.html')],'web-export')
        source=ROOT/'docs/evidence/island_intro/v0/reference/island-intro.mp4'
        assert hashlib.sha256(source.read_bytes()).hexdigest()==EXPECTED
        shutil.copyfile(source,web/'index.island-intro.mp4')
        shutil.copyfile(ROOT/'docs/evidence/island_intro/v0/reference/clip_0000.png',web/'index.poster.png')
        (OUT/'media-manifest.json').write_text(json.dumps(dict(source_sha256=EXPECTED,web_sha256=hashlib.sha256((web/'index.island-intro.mp4').read_bytes()).hexdigest(),duration=104*1001/30000,frames=104),indent=2)+'\n')
    print('ISLAND_HANDOFF_BUILD_PASS')


if __name__=='__main__': main()
