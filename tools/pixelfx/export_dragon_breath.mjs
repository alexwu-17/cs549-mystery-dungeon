// PixelFX ice/frost-breath as Dragon Breath artwork; original palette retained.
// See third_party/pixelfx LICENSE / NOTICE.md. No source assets are modified.
import { writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
const checkout=process.argv[2];
if(!checkout) throw new Error('usage: node tools/pixelfx/export_dragon_breath.mjs <pinned-pixelfx-checkout>');
const upstream=p=>import(pathToFileURL(join(resolve(checkout),p)).href);
const original=await upstream('src/fx/ice/frost-breath.js');
const { renderFrames,spriteSheet }=await upstream('tools/lib/fxlib.mjs');
const meta={...original.meta,fps:40};
const fx={id:'dungeon/dragon_breath',meta,mod:{...original,meta}};
const frames=renderFrames(fx,{actor:false,bg:'none',seed:5});
const sheet=spriteSheet(fx,frames,'dragon_breath');
sheet.json.meta.pixelfx.revision='5294518ce7c72e48b6100a744596e0acf57f2826';
sheet.json.meta.pixelfx.source='ice/frost-breath';
writeFileSync('assets/effects/pixelfx/dragon_breath.png',sheet.png);
writeFileSync('assets/effects/pixelfx/dragon_breath.json',JSON.stringify(sheet.json,null,1)+'\n');
console.log(`PASS: Frost Breath: ${frames.n} frames, ${sheet.json.meta.pixelfx.columns} columns`);
