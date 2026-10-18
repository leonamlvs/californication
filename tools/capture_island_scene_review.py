"""Build durable V2 review artifacts from native captures, using Blender + OpenCV."""
from pathlib import Path
import sys,json,subprocess,shutil
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/island-authoring-deps'))
import cv2
import numpy as np
OUT=ROOT/'docs/evidence/island_intro/v2'
REVIEW=OUT/'review'
CAPTURES=ROOT/'build/island-scene-preview/captures'


def label(image,text):
    result=image.copy()
    cv2.rectangle(result,(0,0),(result.shape[1],32),(16,19,26),-1)
    cv2.putText(result,text,(10,23),cv2.FONT_HERSHEY_SIMPLEX,.65,(245,245,245),1,cv2.LINE_AA)
    return result


def main():
    REVIEW.mkdir(parents=True,exist_ok=True)
    ref=cv2.imread(str(ROOT/'docs/evidence/island_intro/v0/reference/original_0199.png'))
    live=cv2.imread(str(CAPTURES/'live_0199.png'))
    mask=cv2.imread(str(OUT/'reference/land-mask.png'),cv2.IMREAD_GRAYSCALE)>0
    diff=np.abs(ref.astype(float)-live.astype(float))
    cv2.imwrite(str(REVIEW/'reference.png'),ref)
    cv2.imwrite(str(REVIEW/'live.png'),live)
    cv2.imwrite(str(REVIEW/'reveal-comparison.png'),np.hstack([label(ref,'REFERENCE / native frame 199'),label(live,'LIVE 3D / same camera sample')]))
    panels=[]
    for index in [186,190,193,196,199]:
        source=cv2.imread(str(OUT/f'reference/original_{index:04d}.png'))
        rendered=cv2.imread(str(CAPTURES/f'live_{index:04d}.png'))
        comparison=np.hstack([label(source,f'REFERENCE {index}'),label(rendered,f'LIVE {index} / V2, no added blur')])
        cv2.imwrite(str(REVIEW/f'frame-{index}.png'),comparison)
        panels.append(cv2.resize(comparison,(960,360)))
    cv2.imwrite(str(REVIEW/'pullback-comparison.png'),np.vstack(panels))
    rotations=[]
    for angle in [0,45,90,135,180,225,270,315]:
        img=cv2.imread(str(CAPTURES/f'rotation_{angle:03d}.png'))
        rotations.append(label(cv2.resize(img,(320,240)),f'{angle} degrees'))
    cv2.imwrite(str(REVIEW/'rotation-sheet.png'),np.vstack([np.hstack(rotations[:4]),np.hstack(rotations[4:])]))
    shutil.copyfile(CAPTURES/'relief-oblique.png',REVIEW/'relief-oblique.png')
    metrics=dict(reference_frame=199,land_color_mean_absolute_error_rgb=float(diff[mask].mean()),
        full_picture_mean_absolute_error_rgb=float(diff.mean()),
        warning='Reference-projected color and static reference water make these match metrics expected; they do not establish recovered 3D geometry or seamless motion.',
        visual_approval='PENDING USER REVIEW')
    (OUT/'comparison-metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    command=['ffmpeg','-v','error','-y','-framerate','30','-i',str(CAPTURES/'preview_%04d.png'),'-frames:v','150',
        '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(REVIEW/'camera-preview.mp4')]
    subprocess.run(command,check=True)
    (OUT/'review-commands.json').write_text(json.dumps([command],indent=2)+'\n')
    (REVIEW/'index.html').write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Island V2 — Visual review 1</title>
<style>body{margin:0;background:#0c1220;color:#e9eef8;font:16px/1.55 system-ui}main{max-width:1120px;margin:auto;padding:28px}h1{line-height:1.15}h2{margin-top:38px}a{color:#88d2ff}img,video{max-width:100%;height:auto;background:#000}figure{margin:18px 0}figcaption{color:#aebbd0;font-size:14px}button{padding:8px 18px;margin-bottom:10px;background:#25446e;color:white;border:1px solid #83bce8;border-radius:5px}.compare{position:relative;max-width:960px}.compare img{display:block}.compare #live{position:absolute;inset:0;width:100%}input{width:min(960px,100%)}</style>
<main><h1>Island intro — V2 visual review</h1>
<p>Editable 3D terrain, reference color atlas, static ocean, and measured camera continuation. Review 1 is pending your approval.</p>
<p><a href="../index.html">Open interactive Godot study</a> · <a href="camera-preview.mp4">Camera preview video</a></p>
<h2>Full reveal: source and live</h2><p>Move the slider to compare the same frame. The live island has actual terrain relief; color and lighting are projected from the supplied footage.</p>
<div class="compare"><img src="reference.png" alt="Original source frame 199"><img id="live" src="live.png" alt="Live 3D at the corresponding camera pose"></div>
<input type="range" min="0" max="1" step="0.01" value="1" aria-label="Live image opacity" oninput="document.getElementById('live').style.opacity=this.value">
<p>Left: source only. Right: live only.</p>
<h2>Camera continuation</h2><video controls muted playsinline preload="metadata" src="camera-preview.mp4"></video>
<p>The preview starts at the planned overlap time, 3.3033 s, then settles and rotates. V4 supplies the video blend and live radial blur. V2 adds no runtime blur; the source-derived atlas retains some source softness and streaking.</p>
<figure><img src="pullback-comparison.png" alt="Five source and live pullback samples"><figcaption>Source on left; live study on right. Early close-up coastline and texture seams remain visible without V4 blur and require inspection during that milestone.</figcaption></figure>
<h2>Rotation and mesh</h2><figure><img src="rotation-sheet.png" alt="Eight angles of the live island"><figcaption>The source does not establish hidden slopes uniquely. Relief heights and unseen surfaces are editable estimates.</figcaption></figure>
<figure><img src="relief-oblique.png" alt="Untextured terrain from an oblique camera"><figcaption>Clay inspection of the actual island mesh. All water is a separate flat plane.</figcaption></figure>
<h2>Review scope</h2><p>Please assess silhouette, mountain placement, coast, color, and composition. The ocean currently uses a frozen reference color plate; its waves and world-anchored deep-water pattern are V3. Production loading is unchanged. This preview does not establish seamless-transition approval or physical-phone performance.</p></main></html>''',encoding='utf-8')
    destination=ROOT/'build/island-scene-preview/web/review'
    shutil.copytree(REVIEW,destination,dirs_exist_ok=True)
    print('ISLAND_SCENE_REVIEW_READY',metrics)


if __name__=='__main__':main()
