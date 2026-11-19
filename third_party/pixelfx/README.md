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

## Bubble and Razor Leaf adaptations

`bubble.{png,json}` and `razor_leaf.{png,json}` are project-authored projectile
arrangements rendered through the same pinned PixelFX revision. Bubble adapts
the individual bubble shading in `src/fx/water/bubbles.js` (which credits Hugo
Duprez's Sprite Fusion bubbles). Razor Leaf adapts the shading of `drawLeaf` from
`src/fx/nature/_lib.js`, the same helper used by the upstream Leaf Storm aura.
The Leaf Storm aura itself is not shipped. These are adaptations rather than
unmodified library effects. Both exports omit scenery and stock characters.

From this project's root, with the pinned checkout available separately:

```powershell
node tools/pixelfx/export_projectiles.mjs <path-to-pixelfx-checkout>
```

The tracked exporter reproduces both sheets without npm dependencies: 48 frames
at 60 FPS, 64x48 cells, a 6x8 grid, leading-sprite pivot (48,24). Animation is
nonlooping and represents 0.8 seconds / four tiles at normal speed. Secondary
bubbles/leaves emerge after 0.625 tile and reach full size around tile2.
Godot blends adjacent frames, scales playback with action speed, and fades the
effects between 2.75 and4 tiles. Short shots terminate at their actual distance
without accelerating the four-tile lifecycle. No gameplay or targeting changes.

Bubble's travelling fill now uses translucent mid/deep blues rather than the
pale water highlight color, retaining white rim glints. Interior alpha stays
below the hollow-shadow threshold. Its hit sheet keeps the five pops and adds
ten small expanding white-blue billows using `water/_lib.billow`, the same
helper and growth/shrink curve used by `water/wave-crash`. No wave body/sea
geometry is exported; the combined hit still completes in0.25s before Hurt.

Razor Leaf's project-authored curved blade retains the leaf palette and vein
but uses a scythe silhouette. Customize `LEAF_STYLE` in the exporter: `length`,
`width`, `curvature`, `spinTurns` (over four tiles), `startingAngle` (radians),
and `followerPhase` (radians between leaves). Current spin is 1.5 turns per
full flight, with no edge-on flipping so the curved leaf stays readable.
Regenerate sheets after editing; these settings are baked into the artwork.

`viewTilt` (currently PI/3 radians from face-on) foreshortens the spinning
plane, and `viewRoll` (-0.18 radians) angles it on screen. Spin happens inside
that fixed tilted plane for a frisbee-like rotation; blade geometry is unchanged.

Both adapted projectiles have distance-shaped wakes. Razor Leaf uses three
swirling pale green wind ribbons and eight small gold/red autumn leaves drawn
with upstream `drawLeaf` and Leaf Storm's original autumn palettes. Near/far
layers pass around the main blades and extend behind them, replacing the faint
green streak. Bubble has five extra small staggered bubbles. Wakes grow
after0.625 tile and taper from2.25 to4 tiles, alongside the existing late
whole-effect fade, and are baked into the same sheets.

The exporter also writes `razor_leaf_front.{png,json}` with the same blade
shape, spin, foliage and wind, but zero view tilt/roll. Up/down shots select
this face-on variant; left/right retain `razor_leaf`'s tilted frisbee view.

## Stat-change preview replacement

`stat_up.{png,json}` and `stat_down.{png,json}` are custom shaded chevron
animations rendered with PixelFX's drawing/export toolkit, not stock library
buff/debuff effects. Each sheet contains two stacked, narrow chevrons; Godot places three smaller
copies around the affected sprite. Up uses green/gold chevrons and sparkles; down uses
red/violet chevrons and descending wisps. They replace the old flat runtime
arrow generator. Reproduce from the project root:

```powershell
node tools/pixelfx/export_stat_changes.mjs <path-to-pixelfx-checkout>
```

Both use the same pinned revision, 48 frames of64x48 in a6x8 grid, pivot(32,24).
Godot plays them over0.6s with premultiplied frame blending and fade-in/out,
using the opaque sprite bounds for upper-left/right/lower-left placement and
short directional travel in the camera plane. Up/down use the same layout.
The separate stat shader preserves camera-facing overlay behavior. No stock
characters/fonts, stat mechanics or action locks are introduced.

## Projectile hit feedback

`ember_hit`, `razor_leaf_hit` and `bubble_hit` PNG/JSON pairs are generated by:

```powershell
node tools/pixelfx/export_impacts.mjs <path-to-pixelfx-checkout>
```

Ember uses upstream `fire/fire-ring`, replacing the explosion, with its dark
soot-stain blends removed during export (the source file is untouched):
118 frames at224x128, a9x14 atlas, ground pivot(112,92). Runtime fits its
184-pixel ring diameter (default reach92) to one tile, anchors the origin to
the target tile surface plus0.025 and plays the full sequence in0.5s. No stock
actor is exported. The large original explosion is no longer selected.

Ember also layers `ember_body_burst` (128x128 cells) and `ember_smoke`
(64x64 cells), both48 frames in7x7 atlases. The burst reuses the reduced-density
explosion adaptation at the body center, scaled independently to visible body
width. Three staggered smoke puffs move upward in world space about two tiles,
with slight lateral drift and a fade; their rise is independent of the ground
ring's scale. All layers finish within the same0.5s impact, before Hurt.
These assets are regenerated by the same `export_impacts.mjs` command.

Fire-ring/burst/smoke sprites explicitly do not cast engine shadows. The
travelling Ember owns one warm shadow-free OmniLight3D; its energy/radius follow
the same trail-growth/fade envelope as the fireball. It stays hidden during
release delay and turns off at arrival/cancellation. Volumetric fog lighting
is disabled and no logical fog/discovery state or terrain material is changed.

Razor Leaf retains the custom three-direction crossing slashes plus Vine Whip
impact bursts/torn leaves, now at exactly twice the previous display size.
Bubble's five-pop artwork/size are unchanged. These two sheets remain48 frames
of64x48 in6x8 grids and play over0.25s. The configurable impact shader supports
both atlas formats without changing the stat-feedback shader.

Main holds the round through each impact, then applies damage and begins the
existing0.25s Hurt /0.25s Idle recovery. Ember waits0.5s before Hurt. Cancellation suppresses stale damage.
Same pinned revision and MIT/third-party notices apply. No stock actors,
acted moves or fonts are exported.

## Basic move hit feedback

Tackle/Pound's flash is now a centered eight-point star with equal-length
rays throughout growth/fade, displayed at2.5x the original baseline. The
former directional right-hand streak is removed; duration remains0.12s.

The same exporter also writes `basic_hit` and `scratch_hit` PNG/JSON pairs
(48 frames,64x48 cells,6x8 grid). `basic_hit` adapts only Hit Spark's shining
cross/diamond and glow, with no spark spray/chips/particles, for Tackle/Pound
over0.12s. `scratch_hit` uses three simultaneous white tapered diagonal
slashes over0.25s, spaced8 source pixels apart with four white chips per
stroke. Both are body-centered overlays using the existing hit effect helper.
Scratch lines are50% longer (21x48 endpoint delta instead of14x32), centered
on the same positions with unchanged width/spacing. Its48-frame sheet now uses
64x64 cells in a7x7 atlas to avoid clipping; physical pixel size is unchanged.
Named melee impacts now use per-profile `melee_contact_frames`: Chimchar
Scratch frame5 (return-start pose), Piplup Attack frame6, Turtwig Attack frame5,
and Stunky Attack frame7. Native frame durations remain unchanged. Scratch
starts its0.25s swipes at that pose, then applies damage/Hurt; Pound/Tackle
show the flash and apply damage at their contact pose. No
post-hit wait or PP/damage-value change is added. Space/basic attacks without a move ID
retain their existing presentation.

## Final-floor torch flame

`assets/effects/pixelfx/torch_flame.{png,json}` adapts the pinned upstream
`fire/torch` tongue/burn recipe, excluding its drawn bracket, handle and wrap.
Flame, smoke and embers loop for 2 seconds at 30fps (60 frames, 72x120 cells,
10 columns, source origin36,94). Existing license and Hugo Duprez notices apply.
Reproduce from the project root with Node18+:

```powershell
node tools/pixelfx/export_torch_flame.mjs <path-to-pixelfx-checkout>
```

FinalCorridorEnvironment shares one SpriteFrames resource across all torches,
uses nearest-filtered upright billboards, and positions each flame at the native
3D torch cup. Original OBJ and upstream source are unchanged.

## Dragon Breath

`assets/effects/pixelfx/dragon_breath.{png,json}` exports pinned upstream
`ice/frost-breath` with its original colors/shape, at40fps (48 looping frames,
6x8 cells of184x104, mouth origin12,50). Runtime uses the artwork for a
Dragon-type two-tile move. Reproduce with Node18+ from the project root:

```powershell
node tools/pixelfx/export_dragon_breath.mjs <path-to-pixelfx-checkout>
```

Existing MIT license / Hugo Duprez attribution applies.

## Final-corridor dread sky

`assets/effects/pixelfx/dread_sky.{png,json}` combines the pinned checkout's
`core/scene.js` sky backdrop, `weather/aurora`, and `weather/fireflies`.
Aurora palettes are dark/pale purple; subtractive compositing dims the sky and
stars under the curtains, with a subdued violet body. Fireflies retain upstream
motion/pulses/wings but use purple light; meadow/grass/haze are excluded.
No fonts/actors are included. Existing MIT/Hugo Duprez notices apply.

```powershell
node tools/pixelfx/export_dread_sky.mjs <path-to-pixelfx-checkout>
```

Output is144 frames at12fps over a12-second loop (320x180 cells,9x16 atlas).
Runtime uses one nearest-sampled, unlit background quad, depth-tested behind
geometry. It neither lights nor darkens actors and adds no per-frame CPU image
processing, particles, radiance updates or gameplay RNG draws.

### Darker sky and single Eclipse

The dread-sky exporter now shifts both aurora ramps three palette levels darker
and reduces the plain sky to near-black purple. It renders aurora stars separately
with the previous palettes; firefly palettes/motion remain unchanged.
The same command also exports `dread_eclipse.{png,json}` from `shadow/eclipse`,
excluding its extra surrounding stars (48 frames at12fps,4s loop,160x144 cells,
7x7 atlas). The shader composites it once at the visible sky center, independently
of the sky's3x mirror-repeat zoom. PixelFX's existing MIT notices apply.

## Spiritomb reveal transitions

`spiritomb_glitch.{png,json}` uses pinned `transitions/glitch-wipe` source time
0?0.8s (25 frames,4x7 atlas). `spiritomb_dissolve.{png,json}` uses
`transitions/pixel-dissolve` source time1.1?2.2s (34 frames,5x7 atlas).
Both are320x180/30fps, nonlooping, transparent overlay exports with black ink.
The game holds solid black separately for3 seconds. Existing MIT/Hugo Duprez
notices apply; no upstream files are modified.

```powershell
node tools/pixelfx/export_spiritomb_transitions.mjs <path-to-pixelfx-checkout>
```

## Spiritomb test moves

`tools/pixelfx/export_spiritomb_moves.mjs` renders the pinned checkout's
weather/blizzard as purple Ominous Wind,shadow/void-orb as Shadow Ball,
shadow/dark-explosion without the central shrinking sphere as its impact,
and arcane/arcane-missiles as a slower dark-purple/black Dark Pulse volley.
All weather/volley whites are mapped into purple; native actor artwork is excluded.
Sprite sheets and per-sheet layout/runtime pivots live in matching PNG/JSON assets.
Existing MIT/Hugo Duprez notices apply; upstream source is not modified.

```powershell
node tools/pixelfx/export_spiritomb_moves.mjs <path-to-pixelfx-checkout>
```

### Shadow Ball revision / Dark Pulse removal

Dark Pulse was removed at user request; its earlier adaptation notes are historical.
The Spiritomb exporter now emits only Ominous Wind,Shadow Ball and Shadow Ball's
impact. Explosion adaptation removes ground rings/glow,dust,ground smoke and
resting shards/wisps; airborne smoke/particles remain. Runtime orb scale is90%
of the initial size and animation plays at30fps (2x original15fps sampling).

Ominous Wind now excludes Blizzard's ground/snowbank pass entirely and uses
lighter lavender/stronger near wind sheets. Shadow Ball uses opt-in camera-plane
billboarding so its circle is not foreshortened by camera pitch.

Recovery uses the pinned upstream `src/fx/holy/heal.js`, exported without actor/background by `tools/pixelfx/export_recovery.mjs`. Original palette and rising hoop/sparkles are preserved; runtime scales the effect to native Pokémon body height. See existing PixelFX license and revision above.
The Recovery adaptation removes Heal's internal `recolor(p, A, ...)` body drawing as well as disabling the stock actor pass, preserving effects around the native Pokémon.

Healing Bloom uses upstream `src/fx/nature/healing-bloom.js` at the pinned revision above, exported via `tools/pixelfx/export_healing_bloom.mjs`. Flower geometry (stem, leaves, bud, petals and central flower heart) is omitted; healing glow/rings/crosses/motes remain. Output: `assets/effects/pixelfx/healing_bloom.png` and `.json`. The upstream effect credits Sprite Fusion's heal by Hugo Duprez (MIT, 2026); accompanying LICENSE/NOTICE apply.

## Tutorial Electro Ball

`tools/pixelfx/export_electro_ball.mjs` exports `electro_ball`,
`electro_ball_hit` and `electro_ball_shock` PNG/JSON pairs from the same pinned
revision above. Run from the project root:

```powershell
node tools/pixelfx/export_electro_ball.mjs <pinned-pixelfx-checkout>
```

Sources: `lightning/ball-lightning.js` (stationary core, straight rear wake;
wandering and floor zaps omitted), `lightning/charge-up.js` (release segment
only, no stock actor silhouette), and `lightning/electrified.js` (short arc/spark
segment around neutral ellipse endpoints; stock body/outline omitted). Source
palette and original credits remain. Runtime moves the ball along the grid lane
and sizes the electric crackle around the native target. Upstream files are
unchanged; no stock actors are included in the exported sheets.
