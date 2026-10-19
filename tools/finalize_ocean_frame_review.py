"""Preserve the untouched-frame ocean review. Run with Blender/OpenCV."""
from pathlib import Path
import sys, json, shutil, hashlib, subprocess
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/island-authoring-deps'))
import cv2
import numpy as np
OUT=ROOT/'docs/evidence/island_intro/ocean-frame'
BUILD=ROOT/'build/ocean-frame'


def main():
    review=OUT/'review';review.mkdir(parents=True,exist_ok=True)
    source=ROOT/'docs/evidence/island_intro/v0/reference/original_0199.png'
    runtime=ROOT/'frontend/island/live/assets/ocean-frame.png'
    assert source.read_bytes()==runtime.read_bytes(),'Screenshot was modified'
    checks=[dict(name='Screenshot is byte-identical to original source frame 199',passed=True,sha256=hashlib.sha256(runtime.read_bytes()).hexdigest())]
    def read(path):
        data=cv2.imread(str(path));assert data is not None,str(path)
        return data
    def capture(name):return read(BUILD/'captures'/f'{name}.png')
    assert np.array_equal(capture('reveal'),capture('static-later'))
    checks.append(dict(name='Water time does not animate the screenshot',passed=True))
    delta=np.abs(capture('rotation_000').astype(float)-capture('rotation_360').astype(float))
    assert delta.mean()<.01
    checks.append(dict(name='Full rotation returns to same alignment',passed=True,mean=float(delta.mean())))
    for path in (BUILD/'captures').glob('*.png'):shutil.copyfile(path,review/path.name)
    shutil.copyfile(source,review/'source.png')
    panels=[]
    for title,data in [('Untouched source frame',read(source)),('3D island above screenshot',capture('reveal'))]:
        p=cv2.resize(data,(480,360));cv2.rectangle(p,(0,0),(480,28),(15,15,15),-1)
        cv2.putText(p,title,(8,20),cv2.FONT_HERSHEY_SIMPLEX,.5,(255,255,255),1,cv2.LINE_AA);panels.append(p)
    cv2.imwrite(str(review/'comparison.png'),np.hstack(panels))
    panels=[cv2.resize(capture('rotation_%03d'%angle),(320,240)) for angle in range(0,360,45)]
    cv2.imwrite(str(review/'rotation-sheet.png'),np.vstack([np.hstack(panels[:4]),np.hstack(panels[4:])]))
    recording=json.loads((BUILD/'browser/recording.json').read_text())
    frames=sorted({f['timestamp']:f for f in recording['frames']}.values(),key=lambda f:f['timestamp'])
    assert len(frames)>30 and not recording['errors']
    lines=['ffconcat version 1.0']
    for i,f in enumerate(frames):
        duration=frames[i+1]['timestamp']-f['timestamp'] if i+1<len(frames) else 1/60
        lines.extend(["file '"+f['name']+"'",f'duration {duration:.9f}'])
    lines.append("file '"+frames[-1]['name']+"'")
    concat=BUILD/'browser/recording.ffconcat';concat.write_text('\n'.join(lines)+'\n')
    subprocess.run(['ffmpeg','-v','error','-y','-safe','0','-f','concat','-i',str(concat),'-vf','fps=30',
                    '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(review/'browser-handoff.mp4')],check=True)
    for name in recording['captures']:shutil.copyfile(BUILD/'browser'/name,review/name)
    checks.append(dict(name='Actual exported-browser handoff captured without runtime errors',passed=True,frames=len(frames)))
    for name in ['frontend/island/live/assets/island.glb','frontend/island/live/assets/island-color.png',
                 'frontend/island/live/transition.tres','frontend/island/live/handoff.tres','frontend/island/live/IslandProductionSequence.gd']:
        a=subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT);b=(ROOT/name).read_bytes()
        if name.endswith(('.gd','.tres')):a=a.replace(b'\r\n',b'\n');b=b.replace(b'\r\n',b'\n')
        assert a==b,name
        checks.append(dict(name='Preserved '+name,passed=True))
    shutil.copytree(ROOT/'build/island-production/validation',OUT/'validation',dirs_exist_ok=True)
    for name in ['baseline-task23.txt','baseline-task24.txt','import.txt','capture.txt']:shutil.copyfile(BUILD/name,OUT/name)
    for name in ['recording.json','console.json']:shutil.copyfile(BUILD/'browser'/name,OUT/name)
    (OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
    (review/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Full-frame ocean</title>
<style>body{font:16px system-ui;background:#111521;color:#eef;max-width:1100px;margin:24px auto;padding:16px}img,video{max-width:100%}.portrait{max-height:640px}</style>
<h1>Full screenshot beneath the 3D island</h1><p>The actual frame is unchanged: land, beach and wave bands stay in the texture. No wave animation. Visual approval pending.</p>
<h2>Source / live scene</h2><img src="comparison.png"><h2>Production browser handoff</h2><video src="browser-handoff.mp4" controls playsinline loop></video>
<h2>Full rotation</h2><img src="rotation-sheet.png"><h2>Portrait</h2><img class="portrait" src="attract-portrait.png">
<h2>Beach close-up</h2><img src="close-beach.png">''',encoding='utf-8')
    print('OCEAN_FRAME_REVIEW_PASS',len(checks),'checks; visual approval pending')


if __name__=='__main__':main()
