import {readFileSync,writeFileSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL} from 'node:url';
const root=resolve(process.argv[2]);
const source=join(root,'src/fx/holy/heal.js');
// actor:false omits the demo actor pass, but Heal also paints a recolored
// copy inside draw(). Remove only that copy, retaining its surrounding glow.
let code=readFileSync(source,'utf8');
const body=/        recolor\(p, A, \(c, x, y\) => \{[\s\S]*?\n        \}\);/;
if (!body.test(code)) throw new Error('Heal body recolor block changed upstream');
code=code.replace(body,'        // Native Pokemon owns the body; effects only.');
code=code.replace(/from "([^"]+)"/g,(_,p)=>`from "${pathToFileURL(resolve(dirname(source),p)).href}"`);
const mod=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const {renderFrames,spriteSheet}=await import(pathToFileURL(join(root,'tools/lib/fxlib.mjs')).href);
const frames=renderFrames({id:'recovery',meta:mod.meta,mod},{actor:false,bg:'none',seed:5,options:{}});
const sheet=spriteSheet({id:'recovery',meta:mod.meta,mod},frames,'recovery');
sheet.json.meta.pixelfx.runtimePivot=[40,92];
sheet.json.meta.pixelfx.revision='5294518ce7c72e48b6100a744596e0acf57f2826';
writeFileSync('assets/effects/pixelfx/recovery.png',sheet.png);
writeFileSync('assets/effects/pixelfx/recovery.json',JSON.stringify(sheet.json,null,1)+'\n');
console.log('PASS: recovery heal exported');
