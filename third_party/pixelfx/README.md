# PixelFX attribution and asset provenance

Ember uses a sprite sheet generated from [patch-gg/pixelfx](https://github.com/patch-gg/pixelfx),
revision `5294518ce7c72e48b6100a744596e0acf57f2826`.

Included assets: `assets/effects/pixelfx/fireball.png` and its original
`fireball.json` export metadata. Source effect: `src/fx/fire/fireball.js`.
The effect credits adaptations of Hugo Duprez's Sprite Fusion effects.
See the accompanying original `LICENSE` and `NOTICE.md` for terms and credits.
These terms cover the imported PixelFX material, not the whole dungeon project.
No gallery fonts, stock actors, or complete acted moves are included.

## Reproduce

With Node.js 18 or newer, check out the revision above in a separate working
directory, then run from that checkout:

```powershell
node tools/render.mjs fire/fireball --sheet --no-actor --seed 5
```

Copy `records/fire/fireball/fireball.png` and `fireball.json` to
`assets/effects/pixelfx/`. No npm installation is needed for PNG export.
The original output is unchanged: 36 frames at 30 FPS, 136x56 per frame,
4 columns and 9 rows, pivot (112, 28). Palette and other options use upstream
defaults. Glow is baked into the transparent image, not a Godot light.

Godot plays the frames during flight, scaled with the existing action speed.
`ProjectileEffect` uses the source pivot, nearest filtering and a camera-facing
plane rotated toward the projected travel direction. The camera is fixed during
the shot. Flight distance, release timing, combat and cancellation remain owned
by the existing systems. Additional moves must opt in by move ID.

The project-authored `scripts/effects/ember_projectile.gdshader` masks the
unchanged sheet at runtime: a ball through the first 0.625 tile, a smoothly
stretching rear silhouette until early in the third, then tapering and fading
through the fourth. The maximum tail extends about 55 source pixels behind the
head. Adjacent animation frames blend in premultiplied color. Parameters
follow distance traveled, so short shots do not rush through all four stages.
