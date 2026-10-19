"""Verify static ocean captures and preserve the review (run with Blender)."""
from pathlib import Path
import sys, json, shutil, hashlib, subprocess, zipfile, xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/island-authoring-deps'))
import cv2
import numpy as np
OUT=ROOT/'docs/evidence/island_intro/ocean-color'
BUILD=ROOT/'build/ocean-color'
EDIT=ROOT/'art/source/island_intro/ocean-color'


def main():
    review=OUT/'review';review.mkdir(parents=True,exist_ok=True)
    checks=[]
    def check(name,passed,**details):
        checks.append(dict(name=name,passed=bool(passed),**details))
        assert passed,(name,details)
    def read(path):
        result=cv2.imread(str(path));assert result is not None,str(path)
        return result
    def capture(name):return read(BUILD/'captures'/f'{name}.png')
    check('Water time does not change static pixels',np.array_equal(capture('reveal'),capture('static-later')))
    delta=np.abs(capture('rotation_000').astype(float)-capture('rotation_360').astype(float))
    check('360 degree return matches',delta.mean()<.01,mean=float(delta.mean()))
    tile=read(EDIT/'deep-water-tile.png')
    check('Deep tile edges match',np.array_equal(tile[0],tile[-1]) and np.array_equal(tile[:,0],tile[:,-1]))
    mask=cv2.imread(str(EDIT/'coastal-blend-mask.png'),0)
    check('Coastal mask has zero outer border',all(np.all(a==0) for a in [mask[0],mask[-1],mask[:,0],mask[:,-1]]))
    source=read(EDIT/'reference.png');base=read(EDIT/'base-water.png')
    land=cv2.imread(str(ROOT/'docs/evidence/island_intro/v2/reference/land-mask.png'),0)
    wave=cv2.imread(str(EDIT/'wave-mask.png'),0)
    protected=(land==0)&(wave==0)
    check('Untouched water pixels retain exact source RGB',np.array_equal(base[protected],source[protected]),pixels=int(protected.sum()))
    with zipfile.ZipFile(EDIT/'ocean-color.ora') as archive:
        tree=ET.fromstring(archive.read('stack.xml'))
        check('ORA has seven editable layers at source size',tree.attrib['w']=='960' and tree.attrib['h']=='720' and len(tree.findall('.//layer'))==7)
        check('ORA default merge equals base texture',archive.read('mergedimage.png')==(EDIT/'base-water.png').read_bytes())
    for path in (BUILD/'captures').glob('*.png'): shutil.copyfile(path,review/path.name)
    shutil.copyfile(EDIT/'reference.png',review/'source.png')
    comparison=ROOT/'.ref/frames/frame_0167.jpg'
    if comparison.exists():shutil.copyfile(comparison,review/'user-reference.jpg')
    user=read(review/'user-reference.jpg')[:,160:1120]
    panels=[]
    for title,img in [('User reference frame 0167',user),('Lossless source frame 199',source),('Static textured 3D scene',capture('reveal'))]:
        panel=cv2.resize(img,(480,360));cv2.rectangle(panel,(0,0),(480,28),(20,20,20),-1)
        cv2.putText(panel,title,(10,20),cv2.FONT_HERSHEY_SIMPLEX,.48,(255,255,255),1,cv2.LINE_AA);panels.append(panel)
    cv2.imwrite(str(review/'comparison.png'),np.hstack(panels))
    panels=[]
    for angle in range(0,360,45):
        panel=cv2.resize(capture('rotation_%03d'%angle),(320,240))
        cv2.putText(panel,str(angle)+' deg',(10,22),cv2.FONT_HERSHEY_SIMPLEX,.6,(255,255,255),1,cv2.LINE_AA);panels.append(panel)
    cv2.imwrite(str(review/'rotation-sheet.png'),np.vstack([np.hstack(panels[:4]),np.hstack(panels[4:])]))
    recording=json.loads((BUILD/'browser/recording.json').read_text())
    # CDP may deliver duplicate timestamps; keep the final image at each time.
    frames=sorted({f['timestamp']:f for f in recording['frames']}.values(),key=lambda f:f['timestamp'])
    check('Actual browser composition recorded',len(frames)>30 and not recording['errors'],frames=len(frames),raw_frames=len(recording['frames']))
    lines=['ffconcat version 1.0']
    for i,frame in enumerate(frames):
        duration=frames[i+1]['timestamp']-frame['timestamp'] if i+1<len(frames) else 1/60
        assert duration>0
        lines.extend(["file '"+frame['name']+"'",f'duration {duration:.9f}'])
    lines.append("file '"+frames[-1]['name']+"'")
    concat=BUILD/'browser/recording.ffconcat';concat.write_text('\n'.join(lines)+'\n')
    cmd=['ffmpeg','-v','error','-y','-safe','0','-f','concat','-i',str(concat),'-vf','fps=30','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(review/'browser-handoff.mp4')]
    subprocess.run(cmd,check=True)
    # Align composed screenshots to observed presented video time; no offline compositing.
    trace=[t for t in recording['trace'] if t['video'] and t['time']>0]
    last=max(trace,key=lambda t:t['time'])
    panels=[]
    for t in [3.3033,3.37,3.4367,3.4701,3.57,3.7371]:
        sample=min(trace,key=lambda s:abs(s['time']-t)) if t<=last['time'] else last
        wall=sample['wall']/1000+max(0,t-sample['time'])
        frame=min(frames,key=lambda f:abs(f['timestamp']-wall))
        img=read(BUILD/'browser'/frame['name']);check('No black overlap sample '+str(t),img.mean()>5)
        cv2.imwrite(str(review/f'overlap-{t:.3f}.png'),img)
        panel=cv2.resize(img,(480,360));cv2.putText(panel,f'~{t:.3f}s',(12,28),cv2.FONT_HERSHEY_SIMPLEX,.7,(255,255,255),1,cv2.LINE_AA);panels.append(panel)
    cv2.imwrite(str(review/'overlap-sheet.png'),np.vstack([np.hstack(panels[i:i+2]) for i in range(0,6,2)]))
    for name in recording['captures']:shutil.copyfile(BUILD/'browser'/name,review/name)
    checks_path=OUT/'checks.json';checks_path.write_text(json.dumps(checks,indent=2)+'\n')
    shutil.copytree(ROOT/'build/island-production/validation',OUT/'validation',dirs_exist_ok=True)
    for name in ['import.txt','capture.txt']:shutil.copyfile(BUILD/name,OUT/name)
    for name in ['recording.json','console.json']:shutil.copyfile(BUILD/'browser'/name,OUT/name)
    protected_files=['frontend/island/live/assets/island.glb','frontend/island/live/assets/island-color.png',
        'frontend/island/live/transition.tres','frontend/island/live/handoff.tres','frontend/island/live/IslandProductionSequence.gd',
        'frontend/island/live/assets/ocean-shore.png','frontend/island/live/assets/ocean-ripple.png']
    preserved=[]
    for name in protected_files:
        original=subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT)
        current=(ROOT/name).read_bytes()
        comparable = original==current if name.endswith(('.glb','.png')) else original.replace(b'\r\n',b'\n')==current.replace(b'\r\n',b'\n')
        check('Preserved '+name,comparable)
        preserved.append(dict(path=name,sha256=hashlib.sha256(current).hexdigest()))
    (OUT/'preservation.json').write_text(json.dumps(preserved,indent=2)+'\n')
    checks_path.write_text(json.dumps(checks,indent=2)+'\n')
    (review/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Static ocean review</title>
<style>body{background:#111521;color:#eef;font:16px system-ui;max-width:1100px;margin:24px auto;padding:16px}img,video{max-width:100%}h2{margin-top:40px}a{color:#8ce}figure{margin:16px 0}.portrait{max-height:640px}</style>
<h1>Reference-textured ocean — static review</h1><p>Wave animation is disabled. Base colors come from the original video. Visual approval is pending.</p>
<h2>Reference and live scene</h2><img src="comparison.png"><p>The two references depict different video instants. The mesh uses lossless native frame 199. Outer wave bands are separated for later animation.</p>
<h2>Actual production browser handoff</h2><video src="browser-handoff.mp4" controls playsinline loop></video><p>Captured from the exported browser, with original wall-clock timing. No offline video/live compositing.</p>
<h2>Overlap samples</h2><img src="overlap-sheet.png"><h2>Full rotation</h2><img src="rotation-sheet.png">
<h2>Portrait</h2><img class="portrait" src="attract-portrait.png"><h2>Beach close-up</h2><img src="close-beach.png">
<p>Editable source: art/source/island_intro/ocean-color/ocean-color.ora. Faint diffuse water variation remains after the approximate wave separation.</p>
''',encoding='utf-8')
    print('OCEAN_COLOR_REVIEW_PASS',len(checks),'checks; visual approval pending')


if __name__=='__main__':main()
