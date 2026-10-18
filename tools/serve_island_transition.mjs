import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createPreviewServer} from './island_video_preview_server.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../build/island-transition-preview/web');
createPreviewServer(root).listen(8065,'127.0.0.1',()=>console.log('Island transition: http://127.0.0.1:8065/index.html'));
