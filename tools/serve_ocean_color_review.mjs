import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createPreviewServer} from './island_video_preview_server.mjs';
const frame=process.argv.includes('--frame');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), `../docs/evidence/island_intro/${frame ? 'ocean-frame' : 'ocean-color'}/review`);
const port=frame ? 8070 : 8069;
createPreviewServer(root).listen(port,'127.0.0.1',()=>console.log(`Static ocean review: http://127.0.0.1:${port}/index.html`));
