// Effects-only adaptations of the pinned PixelFX lightning sources.
import {readFileSync,writeFileSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL} from 'node:url';
const root=resolve(process.argv[2]);
const {renderFrames,spriteSheet}=await import(pathToFileURL(join(root,'tools/lib/fxlib.mjs')).href);
async function adapted(name,change) {
 const file=join(root,'src/fx/lightning/'+name+'.js');
 let code=change(readFileSync(file,'utf8'));
 code=code.replace(/from "([^"]+)"/g,(_,p)=>`from "${pathToFileURL(resolve(dirname(file),p)).href}"`);
 return import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
}
const ball=await adapted('ball-lightning',s=>s
 .replace('[x, y] = at(t)','[x, y] = [0, -42]')
 .replace('  p.glow(x, -2, 30, C[3], 0.12 + 0.3 * clamp((y + 60) / 40));','')
 .replace('[wx, wy] = at(t - i * 0.034)','[wx, wy] = [-i * 1.5, -42]')
 .replace('[bx, by] = at(born)','[bx, by] = [-age * 45, -42]')
 .replace(/  \/\/ once a loop,[\s\S]*\n\}/,'\n}'));
const burst=await adapted('charge-up',s=>s
 .replace(/        if \(a < 0.07\) p.mask[^\n]+/,'        // No stock actor silhouette.'));
// A neutral ellipse supplies arc endpoints only; no demo body is exported.
const shock=await adapted('electrified',s=>s
 .replace('  const m = A.mask, on =','  const m = {w:20,h:30,data:Array.from({length:600},(_,i)=>((i%20-9.5)/10)**2+((Math.floor(i/20)-14.5)/15)**2<=1)}, on =')
 .replace('e.push([A.x + x + 0.5, A.y + y + 0.5])','e.push([x - 9.5, y - 29.5])')
 .replace(/  p.outline\([^\n]+/,'')
 .replace(/    for \(let y = 0; y < A.h; y\+\+\)[\s\S]*?(?=    p.glow)/,''));
for(const [id,mod,pivot,first,last] of [
 ['electro_ball',ball,[68,50],0,30],
 ['electro_ball_hit',burst,[139,127],48,72],
 ['electro_ball_shock',shock,[54,61],0,12]]) {
 let frames=renderFrames({id,meta:mod.meta,mod},{actor:false,bg:'none',seed:5});
 frames.frames=frames.frames.slice(first,last); frames.n=frames.frames.length;
 const sheet=spriteSheet({id,meta:mod.meta,mod},frames,id);
 sheet.json.meta.pixelfx.runtimePivot=pivot;
 sheet.json.meta.pixelfx.revision='5294518ce7c72e48b6100a744596e0acf57f2826';
 writeFileSync(`assets/effects/pixelfx/${id}.png`,sheet.png);
 writeFileSync(`assets/effects/pixelfx/${id}.json`,JSON.stringify(sheet.json,null,1)+'\n');
 console.log(`PASS: ${id}: ${frames.n} frames`);
}
