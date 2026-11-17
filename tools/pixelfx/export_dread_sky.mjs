// PixelFX sky + weather/aurora + weather/fireflies, adapted for the final corridor.
// MIT / Hugo Duprez notices: third_party/pixelfx. No upstream files are modified.
import {readFileSync,writeFileSync} from 'node:fs';
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL} from 'node:url';
const checkout=process.argv[2];
if(!checkout) throw new Error('usage: node tools/pixelfx/export_dread_sky.mjs <pinned-pixelfx-checkout>');
const upstream=p=>import(pathToFileURL(join(resolve(checkout),p)).href);
const {renderFrames,spriteSheet}=await upstream('tools/lib/fxlib.mjs');
const {backdrop}=await upstream('src/core/scene.js');
const auroraPath=join(resolve(checkout),'src/fx/weather/aurora.js');
let auroraCode=readFileSync(auroraPath,'utf8').replace('  stars(q, t, S, G, U);','');
auroraCode += '\nexport function drawStars(p,t,o) { stars(clip(p,meta),t,o.seed,fit(o.palette,7),fit(o.upper,7)); }';
auroraCode=auroraCode.replace(/from "([^"]+)"/g,(_,p)=>`from "${pathToFileURL(resolve(dirname(auroraPath),p)).href}"`);
const aurora=await import('data:text/javascript;base64,'+Buffer.from(auroraCode).toString('base64'));
const flyPath=join(resolve(checkout),'src/fx/weather/fireflies.js');
let code=readFileSync(flyPath,'utf8');
// Keep the exact upstream firefly paths, pulse, wings and light recipe, excluding
// its meadow/grass and full-screen haze so it can sit over the aurora sky.
code=code.replace(/export function drawBack[\s\S]*?(?=export function draw\()/,`export function drawBack(p,t,o) {
 const q=clip(p,meta), C=fit(o.palette,6);
 for(let i=0;i<26;i++) firefly(q,t,fly(o.seed,i,t),C);
}\n`);
code=code.replace(/export function draw\(p, t, o\) \{[\s\S]*?(?=function firefly)/,`export function draw(p,t,o) {
 const q=clip(p,meta), C=fit(o.palette,6);
 for(let i=26;i<32;i++) firefly(q,t,fly(o.seed,i,t),C);
}\n`);
code=code.replace(/from "([^"]+)"/g,(_,p)=>`from "${pathToFileURL(resolve(dirname(flyPath),p)).href}"`);
const flies=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const meta={...aurora.meta,name:'Dread sky',fps:12};
const oldDark=['#10091e','#20102f','#341849','#4b2863','#673d85','#8b60a5','#b78fc8'];
const dark=['#030105','#06020a','#0a0410','#10091e','#20102f','#341849','#4b2863'];
const oldUpper=['#100b20','#211231','#351d4d','#513064','#72498b','#9a74ae','#c1a1cd'];
const upper=['#030105','#06030a','#0a0511','#100b20','#211231','#351d4d','#513064'];
const a=renderFrames({id:'weather/aurora',meta,mod:{...aurora,meta}},{actor:false,bg:'none',options:{palette:dark,upper},seed:3});
const f=renderFrames({id:'weather/fireflies',meta:{...flies.meta,fps:12},mod:flies},{actor:false,bg:'none',options:{palette:['#160b23','#34154c','#62338a','#9455bd','#c18be0','#e4b9f5']},seed:2,fps:12});
const stars=renderFrames({id:'weather/aurora-stars',meta,mod:{meta,draw:aurora.drawStars}},{actor:false,bg:'none',options:{palette:oldDark,upper:oldUpper},seed:3});
const sky=backdrop('sky',320,180);
for(let frame=0;frame<a.n;frame++) {
 const aa=a.frames[frame].clear, ff=f.frames[frame].clear, ss=stars.frames[frame].clear;
 const out=new Uint8ClampedArray(320*180*4);
 for(let i=0;i<320*180;i++) {
  const j=i*4,c=sky[i], alpha=aa[j+3]/255;
  const density=alpha*Math.max(aa[j],aa[j+1],aa[j+2])/210;
  const skyRGB=[c&255,(c>>>8)&255,(c>>>16)&255];
  const isStar=Math.max(...skyRGB)>60;
  const base=skyRGB.map((v,ch)=>v*(isStar?[1.15,0.72,1.25][ch]:[0.16,0.12,0.19][ch]));
  // Subtractive curtains dim stars/sky; a subdued violet body retains shape.
  for(let channel=0;channel<3;channel++) {
   const curtain=base[channel]*(1-density*0.82)+aa[j+channel]*alpha*0.38;
   const starAlpha=ss[j+3]/255;
   const starry=curtain*(1-starAlpha)+ss[j+channel]*starAlpha;
   const flyAlpha=ff[j+3]/255;
   const brightness=Math.max(ff[j],ff[j+1],ff[j+2]);
   const purple=brightness*[0.83,0.43,1.0][channel];
   out[j+channel]=Math.min(220,starry*(1-flyAlpha)+purple*flyAlpha*0.8);
  }
  out[j+3]=255;
 }
 a.frames[frame].clear=out;
 a.frames[frame].color=out;
}
const fx={id:'dungeon/dread_sky',meta,mod:{}};
const sheet=spriteSheet(fx,a,'dread_sky');
sheet.json.meta.pixelfx.revision='5294518ce7c72e48b6100a744596e0acf57f2826';
sheet.json.meta.pixelfx.source='core/scene sky + weather/aurora three-shades-darker subtractive purple + weather/fireflies purple, no meadow';
writeFileSync('assets/effects/pixelfx/dread_sky.png',sheet.png);
writeFileSync('assets/effects/pixelfx/dread_sky.json',JSON.stringify(sheet.json,null,1)+'\n');
console.log(`PASS: dread sky: ${a.n} frames at12fps, ${sheet.json.meta.pixelfx.columns} columns`);

// Export Eclipse separately so the3x repeated sky contains only one moon.
const eclipsePath=join(resolve(checkout),'src/fx/shadow/eclipse.js');
let eclipseCode=readFileSync(eclipsePath,'utf8');
eclipseCode=eclipseCode.replace(/  cycle\(t, D, 26,[\s\S]*?\n  \}\);/,'  // Existing sky owns the stars.');
eclipseCode=eclipseCode.replace(/from "([^"]+)"/g,(_,p)=>`from "${pathToFileURL(resolve(dirname(eclipsePath),p)).href}"`);
const eclipse=await import('data:text/javascript;base64,'+Buffer.from(eclipseCode).toString('base64'));
const eclipseMeta={...eclipse.meta,fps:12};
const eclipseFx={id:'shadow/eclipse',meta:eclipseMeta,mod:{...eclipse,meta:eclipseMeta}};
const eclipseFrames=renderFrames(eclipseFx,{actor:false,bg:'none',seed:3});
const eclipseSheet=spriteSheet(eclipseFx,eclipseFrames,'dread_eclipse');
eclipseSheet.json.meta.pixelfx.revision='5294518ce7c72e48b6100a744596e0acf57f2826';
eclipseSheet.json.meta.pixelfx.source='shadow/eclipse, surrounding stars omitted';
writeFileSync('assets/effects/pixelfx/dread_eclipse.png',eclipseSheet.png);
writeFileSync('assets/effects/pixelfx/dread_eclipse.json',JSON.stringify(eclipseSheet.json,null,1)+'\n');
console.log(`PASS: Eclipse: ${eclipseFrames.n} frames, ${eclipseSheet.json.meta.pixelfx.columns} columns`);
