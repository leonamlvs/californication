"""Validate native ocean pixels and save compact V3 review evidence (Blender + OpenCV)."""
from pathlib import Path
import sys, json, shutil, subprocess
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/island-authoring-deps'))
import cv2
import numpy as np
OUT=ROOT/'docs/evidence/island_intro/v3'
CAPTURES=ROOT/'build/island-scene-preview/ocean-captures'


def read(name):
    image=cv2.imread(str(CAPTURES/(name+'.png')))
    if image is None: raise RuntimeError('Missing capture '+name)
    return image


def difference(a,b):
    delta=np.abs(a.astype(float)-b.astype(float))
    return dict(mean=float(delta.mean()),maximum=float(delta.max()),changed_pixels=int(np.any(delta>0,axis=2).sum()))


def main():
    review=OUT/'review'; review.mkdir(parents=True,exist_ok=True)
    checks=[]
    def check(name,condition,**details):
        checks.append(dict(name=name,passed=bool(condition),**details))
        if not condition: raise RuntimeError(name+' '+str(details))
    first=read('reveal');repeat=read('repeat');later=read('later')
    diff=difference(first,repeat)
    check('Same water time reproduces identical native pixels',diff['maximum']==0,**diff)
    diff=difference(first,later)
    check('Water visibly changes with controller time',diff['changed_pixels']>15000,**diff)
    for kind in ['wave','ripple']:
        diff=difference(read(kind+'-wrap-before'),read(kind+'-wrap-after'))
        check(kind+' phase wrap is visually continuous',diff['mean']<.08 and diff['maximum']<=4,**diff)
    zero=read('rotation_000')
    corner=np.zeros(zero.shape[:2],bool)
    for y,x in [(20,20),(20,880),(640,20),(640,880)]:corner[y:y+40,x:x+40]=True
    for angle in range(45,361,45):
        rotated=read('rotation_%03d'%angle)
        delta=np.abs(zero.astype(float)-rotated.astype(float))[corner]
        check('World ocean stays fixed at %d degrees'%angle,float(delta.max())==0,maximum=float(delta.max()))
    diff=difference(zero,read('rotation_360'))
    check('Full rotation returns to matching shore pixels',diff['mean']<.01,**diff)
    max_step=0.0
    previous=read('water_0000')
    for i in range(1,150):
        current=read('water_%04d'%i)
        max_step=max(max_step,difference(current,previous)['mean']);previous=current
    check('Consecutive 30fps water samples have no jump',max_step<.25,maximum_frame_mean_delta=max_step)
    # Map border is an invariant, not a subjective seam threshold.
    data=cv2.imread(str(ROOT/'dev/island_scene/assets/ocean-shore.png'),cv2.IMREAD_UNCHANGED)
    edge=np.concatenate([data[0],data[-1],data[:,0],data[:,-1]])
    check('Packed shore border is constant deep water',np.all(edge[:,2]==255) and np.all(edge[:,1]==0) and np.all(edge[:,3]==0))
    noise=cv2.imread(str(ROOT/'dev/island_scene/assets/ocean-ripple.png'),cv2.IMREAD_GRAYSCALE).astype(float)
    internal=np.concatenate([np.diff(noise,axis=0).ravel(),np.diff(noise,axis=1).ravel()])
    seam=np.concatenate([noise[0]-noise[-1],noise[:,0]-noise[:,-1]])
    check('Periodic noise boundary has no exceptional derivative',np.abs(seam).max()<=np.abs(internal).max()+1,
          seam_max=float(np.abs(seam).max()),internal_max=float(np.abs(internal).max()))
    (OUT/'render-checks.json').write_text(json.dumps(dict(status='ISLAND_OCEAN_RENDER_PASS',checks=checks),indent=2)+'\n')
    for name in ['reveal','later','long-wait','wave-wrap-before','wave-wrap-after','ripple-wrap-before','ripple-wrap-after']:
        shutil.copyfile(CAPTURES/(name+'.png'),review/(name+'.png'))
    panels=[]
    for angle in range(0,360,45):
        img=cv2.resize(read('rotation_%03d'%angle),(320,240))
        cv2.putText(img,str(angle)+' degrees',(8,22),cv2.FONT_HERSHEY_SIMPLEX,.55,(255,255,255),1,cv2.LINE_AA)
        panels.append(img)
    cv2.imwrite(str(review/'rotation-sheet.png'),np.vstack([np.hstack(panels[:4]),np.hstack(panels[4:])]))
    source=cv2.imread(str(ROOT/'docs/evidence/island_intro/v0/reference/original_0199.png'))
    cv2.imwrite(str(review/'source-and-water.png'),np.hstack([source,first]))
    commands=[]
    for prefix,fps,count,name in [('water',30,150,'water-preview'),('turn',5,361,'full-rotation')]:
        command=['ffmpeg','-v','error','-y','-framerate',str(fps),'-i',str(CAPTURES/(prefix+'_%04d.png')),
                 '-frames:v',str(count),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(review/(name+'.mp4'))]
        subprocess.run(command,check=True);commands.append(command)
    (OUT/'review-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    (review/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Island V3 — Animated water</title><style>body{margin:0;background:#0c1220;color:#e9eef8;font:16px/1.55 system-ui}main{max-width:1120px;margin:auto;padding:28px}h1{line-height:1.15}h2{margin-top:36px}a{color:#88d2ff}img,video{max-width:100%;height:auto;background:#000}figure{margin:18px 0}small{color:#afbdd0}</style>
<main><h1>Island V3 — Animated water</h1><p>Subtle shore waves follow the rotating coast. Deep-water ripples stay anchored to the surrounding sea.</p>
<p><a href="../index.html">Open interactive preview</a> · Use <b>Water</b> for a stationary island, <b>Rotate</b> for attract, and <b>Pause</b> to hold the same water phase.</p>
<h2>Water motion at normal speed</h2><video controls muted playsinline loop preload="metadata" src="water-preview.mp4"></video>
<p>The camera is held still to make the faint waves easier to inspect. The five-second review video loops; the live water clock continues indefinitely.</p>
<h2>Complete island rotation</h2><video controls muted playsinline preload="metadata" src="full-rotation.mp4"></video><p>One full 72-second turn. This inspection recording samples at 5 fps; it is not a performance measurement.</p>
<img src="rotation-sheet.png" alt="Coastline and water at eight rotation angles">
<h2>Reference and animated reconstruction</h2><img src="source-and-water.png" alt="Original frame on left, live water on right"><p>Reference on the left; live rendering on the right. The cyan shape is derived from the reference. Wave shape, timing, and deep-water noise are authored approximations; the original frozen outer wave rings are replaced by animated shading.</p>
<h2>Scope and checks</h2><p>One opaque plane, two triangles, one material, a 1024-square packed data map, and a 256-square periodic noise texture. Pause/seek, phase wraps, world anchoring, full rotation, browser focus, and package isolation are checked. V2 terrain and camera approval is recorded. Seamless video blending is V4; production integration is V5; phone performance remains V6.</p></main></html>''',encoding='utf-8')
    shutil.copytree(review,ROOT/'build/island-scene-preview/web/water-review',dirs_exist_ok=True)
    print('ISLAND_OCEAN_RENDER_PASS',len(checks),'checks; review ready')


if __name__=='__main__': main()
