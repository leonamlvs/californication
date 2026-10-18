"""Build the isolated island/camera/water study; production startup is untouched.

python tools/build_island_scene_preview.py --web
Optional --generate invokes the reproducible Blender asset generator.
"""
from pathlib import Path
import argparse, json, math, shutil, subprocess
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'build/island-scene-preview'
PROJECT=OUTPUT/'project'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--web',action='store_true')
    parser.add_argument('--generate',action='store_true')
    parser.add_argument('--generate-ocean',action='store_true')
    parser.add_argument('--blender',default=shutil.which('blender') or 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe')
    args=parser.parse_args()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    if args.generate:
        result=subprocess.run([args.blender,'--background','--factory-startup','--python-exit-code','1','--python',str(ROOT/'tools/generate_island_asset.py')],cwd=ROOT,capture_output=True,timeout=60)
        (OUTPUT/'generate.txt').write_bytes(result.stdout+result.stderr);result.check_returncode()
    if args.generate_ocean:
        result=subprocess.run([args.blender,'--background','--factory-startup','--python-exit-code','1','--python',str(ROOT/'tools/generate_island_ocean.py')],cwd=ROOT,capture_output=True,timeout=60)
        (OUTPUT/'generate-ocean.txt').write_bytes(result.stdout+result.stderr);result.check_returncode()
    measurements=[m for m in json.loads((ROOT/'docs/evidence/island_intro/v2/reference-measurements.json').read_text())['measurements'] if m['native_frame']>=186]
    config=json.loads((ROOT/'art/source/island_intro/authoring.json').read_text())
    def numbers(values):return ', '.join(f'{v:.10f}' for v in values)
    profile='''[gd_resource type="Resource" script_class="IslandTransitionProfile" load_steps=2 format=3]

[ext_resource type="Script" path="res://dev/island_scene/IslandTransitionProfile.gd" id="1"]

[resource]
script = ExtResource("1")
'''
    profile+='times = PackedFloat32Array('+numbers(m['intro_seconds'] for m in measurements)+')\n'
    profile+='ortho_sizes = PackedFloat32Array('+numbers(config['reference_ortho_size']/m['scale'] for m in measurements)+')\n'
    profile+='targets = PackedVector2Array('+numbers(v for m in measurements for v in m['target_pixel'])+')\n'
    profile+='rolls_degrees = PackedFloat32Array('+numbers(m['roll_degrees'] for m in measurements)+')\n'
    for key in ['pixels_per_unit','camera_distance']:
        profile+=f'{key} = {config[key]}\n'
    profile+=f'elevation_degrees = {config["camera_elevation_degrees"]}\n'
    (ROOT/'dev/island_scene/transition.tres').write_text(profile,encoding='utf-8')
    shutil.copyfile(ROOT/'docs/evidence/island_intro/v0/reference/original_0199.png',ROOT/'dev/island_scene/reference.png')
    files=[p for p in (ROOT/'dev/island_scene').rglob('*') if p.is_file() and p.suffix!='.import']
    files += list((ROOT/'dev/island_scene/assets').glob('ocean-*.png.import'))
    files += [ROOT/'frontend/island/video/IslandVideoPlayback.gd']
    files += list((ROOT/'tests/cli').glob('IslandScene*'))
    files += list((ROOT/'tests/cli').glob('IslandOcean*'))
    for source in files:
        destination=PROJECT/source.relative_to(ROOT)
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,destination)
    (PROJECT/'project.godot').write_text('''config_version=5

[application]
config/name="Island Geometry, Camera and Water Study"
run/main_scene="res://dev/island_scene/IslandScenePreview.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

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
include_filter=""
exclude_filter="tests/*"
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
    def run(arguments,label):
        log=OUTPUT/(label+'.txt')
        result=subprocess.run(['godot','--headless','--path',str(PROJECT),*arguments,'--log-file',str(log)],cwd=ROOT,capture_output=True,timeout=60)
        text=log.read_text(encoding='utf-8',errors='replace')
        if result.returncode or 'ERROR:' in text:raise RuntimeError(text)
        print(label+': PASS',flush=True)
    run(['--editor','--import','--quit'],'import')
    if args.web:
        (OUTPUT/'web').mkdir(exist_ok=True)
        run(['--export-release','Web Preview',str(OUTPUT/'web/index.html')],'web-export')
    print('ISLAND_SCENE_PREVIEW_BUILD_PASS',flush=True)


if __name__=='__main__':main()
