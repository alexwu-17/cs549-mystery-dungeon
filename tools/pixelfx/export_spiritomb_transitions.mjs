// Pinned PixelFX transitions, no upstream edits. See third_party/pixelfx notices.
import {writeFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
const checkout=process.argv[2];
if(!checkout) throw new Error('usage: node tools/pixelfx/export_spiritomb_transitions.mjs <pinned-pixelfx-checkout>');
const upstream=p=>import(pathToFileURL(join(resolve(checkout),p)).href);
const {renderFrames,spriteSheet}=await upstream('tools/lib/fxlib.mjs');
for(const [source,name,start,end] of [['glitch-wipe','spiritomb_glitch',0,0.8],['pixel-dissolve','spiritomb_dissolve',1.1,2.2]]) {
 const mod=await upstream(`src/fx/transitions/${source}.js`);
 const full=renderFrames({id:`transitions/${source}`,meta:mod.meta,mod},{actor:false,bg:'none',seed:1,options:{color:'#000000'}});
 const frames=full.frames.slice(Math.round(start*30),Math.round(end*30)+1);
 const meta={...mod.meta,duration:end-start};
 const rendered={...full,frames,n:frames.length};
 const sheet=spriteSheet({id:`transitions/${source}`,meta,mod},rendered,name);
 sheet.json.meta.pixelfx.revision='5294518ce7c72e48b6100a744596e0acf57f2826';
 sheet.json.meta.pixelfx.sourceSegment=[start,end];
 writeFileSync(`assets/effects/pixelfx/${name}.png`,sheet.png);
 writeFileSync(`assets/effects/pixelfx/${name}.json`,JSON.stringify(sheet.json,null,1)+'\n');
 console.log(`PASS: ${name}: ${frames.length} frames, ${sheet.json.meta.pixelfx.columns} columns`);
}
