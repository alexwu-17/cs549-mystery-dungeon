// Project-authored projectile arrangements using PixelFX's MIT drawing code.
// Bubble shading adapts src/fx/water/bubbles.js (Patch / Hugo Duprez, 2026).
// Curved leaf shading adapts src/fx/nature/_lib.js, also used by Leaf Storm.
// See third_party/pixelfx/LICENSE and NOTICE.md. Node >=18; no npm dependencies.
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const checkout = process.argv[2];
if (!checkout) throw new Error('usage: node tools/pixelfx/export_projectiles.mjs <pinned-pixelfx-checkout>');
const upstream = path => import(pathToFileURL(join(resolve(checkout), path)).href);
const { fit, WHITE, TAU, smooth } = await upstream('src/core/index.js');
const { WATER } = await upstream('src/fx/water/_lib.js');
const { drawLeaf } = await upstream('src/fx/nature/_lib.js');
const { meta: leafStorm } = await upstream('src/fx/nature/leaf-storm.js');
const { renderFrames, spriteSheet } = await upstream('tools/lib/fxlib.mjs');

// Edit these and rerun the exporter to customize the blade and spin.
const LEAF_STYLE = {
  length: 22, width: 3.2, curvature: 0.30,
  spinTurns: 1.5, startingAngle: -0.35, followerPhase: 1.7,
  viewTilt: Math.PI / 3, viewRoll: -0.18,
};

function floralWind(p, phase, trail, front) {
  if (trail < 0.03) return;
  const wind = fit(leafStorm.options.palette, 6);
  const autumn = fit(leafStorm.options.leaves, 12);
  // Wind ribbons and autumn leaves share a loose helix around the shot.
  // Split the near/far halves around the main blades to mix the wake into
  // the projectile as well as extending it behind the leading leaf.
  for (let band = 0; band < 3; band++) {
    for (let step = 0; step < 30; step++) {
      const t = step / 30, t2 = (step + 1) / 30;
      const angle = phase * 2 + t * 7 + band * TAU / 3;
      if ((Math.cos(angle) > 0) !== front) continue;
      const radius = (3 + 5 * t) * trail;
      const x = 4 - t * 42 * trail, y = Math.sin(angle) * radius;
      const nextY = Math.sin(phase * 2 + t2 * 7 + band * TAU / 3) * (3 + 5 * t2) * trail;
      p.line(x, y, 4 - t2 * 42 * trail, nextY, front ? wind[5] : wind[3],
        (front ? 0.65 : 0.4) * trail * Math.sin(Math.PI * t));
    }
  }
  for (let i = 0; i < 8; i++) {
    const t = (i + 0.5) / 8, angle = phase * 2 + t * 8;
    if ((Math.cos(angle) > 0) !== front) continue;
    const palette = autumn.slice(i % 2 === 0 ? 4 : 8, i % 2 === 0 ? 8 : 12);
    drawLeaf(p, 3 - t * 40 * trail, Math.sin(angle) * (3 + 5 * t) * trail,
      (6 + i % 3) * trail, (1.5 + (i % 2) * 0.4) * trail,
      -phase * 2 + i * 1.3, phase * 2.5 + i, palette, front ? 1 : 0.8);
  }
}

function scytheLeaf(p, x, y, length, width, angle, palette, faceOn = false) {
  const ca = Math.cos(angle), sa = Math.sin(angle), bend = length * LEAF_STYLE.curvature;
  const roll = faceOn ? 0 : LEAF_STYLE.viewRoll;
  const cr = Math.cos(roll), sr = Math.sin(roll);
  const foreshorten = faceOn ? 1 : Math.max(0.15, Math.cos(LEAF_STYLE.viewTilt));
  const bounds = Math.ceil(length / 2 + Math.abs(bend) + width + 2);
  // A curved central vein and unequal sides retain the shaded leaf blade,
  // while both pointed ends follow a pronounced crescent/scythe silhouette.
  p.shade(x - bounds, y - bounds, x + bounds, y + bounds, (px, py, out) => {
    const screenX = px - x, screenY = py - y;
    // Undo the fixed viewing angle before undoing the in-plane spin. The
    // blade rotates inside a tilted disc, rather than turning like a wheel
    // facing the camera. Its original geometry and spin rate stay unchanged.
    const dx = screenX * cr + screenY * sr;
    const dy = (-screenX * sr + screenY * cr) / foreshorten;
    const u = (dx * ca + dy * sa) / (length / 2);
    if (Math.abs(u) >= 1) return;
    const v = -dx * sa + dy * ca;
    const arch = 1 - u * u, vein = bend * arch;
    const half = width * Math.pow(arch, 0.7) * (0.85 - 0.25 * u);
    const distance = v - vein;
    if (Math.abs(distance) > half + 0.6) return;
    out.c = Math.abs(distance) > Math.max(0, half - 0.6) ? palette[0]
      : Math.abs(distance) < 0.55 ? palette[1]
      : distance < 0 ? palette[3] : palette[2];
  });
}

function bubble(p, C, x, y, radius, squash) {
  const rx = radius * (1 + squash), ry = radius * (1 - squash);
  p.shade(x - rx - 1, y - ry - 1, x + rx + 1, y + ry + 1, (px, py, out) => {
    const dx = (px - x) / rx, dy = (py - y) / ry, d = Math.hypot(dx, dy);
    if (d > 1 + 0.5 / radius) return;
    const light = (-dx - dy) / Math.SQRT2 / Math.max(0.01, d);
    if (d > 1 - 0.6 / radius) out.c = light > 0.45 ? C[6] : light < -0.55 ? C[3] : C[4];
    // Blue glass rather than a pale/white fill. Keep alpha below the
    // shadow's rim threshold so the ground projection remains hollow.
    else p.blend(px, py, dy > 0.15 ? C[2] : C[3], 0.24 + 0.1 * d);
  });
  p.px(Math.round(x - rx * 0.45), Math.round(y - ry * 0.45), WHITE);
  p.px(Math.round(x - rx * 0.45) + 1, Math.round(y - ry * 0.45), C[6]);
  p.px(Math.round(x + rx * 0.5), Math.round(y + ry * 0.5), C[6]);
}

const output = resolve('assets/effects/pixelfx');
mkdirSync(output, { recursive: true });
for (const id of ['bubble', 'razor_leaf', 'razor_leaf_front']) {
  const meta = {
    name: id, size: [64, 48], origin: [48, 24],
    duration: 0.8, fps: 60, loop: true, bg: 'none', options: {},
  };
  const draw = (p, time) => {
    const tiles = time / 0.2, phase = time / 0.8 * TAU;
    const growth = smooth(0.625, 2.1, tiles);
    const taper = 1 - smooth(2.25, 4.0, tiles);
    const trail = growth * taper;
    if (id === 'bubble') {
      const C = fit(WATER, 8);
      // A few small, staggered bubbles extend the wake. Their size and
      // spacing grow together, then contract as the shot fizzles out.
      for (let i = 4; i >= 0; i--) {
        const emergence = smooth(0.625 + i * 0.12, 1.65 + i * 0.12, tiles);
        const radius = (2.2 - i * 0.25) * emergence * taper;
        if (radius < 0.65) continue;
        bubble(p, C, -(20 + i * 5) * trail,
          Math.sin(phase * 2 + i * 1.7) * (2 + i * 0.5) * trail,
          radius, Math.sin(phase * 3 + i) * 0.08);
      }
      // Secondary bubbles emerge continuously behind the leading bubble.
      for (let i = 2; i >= 1; i--) {
        const size = smooth(0.625 + i * 0.15, 1.8 + i * 0.15, tiles) * taper;
        if (size < 0.03) continue;
        bubble(p, C, -i * 8 * growth, Math.sin(phase * 2 + i) * 4 * growth,
          (4.5 - i * 0.6) * size, Math.sin(phase * 3 + i) * 0.08);
      }
      bubble(p, C, 0, Math.sin(phase * 2) * 0.5, 6, Math.sin(phase * 3) * 0.07);
    } else {
      const palette = fit(['#123818', '#2f7a2a', '#6cb83a', '#c8f070'], 4);
      floralWind(p, phase, trail, false);
      for (let i = 2; i >= 0; i--) {
        const size = i === 0 ? 1 : smooth(0.625 + i * 0.15, 1.9, tiles);
        if (size < 0.03) continue;
        scytheLeaf(p, -i * 8 * growth, i === 0 ? 0 : Math.sin(phase * 2 + i * 2) * 5 * growth,
          (LEAF_STYLE.length - i * 3) * size, (LEAF_STYLE.width - i * 0.4) * size,
          phase * LEAF_STYLE.spinTurns + LEAF_STYLE.startingAngle + i * LEAF_STYLE.followerPhase, palette,
          id === 'razor_leaf_front');
      }
      floralWind(p, phase, trail, true);
    }
  };
  const mod = { meta, draw };
  const fx = { id: `dungeon/${id}`, meta, mod };
  const rendered = renderFrames(fx, { actor: false, bg: 'none', seed: 5 });
  const sheet = spriteSheet(fx, rendered, id);
  // Frames represent one flight lifecycle; the tool uses loop=true solely to
  // omit its extra endpoint frame. Godot clamps playback and fades by distance.
  sheet.json.meta.pixelfx.loop = false;
  sheet.json.meta.pixelfx.derivedFrom = id === 'bubble' ? 'water/bubbles' : 'nature/leaf-storm + nature/_lib';
  sheet.json.meta.pixelfx.revision = '5294518ce7c72e48b6100a744596e0acf57f2826';
  writeFileSync(join(output, `${id}.png`), sheet.png);
  writeFileSync(join(output, `${id}.json`), JSON.stringify(sheet.json, null, 1) + '\n');
  console.log(`PASS: ${id}: ${rendered.n} frames, ${sheet.json.meta.pixelfx.columns} columns`);
}
