# Rocky terrain joins and restored relief

This revision replaces the first narrow-bevel prototype after visual review. Changes remain uncommitted on `Midterm`; gameplay topology, generation, camera and the optimized turn/sprite systems are unchanged.

## Shape

`CaveRockSlopes` builds a floor-lifetime visual height field from the existing ground/terrace records and required upper-room foundation height. A shared corner takes the highest nominal surface touching it. Eligible ground has broad half-pyramid sides reaching those shared corners, with an angular central plateau. Tiny enclosed depressions fill rather than becoming a repeated grid of inverted pyramids. Flat compatible regions still merge within the existing chunks; internal side bands still disappear.

For decorative terraces, the entire roof slopes between neighboring band heights. For example, an unobstructed chain connects ground to 1.1, 2.1 and the actual upper foundation underside (~2.94), without flat intermediate shelves. Adjacent bands share their edge vertices. This extends the visible rocky pyramid shape toward the upper platform while retaining its three required foundation layers and flat playable floor.

Only presentation records change. Terrain remains inside its original horizontal cell footprint. Terrace rendering bounds explicitly include the new upper join, so instance validation and selective occlusion use the actual geometry. The sloped mesh retains its existing two surfaces, fog variants, owner and shadow behavior; directional profiles never receive random quarter-turn rotations. No new scene node is created for a slope.

## Clearance and reversibility

- Required room foundations and shallow corridor supports keep their full original volumes.
- Ramps, approach halos, bridge underlays, conventional lower walls and protected lower-path cells retain their original shape.
- Proposed raised corners undergo the existing conservative lower-path camera-risk test using the configured camera pitch. Unsafe cells retain their previous geometry. A protected transition can therefore retain a vertical face rather than force a slope into player clearance.
- Ground beneath a terrace remains a low plinth; it is not raised into a second overlapping terrace roof.
- No new walkable surface, collision/navigation object, exploration cell or gameplay RNG call exists. Identical seeds intentionally have a new decorative silhouette, while DungeonData and generation RNG match exactly.

The existing `cave_weathered_edges_enabled` switch now controls these connected rocky slopes. Disable it for stepped continuous ground; disable continuous ground and stone mapping too for Graphics Checkpoint 1. Retained historical bevel screenshots/data remain under `.godot/continuous_terrain/`.

## Texturing

The authored cap's cracks/chips were modeled geometry, which the first lightweight surfaces lost. `CaveStoneMaterial` now rasterizes the original FLOOR mesh's height relief once into a reusable 128x128 stone texture and normal map. Cropping removes its outer tile rim, and a four-texel periodic edge treatment avoids a new tiled border line while retaining sharp interior detail. Subtle deterministic mineral grain remains. A separate roughness texture keeps cracks rough rather than making them glossy.

Ground uses the existing three world-space stone samples, plus derivative relief from the same sampled signal without further texture reads. Standard cliff materials use shared world-triplanar albedo, normal and roughness textures. Mipmaps keep distant detail stable. Source OBJ/MTL assets are untouched. The texture resources are shared, and geometry/corner/plateau caches are owned by the current floor. There is no extra per-frame terrain scan or mesh rebuild.

## Validation and measurements

`validate_rock_slopes.gd` checks an explicit ground/three-band fixture: shared corners, upward continuation to the actual foundation underside, no flat intermediate roof, exact actual mesh bounds, intact required foundations, recovered authored relief and unchanged DungeonData/RNG. `validate_continuous_terrain.gd` additionally checks six generated seeds, required geometry, fog palettes, protected underlays, deterministic joins, rollback, mesh winding and unchanged idle palette uploads.

All **39/39 validation scripts** reported PASS, with no script/assertion/parse/shader errors; affected geometry/slope/wall tests were rerun after mesh sharing. The 29-frame Python source-alpha/hash check also passed. Normal Forward+ images and samples completed successfully. Existing restricted-environment certificate/editor-settings/shader-cache save errors remain; the GPU process exits 1 after cache-save errors despite completing its PASS capture.

Pooled results across ten identical poses, 1,200 measured frames per half:

| Metric | Narrow bevel before | Connected slopes after |
| --- | ---: | ---: |
| Mean frame ms | 10.004 | 9.998 |
| p95 frame ms | 11.161 | 10.804 |
| p99 frame ms | 13.649 | 12.643 |
| Mean viewport GPU ms | 4.315 | 4.277 |
| Mean render CPU ms | 2.696 | 2.695 |
| Mean draw calls | 352.600 | 432.200 |
| Frames over 16.67 ms | 0.083% | 0.083% |
| Ground mesh nodes | 41 | 41 |

One frame in each half exceeded 16.67 ms; worst intervals were 16.889 and 18.479 ms. Frame intervals include display/scheduling effects and do not establish the cause of the outliers. Mean GPU/CPU budget is effectively unchanged within short-run noise, and the p95/p99 intervals remain below 16.67 ms. These results support retaining current 60 FPS headroom in the sampled views, not guaranteed spike-free play.

Sloped roofs add distinct geometry shapes, increasing average draws from about 353 to 432. Reusing identical local shapes within the floor reduces this from the initial unshared implementation (~474), without merging fog or selective-occlusion ownership. Rendered primitives decrease because the sloped decorative roofs no longer require dense repeated cap geometry. Engine static-memory readings increase by about 1.58 MiB, including floor-local corner/plateau profiles, mesh variants, baked normal/roughness textures and allocator state. This is not isolated VRAM accounting. Caches clear on floor rebuild; texture maps are shared for the process lifetime.

| Seed / pose | GPU ms before -> after | p95 frame ms before -> after | Draws before -> after |
| --- | ---: | ---: | ---: |
| 4 / spawn | 3.789 -> 3.719 | 11.456 -> 11.581 | 367 -> 403 |
| 4 / edge | 2.590 -> 2.587 | 11.090 -> 10.856 | 123 -> 139 |
| 4 / ramp | 4.362 -> 4.343 | 10.934 -> 10.903 | 480 -> 573 |
| 4 / bridge | 4.653 -> 4.580 | 11.403 -> 11.310 | 325 -> 431 |
| 4 / terrace | 4.281 -> 4.143 | 10.253 -> 10.400 | 374 -> 444 |
| 17 / spawn | 4.943 -> 4.678 | 10.838 -> 10.849 | 342 -> 433 |
| 17 / edge | 4.396 -> 4.372 | 11.124 -> 10.743 | 360 -> 470 |
| 17 / ramp | 4.276 -> 4.366 | 10.160 -> 10.628 | 395 -> 510 |
| 17 / bridge | 4.901 -> 5.209 | 10.901 -> 10.499 | 365 -> 434 |
| 17 / terrace | 4.957 -> 4.768 | 12.303 -> 10.496 | 395 -> 485 |


Normal-renderer captures and raw before/after timings use seeds 4 and 17 at spawn, upper edge, ramp approach, shallow bridge and terrace-owner positions. Both halves run the same current dungeon data at actual 1920x1080 Forward+, 100 Hz V-Sync, max_fps=0, 60 warmup/120 sampled frames per pose, with no concurrent test runner. Outputs: ignored `.godot/rock_slopes/`, including `before.json`, `after.json` and matching screenshots. These short idle samples do not certify sustained enemy-turn tails, floor loading or OBS recording.

Changed rendering files: `cave_rock_slopes.gd` (new), `cave_ground_surface.gd`, `cave_stone_material.gd`, `dungeon_renderer.gd`, `shaders/cave_ground.gdshader`. The existing generator, traversal, combat, enemy action order, fog rules, camera, sprite cache and source art remain untouched. Updated validation and handoff/report documents accompany the change.
