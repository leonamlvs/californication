// Dependency-free Chromium/Edge smoke test of the exported game, not a dev build.
// Usage: node tools/smoke_web.mjs [path-to-Chromium-or-Edge]
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const web = path.join(project, 'build', 'web');
const output = path.join(project, 'build', 'rehabilitation', 'browser');
await fs.mkdir(output, { recursive: true });
const profile = await fs.mkdtemp(path.join(output, 'edge-profile-'));
const browserPath = process.argv[2] || 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const messages = [];
const errors = [];
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.pck': 'application/octet-stream' };
const server = http.createServer(async (request, response) => {
  const target = path.resolve(web, '.' + new URL(request.url, 'http://localhost').pathname.replace(/\/$/, '/index.html'));
  if (!target.startsWith(web + path.sep)) { response.writeHead(403).end(); return; }
  try { response.writeHead(200, { 'Content-Type': mime[path.extname(target)] || 'application/octet-stream' }).end(await fs.readFile(target)); }
  catch { response.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = spawn(browserPath, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0', '--disable-extensions', '--use-angle=swiftshader', '--disable-background-timer-throttling', '--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', `--user-data-dir=${profile}`, 'about:blank'], { windowsHide: true, stdio: 'ignore' });
let socket;
let nextId = 0;
const pending = new Map();
async function call(method, params = {}) {
  const id = ++nextId;
  const result = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 60000);
    pending.set(id, { resolve: value => { clearTimeout(timeout); resolve(value); }, reject: error => { clearTimeout(timeout); reject(error); } });
  });
  socket.send(JSON.stringify({ id, method, params }));
  return result;
}
async function key(key, code = key, virtual = key.charCodeAt(0)) {
  await call('Input.dispatchKeyEvent', { type: 'keyDown', key, code, windowsVirtualKeyCode: virtual });
  await delay(60);
  await call('Input.dispatchKeyEvent', { type: 'keyUp', key, code, windowsVirtualKeyCode: virtual });
}
async function swipe(fromX, fromY, toX, toY) {
  await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: fromX, y: fromY, id: 1 }] });
  await delay(80);
  await call('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: toX, y: toY, id: 1 }] });
  await delay(80);
  await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}
async function capture(name) {
  const { data } = await call('Page.captureScreenshot', { format: 'png' });
  await fs.writeFile(path.join(output, `${name}.png`), Buffer.from(data, 'base64'));
  console.log(`CAPTURE ${name}`);
}
try {
  let port;
  for (let attempt = 0; attempt < 100; attempt++) {
    try { port = Number((await fs.readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); break; }
    catch { await delay(100); }
  }
  if (!port) throw new Error('Browser debugging endpoint did not start');
  const target = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' })).json();
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  socket.onmessage = event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const promise = pending.get(message.id); pending.delete(message.id);
      if (message.error) promise.reject(new Error(JSON.stringify(message.error))); else promise.resolve(message.result);
    } else if (message.method === 'Runtime.consoleAPICalled') {
      const text = message.params.args.map(argument => argument.value ?? argument.description ?? '').join(' ');
      messages.push(text);
      if (/SCRIPT ERROR|ERROR:|abort\(|RuntimeError/.test(text)) errors.push(text);
    } else if (message.method === 'Runtime.exceptionThrown') errors.push(JSON.stringify(message.params.exceptionDetails));
  };
  await call('Runtime.enable');
  await call('Page.enable');
  await call('Emulation.setDeviceMetricsOverride', { width: 960, height: 720, deviceScaleFactor: 1, mobile: false });
  await call('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
  await call('Page.navigate', { url: `http://127.0.0.1:${server.address().port}/index.html` });
  console.log('Web page committed; waiting for engine initialization');
  let started = false;
  for (let attempt = 0; attempt < 120; attempt++) {
    const result = await call('Runtime.evaluate', { expression: '!!document.querySelector("canvas") && !document.getElementById("status")', returnByValue: true });
    if (result.result.value) { started = true; break; }
    await delay(250);
  }
  if (!started) throw new Error('Web engine failed to finish initialization');
  await call('Runtime.evaluate', { expression: 'document.querySelector("canvas").focus()' });
  await delay(9500);
  await capture('01-attract');
  await key('Enter', 'Enter', 13);
  await delay(8000);
  await capture('02-player-select');
  await key('Enter', 'Enter', 13);
  await delay(1900);
  await capture('03-running');
  await swipe(480, 560, 610, 560);
  await delay(250);
  await capture('03-touch-swipe');
  await key('p', 'KeyP', 80);
  await delay(250);
  await capture('04-pause');
  for (const [width, height] of [[844, 390], [360, 640]]) {
    await call('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
    await delay(300);
    await capture(`05-resize-${width}x${height}`);
  }
  await key('p', 'KeyP', 80);
  await delay(5200);
  await capture('06-game-over');
  await key('Enter', 'Enter', 13);
  await delay(1900);
  await capture('07-retry');
  await delay(5500);
  await key('ArrowDown', 'ArrowDown', 40);
  await key('Enter', 'Enter', 13);
  await delay(500);
  await capture('08-island-return');
  await fs.writeFile(path.join(output, 'console.json'), JSON.stringify({ messages, errors }, null, 2));
  if (errors.length) throw new Error(`Browser runtime errors: ${errors.join('\n')}`);
  console.log('WEB_RUNTIME_NO_ERRORS: review captured frames for state and composition acceptance');
} finally {
  await fs.writeFile(path.join(output, 'console.json'), JSON.stringify({ messages, errors }, null, 2));
  if (socket?.readyState === WebSocket.OPEN) {
    try { await call('Browser.close'); } catch { /* Browser can close before replying. */ }
    socket.close();
  }
  browser.kill();
  server.close();
}
