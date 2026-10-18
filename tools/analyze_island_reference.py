"""Measured V2 source mask and image registration. Run with Blender's Python + NumPy.

OpenCV 4.11.0.86 is installed only under ignored build/island-authoring-deps.
This extracts source pixels; no generative imagery is used.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import math
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/island-authoring-deps'))
import cv2
import numpy as np

OUT = ROOT / 'docs/evidence/island_intro/v2'
SOURCE = ROOT / '.ref/music-video.mp4'
V0 = ROOT / 'docs/evidence/island_intro/v0/reference'


def read_frame(index):
    if index <= 190:
        file, frame = V0 / 'island-intro.mp4', index - 87
    else:
        file, frame = SOURCE, index
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(file), '-vf',
        f'select=eq(n\\,{frame}),crop=960:720:160:0', '-fps_mode', 'passthrough',
        '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'bgr24', 'pipe:1'])
    return np.frombuffer(raw, np.uint8).reshape(720,960,3).copy()


def main():
    (OUT/'reference').mkdir(parents=True,exist_ok=True)
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != 'b09cdb326cf1e62574c3aea75b1be4f599c4b48baf517fb03da25d1886ba366a':
        raise RuntimeError('Unexpected original video')
    frames={i:read_frame(i) for i in range(180,201)}
    ref=frames[199]
    b,g,r=cv2.split(ref.astype(np.float32))
    mask=((r>b*0.86)&(g>b*1.025)&(g>22)).astype(np.uint8)*255
    mask=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((5,5),np.uint8))
    contours,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    contour=max(contours,key=cv2.contourArea)
    mask[:]=0
    cv2.drawContours(mask,[contour],-1,255,-1)
    contour=cv2.approxPolyDP(contour,1.1,True).reshape(-1,2)
    cv2.imwrite(str(OUT/'reference/land-mask.png'),mask)
    annotated=ref.copy()
    cv2.polylines(annotated,[contour],True,(0,0,255),1,cv2.LINE_AA)
    cv2.imwrite(str(OUT/'reference/coastline-trace.png'),annotated)
    # Register adjacent frames to make large total zoom tractable. ECC maps
    # template coordinates to input coordinates. Store the full measured affine
    # and a similarity approximation for the independently authored live camera.
    cumulative=np.eye(3,dtype=np.float64)
    measurements={199:dict(matrix=cumulative[:2].tolist(),correlation=1.0)}
    for i in range(198,179,-1):
        previous=cv2.cvtColor(frames[i+1],cv2.COLOR_BGR2GRAY).astype(np.float32)/255
        current=cv2.cvtColor(frames[i],cv2.COLOR_BGR2GRAY).astype(np.float32)/255
        best=None
        for scale in [1.0,1.15,1.3,1.5,2.0,2.5,3.0,4.0]:
            warp=np.array([[scale,0,510*(1-scale)],[0,scale,510*(1-scale)]],np.float32)
            try:
                score,warp=cv2.findTransformECC(previous,current,warp,cv2.MOTION_AFFINE,
                    (cv2.TERM_CRITERIA_EPS|cv2.TERM_CRITERIA_COUNT,150,1e-6),None,7)
                singular=np.linalg.svd(warp[:,:2],compute_uv=False)
                if np.linalg.det(warp[:,:2])>0 and .8<singular.min()<=singular.max()<5 and singular.max()/singular.min()<1.12:
                    if best is None or score>best[0]: best=(score,warp)
            except cv2.error: pass
        if best is None: raise RuntimeError(f'Camera registration failed at {i}')
        score,warp=best
        cumulative=np.vstack([warp,[0,0,1]]) @ cumulative
        measurements[i]=dict(matrix=cumulative[:2].tolist(),correlation=float(score))
    records=[]
    for i in range(180,200):
        item=measurements[i]
        matrix=np.array(item['matrix'])
        u,s,v=np.linalg.svd(matrix[:,:2]); rotation=u@v
        scale=float(np.mean(s)); center=np.array([480.,360.])
        target=np.linalg.solve(matrix[:,:2],center-matrix[:,2])
        angle=math.atan2(rotation[1,0],rotation[0,0])
        item.update(native_frame=i,intro_seconds=(i-87)*1001/30000,scale=scale,
                    target_pixel=target.tolist(),roll_degrees=math.degrees(angle),singular_values=s.tolist())
        records.append(item)
        cv2.imwrite(str(OUT/f'reference/original_{i:04d}.png'),frames[i])
    data=dict(reference_frame=199,reference_image='docs/evidence/island_intro/v0/reference/original_0199.png',
              method='Adjacent-frame grayscale ECC affine; similarity camera approximation; height/elevation remain authored inferences',
              opencv=cv2.__version__,numpy=np.__version__,coastline=contour.tolist(),measurements=records)
    (OUT/'reference-measurements.json').write_text(json.dumps(data,indent=2)+'\n')
    tiles=[]
    for i in [186,188,190,192,194,196,198,199]:
        tile=cv2.resize(frames[i],(320,240))
        cv2.putText(tile,f'native {i} / {(i-87)*1001/30000:.3f}s',(8,22),cv2.FONT_HERSHEY_SIMPLEX,.55,(255,255,255),1,cv2.LINE_AA)
        tiles.append(tile)
    cv2.imwrite(str(OUT/'reference/pullback-contact-sheet.png'),np.vstack([np.hstack(tiles[:4]),np.hstack(tiles[4:])]))
    print('ISLAND_REFERENCE_ANALYSIS_PASS',[(r['native_frame'],round(r['scale'],3),round(r['correlation'],3)) for r in records])


if __name__=='__main__':main()
