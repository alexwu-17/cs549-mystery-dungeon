// Impact adaptations rendered from the pinned PixelFX MIT toolkit/effects.
// See third_party/pixelfx/LICENSE and NOTICE.md for Patch/Hugo Duprez credits.
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { emberBurst, leafImpact, basicHitFlash, scratchHit } from './impact_adaptations.mjs';
const checkout = process.argv[2];
if (!checkout) throw new Error('usage: node tools/pixelfx/export_impacts.mjs <pinned-pixelfx-checkout>');
const upstream = path => import(pathToFileURL(join(resolve(checkout), path)).href);
const core = await upstream('src/core/index.js');
const { fit, TAU, smooth, ease } = core;
const { drawLeaf } = await upstream('src/fx/nature/_lib.js');
const { meta: vineWhip } = await upstream('src/fx/nature/vine-whip.js');
const { WATER, billow } = await upstream('src/fx/water/_lib.js');
const { renderFrames, spriteSheet } = await upstream('tools/lib/fxlib.mjs');
const output = resolve('assets/effects/pixelfx');
mkdirSync(output, { recursive: true });

for (const id of ['ember_hit', 'ember_body_burst', 'ember_smoke', 'razor_leaf_hit', 'bubble_hit', 'basic_hit', 'scratch_hit']) {
  let meta = { name: id, size: [64,48], origin: [32,24], duration: 0.25, fps: 192, loop: true, bg: 'none', options: {} };
  let rendered, source;
  if (id === 'ember_hit') {
    source = 'fire/fire-ring: soot stain removed';
    const original = await upstream('src/fx/fire/fire-ring.js');
    meta = original.meta;
    const soot = core.hex('#0d0a12'), soot2 = core.hex('#17121d');
    const mod = { ...original, create:o => {
      const effect = original.create(o);
      return { ...effect, drawBack:p => {
        // Remove only the original scorch() soot blends. Retain hot embers,
        // floor light, flame tongues and smoke; leave upstream files intact.
        const clean = Object.create(p);
        clean.blend = (x,y,color,alpha) => {
          if (color !== soot && color !== soot2) p.blend(x,y,color,alpha);
        };
        effect.drawBack(clean);
      } };
    } };
    rendered = renderFrames({ id: source, mod, meta }, { actor: false, bg: 'none' });
  } else if (id === 'ember_body_burst') {
    source = 'reduced-density small-explosion adaptation / body burst';
    const original = await upstream('src/fx/explosions/small-explosion.js');
    meta = { ...meta, size:[128,128], origin:[64,90], duration:0.7, fps:48/0.7, options:original.meta.options };
    rendered = renderFrames({ id,meta,mod:{ meta,create:o=>emberBurst(core,o) } }, { actor:false,bg:'none' });
  } else if (id === 'ember_smoke') {
    source = 'PixelFX smoke puff / runtime world-space rise';
    meta = { ...meta,size:[64,64],origin:[32,32],duration:0.5,fps:96 };
    const create = () => {
      const particles = new core.Particles({ rng:new core.Rng(5),ground:()=>100 });
      particles.spawn(core.P.SMOKE,0,0,0,-4,0.5,core.rgb(92,86,96),7);
      return { update:dt=>particles.update(dt), draw:p=>particles.draw(p) };
    };
    rendered=renderFrames({ id,meta,mod:{meta,create} },{actor:false,bg:'none'});
  } else if (id === 'basic_hit' || id === 'scratch_hit') {
    source = id === 'basic_hit' ? 'impacts/hit-spark shining cross/diamond only, no particles' : 'custom three simultaneous white diagonal slashes';
    if(id === 'basic_hit') meta={...meta,duration:0.12,fps:400};
    if(id === 'scratch_hit') meta={...meta,size:[64,64],origin:[32,32]};
    const draw=id==='basic_hit'?basicHitFlash(core):scratchHit(core);
    rendered=renderFrames({id,meta,mod:{meta,draw}},{actor:false,bg:'none'});
  } else if (id === 'razor_leaf_hit') {
    source = 'custom three-direction claw-style slashes + nature/vine-whip impact-only crack/leaves';
    rendered = renderFrames({ id, meta, mod: { meta, draw: leafImpact(core,drawLeaf,vineWhip.options.palette) } }, { actor:false,bg:'none' });
  } else {
    source = 'custom five pops + water/wave-crash expanding foam billows';
    const C = fit(WATER, 8);
    const centers = [[-20,-13],[20,-12],[0,0],[-18,13],[19,13]];
    const draw = (p, time) => {
      // Wave Crash's expanding white-blue foam particles, scaled into a
      // short body-sized burst behind the existing five pop rings.
      centers.forEach(([x,y], i) => {
        for (let j = 0; j < 2; j++) {
          const age = (time - i * 0.012 - j * 0.018) / 0.17;
          if (age <= 0 || age >= 1) continue;
          const angle = i * 1.7 + j * Math.PI;
          const radius = (0.9 + (3.5 + j * 0.6) * ease.outCubic(age)) * (1 - smooth(0.7,1,age));
          if (radius > 0.6) billow(p, x * 0.65 + Math.cos(angle) * age * 6,
            y * 0.6 + Math.sin(angle) * age * 5 - age * 2, radius, C);
        }
      });
      centers.forEach(([x,y], i) => {
        const age = (time - i * 0.018) / 0.16;
        if (age <= 0 || age >= 1) return;
        const radius = 1.5 + age * 5.5, alpha = Math.sin(Math.PI * age);
        for (let j = 0; j < 16; j++) {
          const angle = j / 16 * TAU, next = (j + 1) / 16 * TAU;
          p.line(x + Math.cos(angle)*radius, y + Math.sin(angle)*radius,
            x + Math.cos(next)*radius, y + Math.sin(next)*radius, j < 8 ? C[6] : C[4], alpha);
        }
        for (let j = 0; j < 4; j++) {
          const angle = j * TAU / 4 + i * 0.6;
          p.line(x + Math.cos(angle)*(radius+1), y + Math.sin(angle)*(radius+1),
            x + Math.cos(angle)*(radius+2.5), y + Math.sin(angle)*(radius+2.5), C[7], alpha);
        }
      });
    };
    rendered = renderFrames({ id, meta, mod: { meta, draw } }, { actor: false, bg: 'none' });
  }
  const sheet = spriteSheet({ id: `dungeon/${id}`, meta, mod: { meta } }, rendered, id);
  sheet.json.meta.pixelfx.loop = false;
  sheet.json.meta.pixelfx.derivedFrom = source;
  sheet.json.meta.pixelfx.revision = '5294518ce7c72e48b6100a744596e0acf57f2826';
  writeFileSync(join(output, `${id}.png`), sheet.png);
  writeFileSync(join(output, `${id}.json`), JSON.stringify(sheet.json, null, 1) + '\n');
  console.log(`PASS: ${id}: ${rendered.n} frames, ${rendered.w}x${rendered.h}, ${sheet.json.meta.pixelfx.columns} columns`);
}
