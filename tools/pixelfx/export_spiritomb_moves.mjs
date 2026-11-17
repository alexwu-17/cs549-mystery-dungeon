// Pinned PixelFX Spiritomb adaptations. See third_party/pixelfx notices.
import {readFileSync,writeFileSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL} from 'node:url';
const checkout=resolve(process.argv[2]);
const upstream=p=>import(pathToFileURL(join(checkout,p)).href);
const {renderFrames,spriteSheet}=await upstream('tools/lib/fxlib.mjs');
async function adapted(path,change) {
 const file=join(checkout,path);
 let code=change(readFileSync(file,'utf8'));
 code=code.replace(/from "([^"]+)"/g,(_,p)=>`from "${pathToFileURL(resolve(dirname(file),p)).href}"`);
 return import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
}
const wind=await adapted('src/fx/weather/blizzard.js',s=>s.replace('  ground(p, q, t, S, C);','  // Airborne wind only: no accumulated snowbank.').replace('R.a[i] = Math.min(0.5, d);','R.a[i] = Math.min(0.75, d * 1.5);'));
const orb=await upstream('src/fx/shadow/void-orb.js');
const explosion=await adapted('src/fx/shadow/dark-explosion.js',s=>s
 .replace('sphere(p, C, sr, t, t < BURN ? 1 : 1 + 0.5 * clamp((t - BURN) / (POP - BURN)));','// No central collapsing sphere.')
 .replace(/for \(const r of rings\) floorRing\(p, C, r, (true|false)\);/g,'')
 .replace('if (k > 0) p.glow(0, -3, 74, C[4], 0.24 * Math.min(1, k) * flick);','')
 .replace(/    \/\/ the shock flattens on the floor[\s\S]*?(?=    for \(let i = 0; i < 10;)/,'')
 .replace(/      \/\/ the shock reaches the floor[\s\S]*?(?=      for \(const a of \[lights, rings\])/,'')
 .replace(/        if \(b.life < 0.45 && !b.wisp\) \{[\s\S]*?\n        \}/,'')
 .replace('for (const b of bits.list) shard(p, b, C, 0, Y, Math.min(1, k) * 0.9);','for (const b of bits.list) if (!b.rest && b.y < -8) shard(p, b, C, 0, Y, Math.min(1, k) * 0.9);'));

for(const [id,mod,duration,pivot,options,purple] of [
 ['ominous_wind',wind,1,[160,180],{},true],
 ['shadow_ball',orb,3.2,[84,88],{},false],
 ['shadow_ball_hit',explosion,3.8,[140,152],{},false]]) {
 const meta={...mod.meta,duration,fps:48/duration,loop:true};
 let frames=renderFrames({id,meta,mod:{...mod,meta}},{actor:false,bg:'none',seed:5,options});
 if(id==='shadow_ball_hit') {
  // Use the released explosion, omitting the windup and central inward collapse.
  frames.frames=frames.frames.slice(7); frames.n=frames.frames.length;
  // Nothing on/below the original ground line: retain the airborne burst only.
  for(const f of frames.frames) for(let y=198;y<248;y++) for(let x=0;x<280;x++) f.clear[(y*280+x)*4+3]=0;
 }

 if(purple) for(const f of frames.frames) for(let i=0;i<f.clear.length;i+=4) {
  const light=Math.max(f.clear[i],f.clear[i+1],f.clear[i+2]);
  f.clear[i]=light*0.72; f.clear[i+1]=light*0.46; f.clear[i+2]=light*0.98;
 }
 const sheet=spriteSheet({id,meta,mod},frames,id);
 sheet.json.meta.pixelfx.runtimePivot=pivot;
 sheet.json.meta.pixelfx.revision='5294518ce7c72e48b6100a744596e0acf57f2826';
 writeFileSync(`assets/effects/pixelfx/${id}.png`,sheet.png);
 writeFileSync(`assets/effects/pixelfx/${id}.json`,JSON.stringify(sheet.json,null,1)+'\n');
 console.log(`PASS: ${id}: ${frames.n} frames, ${sheet.json.meta.pixelfx.columns} columns`);
}
