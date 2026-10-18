"""Encode actual exported-browser V4 screencast and compact overlap evidence.

Run through Blender for local NumPy/OpenCV, after the browser suite.
"""
from pathlib import Path
import sys,json,subprocess,shutil,hashlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/island-authoring-deps'))
import cv2
import numpy as np
BUILD=ROOT/'build/island-transition-preview'
OUT=ROOT/'docs/evidence/island_intro/v4'


def main():
    review=OUT/'review';review.mkdir(parents=True,exist_ok=True)
    recording=json.loads((BUILD/'browser/recording.json').read_text())
    trace=recording['trace'];start=next(i for i,s in enumerate(trace) if s['time']<.1)
    trace=trace[start:];wall_start=trace[0]['wall']/1000
    frames=[f for f in recording['frames'] if f['timestamp']>=wall_start]
    assert len(frames)>30
    lines=['ffconcat version 1.0']
    for i,frame in enumerate(frames):
        duration=frames[i+1]['timestamp']-frame['timestamp'] if i+1<len(frames) else 1/60
        assert duration>0
        lines += ["file '"+frame['name']+"'",f'duration {duration:.9f}']
    lines += ["file '"+frames[-1]['name']+"'"]
    concat=BUILD/'browser/recording.ffconcat';concat.write_text('\n'.join(lines)+'\n')
    command=['ffmpeg','-v','error','-y','-safe','0','-f','concat','-i',str(concat),'-vf','fps=30',
             '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(review/'browser-handoff.mp4')]
    subprocess.run(command,check=True)
    panels=[];samples=[]
    for target in [3.3033,3.3700333,3.4367667,3.4701333,3.5035,3.57,3.7370667,4.1370667]:
        state=min(trace,key=lambda s:abs(s['time']-target))
        frame=min(frames,key=lambda f:abs(f['timestamp']-state['wall']/1000))
        picture=cv2.imread(str(BUILD/'browser'/frame['name']));assert picture is not None
        name=f'overlap-{target:.3f}.png';cv2.imwrite(str(review/name),picture)
        mean=float(picture.mean());assert mean>5,'Black capture near handoff'
        panel=cv2.resize(picture,(480,360));cv2.rectangle(panel,(0,0),(480,28),(15,18,26),-1)
        cv2.putText(panel,f'{state["time"]:.3f}s / video {state["opacity"]:.2f}',(8,20),cv2.FONT_HERSHEY_SIMPLEX,.5,(255,255,255),1,cv2.LINE_AA)
        panels.append(panel);samples.append(dict(target=target,time=state['time'],opacity=state['opacity'],camera_size=state['camera_size'],blur=state['blur'],frame=frame['name'],image=name,mean_rgb=mean))
    cv2.imwrite(str(review/'overlap-sheet.png'),np.vstack([np.hstack(panels[i:i+2]) for i in range(0,8,2)]))
    metrics={}
    for name,lo,hi in [('overlap',3.3033,3.470134),('attract',4.5,7.0)]:
        times=np.array([s['wall'] for s in trace if lo<=s['time']<=hi])
        intervals=np.diff(times)
        metrics[name]=dict(samples=len(times),median_raf_interval_ms=float(np.median(intervals)),p95_raf_interval_ms=float(np.percentile(intervals,95)))
    (OUT/'recording-metadata.json').write_text(json.dumps(dict(renderer=recording['renderer'],frames=len(frames),duration_seconds=frames[-1]['timestamp']-frames[0]['timestamp'],samples=samples,cadence=metrics,
        caveat='Actual browser screencast, not offline video/live compositing. rAF cadence includes screencast overhead and is not GPU frame-time or V6 device acceptance. Visual review 2 pending.',command=command),indent=2)+'\n')
    (review/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Island V4 — Video to island review</title><style>body{margin:0;background:#0c1220;color:#e9eef8;font:16px/1.55 system-ui}main{max-width:1000px;margin:auto;padding:28px}h1{line-height:1.15}a{color:#88d2ff}video,img{max-width:100%;height:auto;background:#000}h2{margin-top:32px}</style>
<main><h1>Video to island — V4 visual review</h1><p>Review 2 is pending your approval. Watch the pullback at normal speed first, then inspect the overlap frames below.</p>
<p><a href="../index.html">Open interactive preview</a> · <a href="browser-handoff.mp4">Open recording</a></p>
<video controls muted playsinline preload="metadata" src="browser-handoff.mp4"></video>
<p>This is a recording of the exported browser preview: the original HTML video, blended live Godot island, live-only radial blur, and animated water. No offline substitution or compositing was used.</p>
<h2>Across the handoff</h2><img src="overlap-sheet.png" alt="Eight recorded frames spanning the video/live overlap and camera settle">
<h2>Review scope</h2><p>Please assess whether the pullback feels continuous: no visible cut, doubled coastline, exposure jump, scale jump, or camera reset. The live terrain, water, and blur approximate the reference; the recording does not establish visual approval automatically.</p>
<p>The interactive preview includes Pause, Play, Replay, Attract, and Fullscreen. Production loading and frontend integration remain V5. Hardware phone performance and visual review 3 remain V6.</p></main></html>''',encoding='utf-8')
    shutil.copytree(review,BUILD/'web/review',dirs_exist_ok=True)
    print('ISLAND_HANDOFF_REVIEW_READY',len(frames),'browser frames; visual approval pending')


if __name__=='__main__': main()
