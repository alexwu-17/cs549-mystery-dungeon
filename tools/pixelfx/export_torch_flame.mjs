// Flame-only adaptation of PixelFX fire/torch (Patch / Hugo Duprez, MIT).
// See third_party/pixelfx/{LICENSE,NOTICE.md,README.md}. No torch hardware baked in.
import { writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
const checkout = process.argv[2];
if (!checkout) throw new Error('usage: node tools/pixelfx/export_torch_flame.mjs <pinned-pixelfx-checkout>');
const upstream = path => import(pathToFileURL(join(resolve(checkout), path)).href);
const { fit } = await upstream('src/core/index.js');
const { burn, hotFirst, noiseFor } = await upstream('src/fx/fire/_lib.js');
const { meta: original } = await upstream('src/fx/fire/torch.js');
const { renderFrames, spriteSheet } = await upstream('tools/lib/fxlib.mjs');
const meta = { ...original, name: 'Torch flame', origin: [36,94], bg: 'none' };
const tongues = [[-1.9,-1,0.74,2,1],[2.1,-1,0.7,2,1],[-3.4,0.5,0.42,1.6,0],[3.6,0.5,0.46,1.6,0],[0,0,1,2.9,0]];
const NL = noiseFor(meta.duration);
const draw = (p,t,o) => burn(p,t,tongues, {
  H:hotFirst(fit(o.palette,9)), D:meta.duration, NL, S:o.seed,
  x:0,y:0,height:20,lean:0.12,spread:4,puffs:10,licks:5,
  smoke:7,smokeSize:2.3,smokeLife:[1.3,2.1],embers:7,glowR:48,glow:1.25,wind:2,
});
const fx = { id:'dungeon/torch_flame', meta, mod:{meta,draw} };
const frames = renderFrames(fx,{actor:false,bg:'none',seed:5});
const sheet = spriteSheet(fx,frames,'torch_flame');
sheet.json.meta.pixelfx.revision = '5294518ce7c72e48b6100a744596e0acf57f2826';
sheet.json.meta.pixelfx.source = 'fire/torch: flame/smoke/embers only';
writeFileSync('assets/effects/pixelfx/torch_flame.png',sheet.png);
writeFileSync('assets/effects/pixelfx/torch_flame.json',JSON.stringify(sheet.json,null,1)+'\n');
console.log(`PASS: torch_flame: ${frames.n} looping frames at ${frames.fps}fps`);
