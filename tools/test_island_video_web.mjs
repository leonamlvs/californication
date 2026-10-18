// Real exported Godot preview + browser media integration checks. No autoplay relaxation.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createPreviewServer, defaultRoot } from './island_video_preview_server.mjs';

const output = path.resolve(defaultRoot, '../web-checks');
await fs.mkdir(output, { recursive: true });
const server = createPreviewServer();
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const profile = await fs.mkdtemp(path.join(output, 'edge-'));
const browserPath = process.argv[2] || 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const browser = spawn(browserPath, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0',
  '--disable-extensions', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling',
  `--user-data-dir=${profile}`, 'about:blank'], { windowsHide: true, stdio: 'ignore' });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let socket;
let nextId = 0;
const pending = new Map();
const exceptions = [];
const checks = [];
function call(method, params = {}) {
  const id = ++nextId;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout ${method}`)); }, 30000);
    pending.set(id, { resolve: value => { clearTimeout(timer); resolve(value); }, reject: error => { clearTimeout(timer); reject(error); } });
    socket.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression, userGesture = false) {
  const result = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true, userGesture });
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function waitFor(expression, label, timeout = 25000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const result = await evaluate(expression);
    if (result) return result;
    await delay(35);
  }
  throw new Error(`Timeout ${label}; state=${await evaluate('window.islandPreview?.state')}`);
}
const state = () => evaluate('JSON.parse(window.islandPreview.state)');
const command = value => evaluate(`window.islandPreview.command(${JSON.stringify(value)})`);
async function waitState(value) {
  return waitFor(`window.islandPreview && typeof window.islandPreview.state === 'string' && JSON.parse(window.islandPreview.state).state === ${JSON.stringify(value)}`, value);
}
async function capture(name) {
  const { data } = await call('Page.captureScreenshot', { format: 'png' });
  await fs.writeFile(path.join(output, name + '.png'), Buffer.from(data, 'base64'));
}
async function clickAction() {
  const point = await evaluate(`(() => { const r=document.querySelector('[data-island-video-action]').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}; })()`);
  await call('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...point });
  await call('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...point });
}
async function touchAction() {
  const point = await evaluate(`(() => {const r=document.querySelector('[data-island-video-action]').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
  await call('Emulation.setTouchEmulationEnabled', { enabled: true });
  await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ ...point, id: 1 }] });
  await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await call('Emulation.setTouchEmulationEnabled', { enabled: false });
}
async function reload() {
  await call('Page.navigate', { url: base + '/index.html' });
  await call('Page.bringToFront');
  await waitFor('window.islandPreview && typeof window.islandPreview.state === "string"', 'Godot initialization');
}
function passed(name, details = {}) { checks.push({ name, passed: true, ...details }); console.log('PASS ' + name); }

try {
  const full = await fetch(base + '/index.island-intro.mp4');
  const bytes = Buffer.from(await full.arrayBuffer());
  assert.equal(full.headers.get('content-type'), 'video/mp4');
  assert.equal(createHash('sha256').update(bytes).digest('hex'), '3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866');
  for (const [range, start, end] of [['bytes=0-31', 0, 31], ['bytes=-32', bytes.length - 32, bytes.length - 1], ['bytes=100-', 100, bytes.length - 1]]) {
    const response = await fetch(base + '/index.island-intro.mp4', { headers: { Range: range } });
    assert.equal(response.status, 206);
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), bytes.subarray(start, end + 1));
  }
  assert.equal((await fetch(base + '/index.island-intro.mp4', { headers: { Range: 'bytes=99999999-' } })).status, 416);
  assert.equal((await fetch(base + '/index.island-intro.mp4', { method: 'HEAD' })).headers.get('content-length'), String(bytes.length));
  passed('HTTP video MIME, byte ranges, HEAD, and exact source hash');
  let port;
  for (let attempt = 0; attempt < 150; attempt++) {
    try { port = Number((await fs.readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); break; }
    catch { await delay(100); }
  }
  assert.ok(port, 'Browser did not open debugging port');
  const target = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' })).json();
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  socket.onmessage = event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const promise = pending.get(message.id); pending.delete(message.id);
      if (message.error) promise.reject(new Error(JSON.stringify(message.error))); else promise.resolve(message.result);
    } else if (message.method === 'Runtime.exceptionThrown') exceptions.push(message.params.exceptionDetails);
    else if (message.method === 'Runtime.consoleAPICalled') {
      const text = message.params.args.map(argument => argument.value ?? argument.description ?? '').join(' ');
      if (/SCRIPT ERROR|ERROR:|RuntimeError|abort\(/.test(text)) exceptions.push(text);
    }
  };
  await call('Runtime.enable');
  await call('Page.enable');
  await call('Network.enable');
  await call('Emulation.setDeviceMetricsOverride', { width: 960, height: 720, deviceScaleFactor: 1, mobile: false });
  await reload();
  await waitState('playing');
  const start = await state();
  const wallStart = Date.now();
  await delay(450);
  const after = await state();
  const elapsed = (Date.now() - wallStart) / 1000;
  assert.ok(Math.abs((after.media_time - start.media_time) - elapsed) < 0.15, 'Playback is not at source speed');
  assert.equal(await evaluate('document.querySelector("video").muted && document.querySelector("video").playsInline && !document.querySelector("video").loop'), true);
  passed('Muted inline autoplay at original speed', { observed_seconds: after.media_time - start.media_time, elapsed });
  await command('pause');
  await waitState('paused');
  const paused = await state();
  await delay(250);
  assert.equal((await state()).media_time, paused.media_time);
  await capture('desktop-paused');
  passed('Explicit pause freezes the presented clock');
  for (const [width, height, dpr] of [[360, 640, 1], [844, 390, 2], [1280, 720, 1]]) {
    await call('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: dpr, mobile: false });
    await delay(250);
    const bounds = await evaluate(`(() => {const r=document.querySelector('[data-island-video-layer]').getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height};})()`);
    const scale = Math.min(width / 960, height / 720);
    assert.ok(Math.abs(bounds.w - 960 * scale) < 2 && Math.abs(bounds.h - 720 * scale) < 2, JSON.stringify(bounds));
    assert.ok(Math.abs(bounds.x - (width - bounds.w) / 2) < 2 && Math.abs(bounds.y - (height - bounds.h) / 2) < 2);
    assert.equal((await state()).media_time, paused.media_time);
    await capture(`layout-${width}x${height}-dpr${dpr}`);
    passed(`4:3 layout ${width}x${height} DPR ${dpr}`, bounds);
  }
  await command('opacity_half');
  assert.equal(await evaluate('getComputedStyle(document.querySelector("[data-island-video-layer]")).opacity'), '0.5');
  await command('opacity_full');
  await command('play');
  await waitState('playing');
  await command('focus_out');
  await waitState('paused');
  const focusTime = (await state()).media_time;
  await delay(250);
  assert.equal((await state()).media_time, focusTime);
  await command('focus_in');
  await waitState('playing');
  passed('Host focus pause and resume');
  // A controlled media stall exercises waiting/playing without relying on network timing.
  await evaluate(`(() => {const v=document.querySelector('video');v.pause();v.dispatchEvent(new Event('waiting'));})()`);
  await waitState('buffering');
  const bufferingTime = (await state()).media_time;
  await delay(200);
  assert.equal((await state()).media_time, bufferingTime);
  await evaluate('document.querySelector("video").play()');
  await waitState('playing');
  passed('Injected media stall freezes time and resumes');
  await waitState('ended');
  assert.equal((await state()).completion_count, 1);
  assert.ok(Math.abs((await state()).media_time - 3.470133) < 0.001);
  await capture('ended-retained-frame');
  await command('play');
  await delay(300);
  assert.equal((await state()).completion_count, 1);
  assert.equal((await state()).state, 'ended');
  passed('One-shot completion retains final frame');
  await command('restart');
  await waitState('playing');
  assert.ok((await state()).media_time < 0.5);
  await delay(200);
  await evaluate('document.querySelector("video").dispatchEvent(new Event("error"))');
  await waitState('error');
  assert.equal(await evaluate('document.querySelector("[data-island-video-layer] canvas").style.display'), 'block');
  await capture('failure-retained-frame');
  await clickAction();
  await waitState('playing');
  passed('Mid-play failure retains frame and Retry recovers');
  await command('release');
  await waitState('released');
  assert.equal(await evaluate('document.querySelectorAll("[data-island-video-layer]").length'), 0);
  passed('Release removes media and overlay');

  await reload();
  await waitState('playing');
  const otherTab = await call('Target.createTarget', { url: 'about:blank' });
  await call('Target.activateTarget', { targetId: otherTab.targetId });
  // Godot's render loop is suspended in a hidden tab, so observe native media.
  await waitFor('document.hidden && document.querySelector("video").paused', 'hidden media paused');
  const hiddenTime = await evaluate('document.querySelector("video").currentTime');
  await delay(200);
  assert.equal(await evaluate('document.querySelector("video").currentTime'), hiddenTime);
  await call('Page.bringToFront');
  await waitState('playing');
  await command('pause');
  await waitState('paused');
  await call('Target.closeTarget', { targetId: otherTab.targetId });
  await evaluate('document.documentElement.requestFullscreen()', true);
  await waitFor('!!document.fullscreenElement', 'fullscreen entry');
  await delay(200);
  assert.equal(await evaluate(`(() => {const c=document.querySelector('canvas').getBoundingClientRect(),r=document.querySelector('[data-island-video-layer]').getBoundingClientRect();return Math.abs(r.width/r.height-4/3)<0.01 && r.left>=c.left-1 && r.right<=c.right+1;})()`), true);
  await capture('fullscreen-paused');
  await evaluate('document.exitFullscreen()');
  await waitFor('!document.fullscreenElement', 'fullscreen exit');
  assert.equal((await state()).state, 'paused', 'Manual pause survives focus changes');
  passed('Real tab focus loss/resume and containing-element fullscreen');

  // Deterministically exercise the rejected-play promise; no test hooks in production code.
  const injection = await call('Page.addScriptToEvaluateOnNewDocument', { source: `
    const original = HTMLMediaElement.prototype.play; let rejected = false;
    HTMLMediaElement.prototype.play = function(...args) {
      if (!rejected) {rejected=true;return Promise.reject(new DOMException('Test policy refusal','NotAllowedError'));}
      return original.apply(this,args);
    };` });
  await reload();
  await waitState('gesture_required');
  await capture('gesture-required');
  await evaluate('window.__leaks=0;document.addEventListener("click",()=>window.__leaks++)');
  await clickAction();
  await waitState('playing');
  assert.equal(await evaluate('window.__leaks'), 0);
  passed('Rejected autoplay offers consumed user gesture');
  await call('Page.removeScriptToEvaluateOnNewDocument', { identifier: injection.identifier });
  await call('Network.setBlockedURLs', { urls: ['*index.island-intro.mp4*'] });
  await reload();
  await waitState('error');
  await capture('network-error');
  await call('Network.setBlockedURLs', { urls: [] });
  await evaluate('window.__leaks=0;for(const event of ["click","touchstart","touchend","pointerdown","pointerup"])document.addEventListener(event,()=>window.__leaks++)');
  await touchAction();
  await waitState('playing');
  assert.equal(await evaluate('window.__leaks'), 0);
  passed('Actual blocked network load and consumed touch Retry recovery');
  const fallback = await call('Page.addScriptToEvaluateOnNewDocument', { source: 'HTMLVideoElement.prototype.requestVideoFrameCallback=undefined;' });
  await reload();
  await waitState('playing');
  await delay(250);
  assert.ok((await state()).media_time > 0.1);
  await command('pause');
  await waitState('paused');
  const fallbackTime = (await state()).media_time;
  await delay(150);
  assert.equal((await state()).media_time, fallbackTime);
  passed('currentTime compatibility fallback');
  await call('Page.removeScriptToEvaluateOnNewDocument', { identifier: fallback.identifier });
  assert.deepEqual(exceptions, [], 'Unexpected JavaScript/Godot errors');
  await fs.writeFile(path.join(output, 'results.json'), JSON.stringify({ status: 'ISLAND_VIDEO_WEB_PASS', browser: await call('Browser.getVersion'), rendering: 'SwiftShader; functional checks only', checks }, null, 2));
  console.log('ISLAND_VIDEO_WEB_PASS');
} catch (error) {
  await fs.writeFile(path.join(output, 'failure.json'), JSON.stringify({ error: String(error), checks, exceptions }, null, 2));
  throw error;
} finally {
  if (socket?.readyState === WebSocket.OPEN) { try { await call('Browser.close'); } catch {} socket.close(); }
  browser.kill();
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
}
