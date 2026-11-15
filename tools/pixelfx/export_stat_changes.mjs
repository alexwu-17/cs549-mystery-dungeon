// Project-authored stat chevrons rendered with PixelFX's MIT drawing toolkit.
// See third_party/pixelfx/LICENSE and NOTICE.md. No stock actors or text fonts.
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
const checkout = process.argv[2];
if (!checkout) throw new Error('usage: node tools/pixelfx/export_stat_changes.mjs <pinned-pixelfx-checkout>');
const upstream = path => import(pathToFileURL(join(resolve(checkout), path)).href);
const { fit, TAU } = await upstream('src/core/index.js');
const { renderFrames, spriteSheet } = await upstream('tools/lib/fxlib.mjs');
const output = resolve('assets/effects/pixelfx');
mkdirSync(output, { recursive: true });
for (const increase of [true, false]) {
  const id = increase ? 'stat_up' : 'stat_down';
  const palette = fit(increase
    ? ['#123b30', '#268b51', '#62d96c', '#d6ffb0', '#ffe69a']
    : ['#371b47', '#843b70', '#db526a', '#ffac9e', '#b8a0ed'], 5);
  const meta = { name: id, size: [64,48], origin: [32,24], duration: 0.8, fps: 60, loop: true, bg: 'none', options: {} };
  const draw = (p, time) => {
    const progress = time / 0.8, phase = progress * TAU;
    // Two narrow, thicker chevrons per sprite, at three actor-relative spots.
    for (let i = 0; i < 2; i++) {
      const apex = -10 + i * 11 - Math.sin(phase) * 1.2;
      p.shade(-12, -19, 12, 20, (x, y, out) => {
        const yy = increase ? y : -y;
        const edge = yy - apex - Math.abs(x) * 0.8;
        if (Math.abs(x) > 7 || edge < 0 || edge > 6) return;
        out.c = edge < 0.8 || edge > 5.2 || Math.abs(x) > 6 ? palette[0]
          : edge < 2 ? palette[3] : x < 0 ? palette[2] : palette[1];
        if (Math.abs(x - (progress * 28 - 14)) < 1 && edge > 1 && edge < 3) out.c = palette[4];
      });
    }
    for (let i = 0; i < 7; i++) {
      const age = (progress + i / 7) % 1;
      const x = (i % 2 ? -1 : 1) * (10 + Math.sin(phase + i) * 2);
      const y = (increase ? 1 : -1) * (17 - age * 34);
      const alpha = Math.sin(age * Math.PI) * 0.85;
      if (increase) {
        p.line(x - 1.5, y, x + 1.5, y, palette[4], alpha);
        p.line(x, y - 1.5, x, y + 1.5, palette[3], alpha);
      } else {
        // Curved violet wisps descend around the red indicator.
        p.line(x, y, x + Math.sin(age * 6 + i) * 3, y - 3, palette[4], alpha * 0.65);
      }
    }
  };
  const fx = { id: `dungeon/${id}`, meta, mod: { meta, draw } };
  const frames = renderFrames(fx, { actor: false, bg: 'none', seed: 5 });
  const sheet = spriteSheet(fx, frames, id);
  sheet.json.meta.pixelfx.loop = false;
  sheet.json.meta.pixelfx.revision = '5294518ce7c72e48b6100a744596e0acf57f2826';
  writeFileSync(join(output, `${id}.png`), sheet.png);
  writeFileSync(join(output, `${id}.json`), JSON.stringify(sheet.json, null, 1) + '\n');
  console.log(`PASS: ${id}: ${frames.n} frames, ${sheet.json.meta.pixelfx.columns} columns`);
}
