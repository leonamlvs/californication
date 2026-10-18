import path from 'node:path';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createPreviewServer} from './island_video_preview_server.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/web');
const secure = process.argv.includes('--https');
const lan = process.argv.includes('--lan') || secure;
const host = lan ? '0.0.0.0' : '127.0.0.1';
const port = secure ? 8068 : lan ? 8067 : 8066;
const tls = secure ? {
  key: readFileSync(path.resolve(root, '../island-production/tls/key.pem')),
  cert: readFileSync(path.resolve(root, '../island-production/tls/cert.pem')),
} : null;
createPreviewServer(root, tls).listen(port, host, () => console.log(`Production game: ${secure ? 'https' : 'http'}://${host}:${port}/index.html${lan ? ' (use this computer\'s LAN address on the phone)' : ''}`));
