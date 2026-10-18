// Actual exported V4 preview, real HTML video, CDP recording and interruptions.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import {createPreviewServer} from './island_video_preview_server.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../build/island-transition-preview');
const out=path.join(root,'browser');await fs.mkdir(out,{recursive:true});
const server=createPreviewServer(path.join(root,'web'));await new Promise(r=>server.listen(0,'127.0.0.1',r));
const url=`http://127.0.0.1:${server.address().port}/index.html?capture=1`;
const profile=await fs.mkdtemp(path.join(out,'edge-'));
const browser=spawn('C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',[
 '--headless=new','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--disable-extensions',
 ...(process.argv.includes('--software')?['--use-angle=swiftshader','--enable-unsafe-swiftshader']:[]),
 `--user-data-dir=${profile}`,'about:blank'],{windowsHide:true,stdio:'ignore'});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let socket,id=0,recording=false;const pending=new Map(),errors=[],checks=[],frames=[],writes=[];
function call(method,params={}){return new Promise((resolve,reject)=>{
 const key=++id,timer=setTimeout(()=>{pending.delete(key);reject(new Error('CDP timeout '+method));},30000);
 pending.set(key,{resolve:r=>{clearTimeout(timer);resolve(r);},reject:e=>{clearTimeout(timer);reject(e);}});
 socket.send(JSON.stringify({id:key,method,params}));
});}
async function evaluate(expression,userGesture=false){const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true,userGesture});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function wait(expression,timeout=30000){const start=Date.now();while(Date.now()-start<timeout){if(await evaluate(expression))return;await delay(25);}throw Error('Timeout '+expression);}
const state=()=>evaluate('JSON.parse(window.islandTransition.state)');
const command=c=>evaluate(`window.islandTransition.command(${JSON.stringify(c)})`);
async function screenshot(name){const r=await call('Page.captureScreenshot',{format:'png'});await fs.writeFile(path.join(out,name+'.png'),Buffer.from(r.data,'base64'));}
function pass(name,details={}){checks.push({name,passed:true,...details});console.log('PASS '+name);}
async function holdBlend(){
 await evaluate(`window.holdDone=false;window.holdTimer=setInterval(()=>{const s=JSON.parse(window.islandTransition.state);if(s.time>=3.32 && s.time<3.47){clearInterval(window.holdTimer);window.islandTransition.command('pause');window.holdDone=true;}},4)`);
 await command('restart');await wait('window.holdDone');await delay(80);
 const s=await state();assert.ok(s.time>=3.3033&&s.time<3.470134);return s;
}
try{
 let port;for(let i=0;i<150;i++){try{port=Number((await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]);break;}catch{await delay(100);}}
 assert.ok(port);
 const target=await(await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'})).json();
 socket=new WebSocket(target.webSocketDebuggerUrl);await new Promise((r,j)=>{socket.onopen=r;socket.onerror=j;});
 socket.onmessage=event=>{const m=JSON.parse(event.data);
  if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}
  else if(m.method==='Page.screencastFrame'){
   if(recording){const name=`record_${String(frames.length).padStart(5,'0')}.jpg`;frames.push({name,timestamp:m.params.metadata.timestamp});writes.push(fs.writeFile(path.join(out,name),Buffer.from(m.params.data,'base64')));}
   call('Page.screencastFrameAck',{sessionId:m.params.sessionId}).catch(()=>{});
  } else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);
  else if(m.method==='Runtime.consoleAPICalled'){const s=m.params.args.map(a=>a.value??a.description??'').join(' ');if(/SCRIPT ERROR|ERROR:|RuntimeError|abort\(/.test(s))errors.push(s);}
 };
 await call('Runtime.enable');await call('Page.enable');
 await call('Emulation.setDeviceMetricsOverride',{width:960,height:720,deviceScaleFactor:1,mobile:false});
 await call('Page.navigate',{url});await call('Page.bringToFront');
 await wait('window.islandTransition && typeof window.islandTransition.state === "string"');
 await wait('JSON.parse(window.islandTransition.state).time>4.5');
 assert.equal(await evaluate('document.querySelectorAll("video").length'),0);
 assert.ok(Math.abs((await state()).camera_size-25.2)<.0001);
 const renderer=await evaluate(`(()=>{const c=document.querySelector('canvas'),g=c.getContext('webgl2')||c.getContext('webgl'),e=g.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER);})()`);
 pass('Clip completes into attract and releases native video',{renderer});
 await evaluate(`window.transitionTrace=[];window.traceActive=true;function recordTrace(now){if(!window.traceActive)return;const s=JSON.parse(window.islandTransition.state);window.transitionTrace.push({wall:performance.timeOrigin+now,...s});requestAnimationFrame(recordTrace);}requestAnimationFrame(recordTrace);`);
 recording=true;await call('Page.startScreencast',{format:'jpeg',quality:90,maxWidth:960,maxHeight:720,everyNthFrame:1});
 await command('restart');await wait('JSON.parse(window.islandTransition.state).time<1');
 await wait('JSON.parse(window.islandTransition.state).time>7');
 recording=false;await call('Page.stopScreencast');await Promise.all(writes);
 await evaluate('window.traceActive=false');const trace=await evaluate('window.transitionTrace');
 await fs.writeFile(path.join(out,'recording.json'),JSON.stringify({frames,trace,renderer},null,2));
 assert.ok(frames.length>30);
 const overlap=trace.filter(s=>s.time>=3.3033&&s.time<3.470134);
 assert.ok(overlap.length>0);assert.ok(overlap.some(s=>s.opacity>0&&s.opacity<1));
 assert.ok(overlap.every(s=>Math.abs(s.time-s.water_time)<1e-7));
 assert.ok(trace.filter(s=>s.time>=4.1371).every(s=>s.blur===0&&Math.abs(s.camera_size-25.2)<.0001));
 pass('Actual browser video/live sequence recorded with synchronized overlap',{frames:frames.length,overlap_samples:overlap.length});
 const held=await holdBlend();await screenshot('held-blend');await delay(250);
 assert.equal((await state()).time,held.time);assert.equal((await state()).blur,held.blur);
 pass('Pause holds video, camera, water, opacity, and live blur during overlap');
 for(const [width,height] of [[360,640],[844,390],[1280,720]]){
  await call('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await delay(120);
  assert.equal((await state()).time,held.time);
  const alignment=await evaluate(`(()=>{const c=document.querySelector('canvas').getBoundingClientRect(),v=document.querySelector('[data-island-video-layer]').getBoundingClientRect();return {ratio:v.width/v.height,x:v.x-c.x,y:v.y-c.y,w:v.width,h:v.height,cw:c.width,ch:c.height};})()`);
  assert.ok(Math.abs(alignment.ratio-4/3)<.001);assert.ok(Math.abs(alignment.x-(alignment.cw-alignment.w)/2)<1);assert.ok(Math.abs(alignment.y-(alignment.ch-alignment.h)/2)<1);
  await screenshot(`overlap-${width}x${height}`);
 }
 pass('Paused overlap keeps shared centered 4:3 through orientation/resize');
 await evaluate('document.documentElement.requestFullscreen()',true);await wait('!!document.fullscreenElement');await delay(120);
 assert.equal((await state()).time,held.time);assert.ok((await state()).blur>0);
 assert.ok(await evaluate(`(()=>{const c=document.querySelector('canvas').getBoundingClientRect(),r=document.querySelector('[data-island-video-layer]').getBoundingClientRect();return Math.abs(r.width/r.height-4/3)<.001&&r.left>=c.left-1&&r.right<=c.right+1;})()`));
 await screenshot('overlap-fullscreen');await evaluate('document.exitFullscreen()');await wait('!document.fullscreenElement');
 pass('Containing-element fullscreen keeps video/live framing and held blur');
 await call('Emulation.setDeviceMetricsOverride',{width:960,height:720,deviceScaleFactor:1,mobile:false});
 await command('play');
 await evaluate(`const v=document.querySelector('video');v.pause();v.dispatchEvent(new Event('waiting'));`);
 await delay(100);const stall=await state();await delay(200);assert.equal((await state()).time,stall.time);assert.equal((await state()).video.state,'buffering');
 await evaluate('document.querySelector("video").play()');await wait('JSON.parse(window.islandTransition.state).time>4.5');
 pass('Buffering freezes the coordinated presentation and resumes to attract');
 await holdBlend();await command('play');
 const other=await call('Target.createTarget',{url:'about:blank'});await call('Target.activateTarget',{targetId:other.targetId});
 await wait('document.hidden');const hidden=await state();await delay(500);assert.equal((await state()).time,hidden.time);
 await call('Page.bringToFront');await wait('JSON.parse(window.islandTransition.state).time>4.5');await call('Target.closeTarget',{targetId:other.targetId});
 pass('Real tab focus loss during handoff freezes and resumes safely');
 await holdBlend();await evaluate(`document.querySelector('video').dispatchEvent(new Event('error'))`);await delay(100);
 assert.equal((await state()).video.state,'error');const failure=await state();await delay(150);assert.equal((await state()).time,failure.time);
 assert.equal(await evaluate('document.querySelector("[data-island-video-action]").hidden'),false);await screenshot('retained-error');
 await evaluate('document.querySelector("[data-island-video-action]").click()');await wait('JSON.parse(window.islandTransition.state).time<1');
 await wait('JSON.parse(window.islandTransition.state).time>4.5');pass('Failure retains blend and Retry restarts the coordinated clock');
 await evaluate(`window.savedPlay=HTMLMediaElement.prototype.play;HTMLMediaElement.prototype.play=function(){return Promise.reject(new DOMException('Test gesture requirement','NotAllowedError'));};`);
 await command('restart');await wait('JSON.parse(window.islandTransition.state).video.state === "gesture_required"');
 assert.equal((await state()).time,0);await screenshot('gesture-poster');
 await evaluate(`HTMLMediaElement.prototype.play=window.savedPlay;document.querySelector('[data-island-video-action]').click();`);
 await wait('JSON.parse(window.islandTransition.state).time>4.5');pass('Rejected autoplay keeps poster; start action resumes');
 await command('attract');await delay(200);const a=await state();await delay(250);const b=await state();
 assert.ok(b.rotation>a.rotation);assert.ok(Math.abs(b.camera_size-25.2)<.0001);assert.equal(b.video.state,'released');
 pass('Direct attract keeps final camera and indefinite rotation');
 await call('Page.addScriptToEvaluateOnNewDocument',{source:"Object.defineProperty(HTMLVideoElement.prototype,'requestVideoFrameCallback',{value:undefined,configurable:true});"});
 await call('Page.reload');await wait('window.islandTransition && typeof window.islandTransition.state === "string"');
 await wait('JSON.parse(window.islandTransition.state).time>4.5');
 assert.equal(await evaluate('typeof HTMLVideoElement.prototype.requestVideoFrameCallback'),'undefined');
 assert.equal((await state()).video.state,'released');assert.ok(Math.abs((await state()).camera_size-25.2)<.0001);
 pass('currentTime fallback completes the coordinated video/live handoff');
 const bytes=await fs.readFile(path.join(root,'web/index.island-intro.mp4'));
 assert.equal(createHash('sha256').update(bytes).digest('hex'),'3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866');
 const range=await fetch(url.replace('index.html?capture=1','index.island-intro.mp4'),{headers:{Range:'bytes=0-31'}});assert.equal(range.status,206);assert.equal((await range.arrayBuffer()).byteLength,32);
 assert.deepEqual(errors,[]);pass('Exact companion video, byte ranges, and no browser/Godot errors');
 await fs.writeFile(path.join(out,'results.json'),JSON.stringify({status:'ISLAND_HANDOFF_WEB_PASS',renderer,browser:await call('Browser.getVersion'),checks},null,2));
}catch(error){await fs.writeFile(path.join(out,'failure.json'),JSON.stringify({error:String(error),errors,checks},null,2));throw error;}
finally{if(socket?.readyState===WebSocket.OPEN){try{await call('Browser.close');}catch{}socket.close();}browser.kill();server.closeAllConnections();await new Promise(r=>server.close(r));}
