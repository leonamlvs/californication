import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPreviewServer } from './island_video_preview_server.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/island-scene-preview/web');
const server = createPreviewServer(root);
server.listen(Number(process.argv[2] || 8064), '127.0.0.1', () => console.log(`Island geometry/camera preview: http://127.0.0.1:${server.address().port}`));
