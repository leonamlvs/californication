// Exported island/water preview. Functional checks only (SwiftShader).
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { createPreviewServer } from './island_video_preview_server.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../build/island-scene-preview');
const output=path.join(root,'web-checks');await fs.mkdir(output,{recursive:true});
const server=createPreviewServer(path.join(root,'web'));
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const url=`http://127.0.0.1:${server.address().port}/index.html`;
const profile=await fs.mkdtemp(path.join(output,'edge-'));
const browser=spawn(process.argv[2]||'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',[
  '--headless=new','--no-first-run','--no-default-browser-check','--remote-debugging-port=0',
  '--disable-extensions','--use-angle=swiftshader','--enable-unsafe-swiftshader',`--user-data-dir=${profile}`,'about:blank'],
  {windowsHide:true,stdio:'ignore'});
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let socket;let id=0;const pending=new Map();const errors=[];const checks=[];
function call(method,params={}){return new Promise((resolve,reject)=>{
  const key=++id;const timer=setTimeout(()=>{pending.delete(key);reject(new Error('CDP timeout '+method));},30000);
  pending.set(key,{resolve:r=>{clearTimeout(timer);resolve(r);},reject:r=>{clearTimeout(timer);reject(r);}});
  socket.send(JSON.stringify({id:key,method,params}));
});}
async function evaluate(expression){const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function wait(expression){for(let i=0;i<600;i++){if(await evaluate(expression))return;await delay(50);}throw new Error('Timeout '+expression);}
const state=()=>evaluate('JSON.parse(window.islandStudy.state)');
const command=value=>evaluate(`window.islandStudy.command(${JSON.stringify(value)})`);
async function capture(name){const r=await call('Page.captureScreenshot',{format:'png'});await fs.writeFile(path.join(output,name+'.png'),Buffer.from(r.data,'base64'));}
function pass(name,details={}){checks.push({name,passed:true,...details});console.log('PASS '+name);}
try{
  let port;
  for(let i=0;i<150;i++){try{port=Number((await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]);break;}catch{await delay(100);}}
  assert.ok(port);
  const target=await(await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'})).json();
  socket=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
  socket.onmessage=event=>{const m=JSON.parse(event.data);if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}
    else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);
    else if(m.method==='Runtime.consoleAPICalled'){const text=m.params.args.map(a=>a.value??a.description??'').join(' ');if(/SCRIPT ERROR|ERROR:|RuntimeError|abort\(/.test(text))errors.push(text);}};
  await call('Runtime.enable');await call('Page.enable');
  await call('Emulation.setDeviceMetricsOverride',{width:960,height:720,deviceScaleFactor:1,mobile:false});
  await call('Page.navigate',{url});await call('Page.bringToFront');
  await wait('window.islandStudy && typeof window.islandStudy.state === "string"');
  await capture('desktop-reveal');
  assert.ok(Math.abs((await state()).size-24)<.001);
  pass('Exported WebGL island imports and reaches measured reveal');
  await command('pullback');await delay(450);await command('pause');await delay(80);
  const paused=await state();assert.ok(paused.time>3.3033);await delay(200);assert.equal((await state()).time,paused.time);
  pass('Pullback advances and pause freezes its clock');
  await command('seek:3.7370666667');await delay(150);
  for(const [width,height] of [[360,640],[844,390],[1280,720]]){
    await call('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await delay(350);
    assert.equal((await state()).time,3.7370666667);
    await capture(`layout-${width}x${height}`);
  }
  pass('Portrait, landscape, and widescreen retain the sampled camera');
  await command('reference');await delay(150);assert.equal((await state()).reference,true);await capture('reference-toggle');
  await command('reference');await command('relief');await delay(150);await capture('relief-toggle');await command('relief');
  pass('Source comparison and relief controls work');
  await command('rotate');await delay(250);const rotating=await state();assert.ok(rotating.time>4.137);assert.ok(Math.abs(rotating.size-25.2)<.001);
  await command('pause');await delay(100);
  assert.deepEqual(errors,[]);
  pass('Rotation retains settled camera with no browser/Godot errors');
  await command('water');await delay(300);const water=await state();
  assert.equal(water.rotation,0);assert.ok(water.water_time>3.737);
  await command('pause');await delay(100);const held=await state();await delay(250);
  assert.equal((await state()).water_time,held.water_time);assert.equal((await state()).wave_phase,held.wave_phase);
  pass('Water-only preview advances, and pause freezes shader phases');
  await command('seek:7.125');await delay(150);const seek=await state();
  await command('seek:86400');await delay(150);assert.equal((await state()).water_time,86400);
  await command('seek:7.125');await delay(150);assert.equal((await state()).wave_phase,seek.wave_phase);
  pass('Seek and day-long attract time remain deterministic');
  await command('water');await delay(150);
  const other=await call('Target.createTarget',{url:'about:blank'});
  await call('Target.activateTarget',{targetId:other.targetId});
  // Godot's render loop and published state stop in a hidden tab.
  await wait('document.hidden');
  const unfocused=await state();await delay(300);
  assert.equal((await state()).water_time,unfocused.water_time);
  await call('Page.bringToFront');await wait('JSON.parse(window.islandStudy.state).focus_active === true');
  await delay(200);const resumed=await state();assert.ok(resumed.water_time>unfocused.water_time);
  assert.ok(resumed.water_time-unfocused.water_time<0.5,'Focus return must not include hidden time');
  await command('pause');await call('Target.closeTarget',{targetId:other.targetId});
  pass('Real browser focus loss holds water and focus return resumes it');
  assert.deepEqual(errors,[]);
  await fs.writeFile(path.join(output,'results.json'),JSON.stringify({status:'ISLAND_SCENE_WEB_PASS',browser:await call('Browser.getVersion'),rendering:'SwiftShader; functional evidence only',checks},null,2));
  console.log('ISLAND_SCENE_WEB_PASS');
}catch(error){await fs.writeFile(path.join(output,'failure.json'),JSON.stringify({error:String(error),checks,errors},null,2));throw error;}
finally{if(socket?.readyState===WebSocket.OPEN){try{await call('Browser.close');}catch{}socket.close();}browser.kill();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
