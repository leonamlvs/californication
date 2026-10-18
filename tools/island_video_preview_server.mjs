import http from 'node:http';
import https from 'node:https';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const defaultRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/island-video-preview/web');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.pck': 'application/octet-stream', '.mp4': 'video/mp4' };

export function createPreviewServer(root = defaultRoot, tls = null) {
  const directory = path.resolve(root);
  const handler = async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      const target = path.resolve(directory, '.' + (pathname.endsWith('/') ? pathname + 'index.html' : pathname));
      if (!target.startsWith(directory + path.sep)) { response.writeHead(403).end(); return; }
      if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405).end(); return; }
      const info = await stat(target);
      if (!info.isFile()) { response.writeHead(404).end(); return; }
      const headers = { 'Content-Type': mime[path.extname(target)] || 'application/octet-stream', 'Accept-Ranges': 'bytes', 'Cache-Control': 'no-store' };
      let start = 0;
      let end = info.size - 1;
      let status = 200;
      if (request.headers.range) {
        const match = /^bytes=(\d*)-(\d*)$/.exec(request.headers.range);
        if (!match || (!match[1] && !match[2])) { response.writeHead(416, { 'Content-Range': `bytes */${info.size}` }).end(); return; }
        if (!match[1]) start = Math.max(0, info.size - Number(match[2]));
        else {
          start = Number(match[1]);
          if (match[2]) end = Math.min(end, Number(match[2]));
        }
        if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 0 || start > end || start >= info.size) {
          response.writeHead(416, { 'Content-Range': `bytes */${info.size}` }).end(); return;
        }
        status = 206;
        headers['Content-Range'] = `bytes ${start}-${end}/${info.size}`;
      }
      headers['Content-Length'] = Math.max(0, end - start + 1);
      response.writeHead(status, headers);
      if (request.method === 'HEAD' || info.size === 0) { response.end(); return; }
      const stream = createReadStream(target, { start, end });
      stream.on('error', () => response.destroy());
      response.on('close', () => stream.destroy());
      stream.pipe(response);
    } catch (error) {
      response.writeHead(error.code === 'ENOENT' ? 404 : 400).end();
    }
  };
  return tls ? https.createServer(tls, handler) : http.createServer(handler);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = createPreviewServer();
  server.listen(Number(process.argv[2] || 8063), '127.0.0.1', () => console.log(`Island preview: http://127.0.0.1:${server.address().port}`));
}
