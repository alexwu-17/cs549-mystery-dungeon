# Continuous cave terrain — Stages 2–4

Built against the `Midterm` checkpoint `60aac1a`, Godot 4.4.1 Forward+. Changes remain uncommitted. These are small reversible presentation prototypes, not a replacement for DungeonData or the environmental geometry planner.

## Configuration and rollback

Three DungeonRenderer inspector settings default to true:

- `cave_continuous_ground_enabled`: chunk ArrayMesh ground instead of the old cap/body MultiMeshes.
- `cave_stone_mapping_enabled`: shared world-space stone detail on cave ground, distant apron and planned foundation/terrace/boundary materials. Walkable floors, conventional walls, ramps and shallow walkway supports retain their art/materials.
- `cave_weathered_edges_enabled`: connected half-pyramid ground sides and coherent decorative terrace roofs, effective only with continuous ground. The initial narrow bevel prototype was superseded after visual review; see [rocky terrain slopes](rocky_terrain_slopes.md).

Disable all three to reproduce Graphics Checkpoint 1, including its six-tile scenery border. The border's existing width setting remains independent. Mapping also works with the original ground MultiMeshes. No source artwork or project startup settings were changed.

## Stage 2: continuous ground

`CaveGroundSurface` consumes the existing CaveTerrainBackdrop records without changing their cell, height, ownership, structural or protected classification. It emits one mesh per existing 8×8 spatial chunk. Adjacent flat coplanar tops merge into rectangles within a chunk; neighboring occupied ground volumes hide their shared side faces, including across chunk boundaries. Visible side bands remain. Bottom faces are omitted because the normal camera stays above ground.

This applies only to background ground. Existing conventional walls, required three-layer foundations, decorative terraces, ramp models and shallow upper-corridor supports retain their original instance geometry and selective occlusion ownership. Ground under bridges remains at its previous low height; legitimate air space is preserved.

Fog ownership is independent of merged faces: one small RGBA8 texture stores each record's existing bright/dim/other-elevation shade and top tint. The shared shader chooses the exact column from local position, with an inward bias on vertical faces. Texture sampling is nearest filtered without mipmaps; the stone texture uses separate mipmaps. Existing Main visibility invalidation still schedules updates. No process callback, per-frame rebuild, added occlusion collection or arbitrary update throttle exists. Unchanged colors skip writes and the texture uploads once only when values change. External scenery still ignores discovery and updates only with the global elevation palette.

The standard 54×44 visual footprint uses a 9.3 KiB fog texture. Its RGB quantization is at most one 8-bit level; logical fog shades remain exact and unchanged. Each floor owns its meshes/material/palette; replacing the floor releases them. There is no accumulating global ground mesh cache.

## Stage 3: shared stone mapping

`CaveStoneMaterial` bakes the original FLOOR model relief into a shared 128x128 stone texture and normal map, with mipmaps and subtle deterministic mineral grain. This restores visible cracks/chips on the lightweight surfaces. It consumes no random generator state and never changes the OBJ. Ground uses three world-space samples and derivative relief without extra texture reads; existing cliff materials use world triplanar albedo/normal/roughness mapping while keeping their fog states, opacity/shadow handling and foundation layer tints.

The renderer makes floor-owned stone variants once per distinct source material, reusing them within that floor; it never edits the original cached materials. The distant apron uses the same texture. No parallax, transparency effect, animated noise, displacement shader or additional shadow caster is introduced. Three physical foundation layers remain recognizable; this pass does not merge their occlusion ownership.

## Stage 4: controlled edge refinement

The initial eight-centimeter bevel was replaced by broad connected slopes after user review. Ground retains angular central plateaus, with sides reaching shared neighboring heights. Enclosed tiny depressions fill to avoid a field of inverted pyramids. Decorative terrace roofs slope continuously between the nominal one-unit bands and the upper foundation underside, rather than keeping a flat shelf on each band. Required three-layer foundations, ramps and bridge supports remain intact. Protected/camera-risk cells retain their safe original shape. See [current construction, safety checks and measurements](rocky_terrain_slopes.md).

## Validation

`validate_continuous_terrain.gd` checks six fixed seeds across Stages 2/3/4: identical full DungeonData snapshots/generation RNG and required structural transforms/bounds; unchanged planned record heights/protection; coplanar merging/internal-side removal; chunk bounds/counts; finite vertices, normalized normals and clockwise front faces; watertight same-height chunk corners; neighbor-derived slope ceilings and untouched protected underlays; correct immediate fog palettes through elevation and discovery changes; no static palette uploads/mesh rebuild; shared stone textures and independent fallback switches.

The existing cave-background, scenery-border and authored-wall-style tests explicitly select their original material/batching paths so their original identity/readback contracts remain covered. Other regression tests exercise the new defaults.

Normal Forward+ captures inspect fixed seeds 4 and 17 at spawn, upper edge, lower ramp approach and shallow upper bridge. Captures and raw timings live in ignored `.godot/continuous_terrain/`. The initial GPU inspection caught an incorrect face winding; it was corrected and covered by a new assertion before final measurements.

## Earlier bevel prototype benchmark

These historical numbers describe the first bevel prototype. The subsequent user-requested rocky-slope revision has its own matched before/after results in [rocky terrain slopes](rocky_terrain_slopes.md).

Run the repeatable comparison with normal rendering (not headless):

```powershell
& $godot --path . --log-file .godot/continuous_terrain/benchmark.log --script res://tests/capture_continuous_terrain.gd --quit-after 20000
```

Each view is rebuilt from the same DungeonData for four stages: checkpoint, continuous ground, stone mapping, weathered rims. Each warms 60 frames and samples 120 at actual 1920×1080, Forward+, V-Sync enabled on a 100 Hz display, max_fps=0. Dungeon/RNG invariance is asserted on every rebuild. Input and the FPS overlay are disabled; the cached sprite and fog optimizations remain enabled in every half. No other profiling/test runner runs during the final capture. Results below are short idle comparisons, not sustained combat/OBS certification.

The following table pools the eight matched views (960 sampled frames per stage). Each row after the checkpoint is compared with the preceding row; GPU/draw values are averages across those same views. Frame times remain display-limited, so the GPU measurement is the clearer headroom signal.

| Stage | Mean draw calls | Ground mesh nodes | GPU mean ms | Frame mean ms | Frame p95 ms | Frame p99 ms | >16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Checkpoint | 350.6 | 81 | 4.554 | 10.015 | 10.466 | 12.670 | 0.0% |
| Continuous ground | 344.6 | 41 | 4.208 | 10.000 | 10.245 | 11.015 | 0.0% |
| + shared stone mapping | 344.6 | 41 | 4.285 | 9.982 | 10.242 | 11.040 | 0.0% |
| + weathered rims | 344.6 | 41 | 4.271 | 9.976 | 10.285 | 11.168 | 0.0% |

Per-view checkpoint -> final comparison:

| Seed / view | Draw calls | GPU mean ms | Frame p95 ms | Rendered primitives |
| --- | ---: | ---: | ---: | ---: |
| 4 / spawn | 374 -> 367 | 4.044 -> 3.819 | 10.351 -> 10.247 | 1,267,422 -> 1,254,790 |
| 4 / edge | 129 -> 123 | 3.648 -> 2.648 | 10.223 -> 10.340 | 296,715 -> 285,715 |
| 4 / ramp | 484 -> 480 | 4.613 -> 4.436 | 10.701 -> 10.384 | 2,471,035 -> 2,464,269 |
| 4 / bridge | 330 -> 325 | 4.824 -> 4.757 | 10.467 -> 10.266 | 1,805,993 -> 1,796,937 |
| 17 / spawn | 350 -> 342 | 4.934 -> 4.734 | 12.716 -> 10.339 | 2,012,118 -> 1,998,094 |
| 17 / edge | 367 -> 360 | 4.735 -> 4.373 | 10.738 -> 10.338 | 1,786,068 -> 1,773,614 |
| 17 / ramp | 400 -> 395 | 4.426 -> 4.321 | 10.235 -> 10.272 | 1,839,250 -> 1,830,084 |
| 17 / bridge | 371 -> 365 | 5.207 -> 5.082 | 10.227 -> 10.210 | 2,392,428 -> 2,382,012 |

Each new stage remains below the checkpoint GPU average. Small stage-to-stage GPU timing differences include scheduling/clock noise; weathering is not itself a speed optimization. Ground nodes decrease from 80 MultiMesh nodes + one apron to 40 ArrayMesh instances + one apron. Total scene nodes fall by 40; the MeshInstance3D subclass count increases because those replace MultiMeshInstance3D nodes. Selective wall/foundation instances are unchanged.

Seeds 4/17 emit 4,950/5,342 ground triangles without weathering and 9,386/10,476 with the final bevel rims; 4,942/5,254 shared side faces are omitted. Only visible chunks contribute to the per-view primitive counts above. Existing detailed environmental meshes still dominate those counts.

Measured render CPU means are 2.667 -> 2.621 ms across the eight views. Final engine static memory averages about 0.79 MiB below the checkpoint: chunking saves about 1.68 MiB, shared mapping adds about 0.87 MiB, and bevels add about 0.01 MiB in this monitor. These are allocator/engine monitor readings, not isolated resource or VRAM accounting. No extra palette upload occurred during any warmed idle sample.

All 3,840 sampled frames stayed below 16.67 ms; the slowest final-stage frame was 12.457 ms. Smooth 60 FPS remains achievable in these measured idle views, with approximately 100 FPS under the current V-Sync setting. This does not remeasure enemy-turn tails, floor loading, OBS recording or other hardware.

Headless import/class registration completed; all **38/38 validation scripts** reported PASS with no script/assertion/parse/shader errors, including focused reruns after the final mesh changes. The 29-frame Python sprite/source-hash check also passed. Normal GPU captures completed with PASS and valid images/timings. This restricted environment still reports certificate-store/editor-settings access errors and shader-cache save errors; the GPU process exits 1 after cache-save errors despite completing its capture. No shader compilation failure remains. Existing shutdown resource warnings are separate cleanup concerns.


## Files and limits

Changed rendering files: `dungeon_renderer.gd`, `cave_terrain_backdrop.gd`; added `cave_ground_surface.gd`, `cave_stone_material.gd`, `shaders/cave_ground.gdshader`. Added focused validation and a repeatable GPU capture/benchmark helper; updated fallback test settings and the handoff/report. Godot-generated UID companions belong with the new scripts/shader.

The renderer still contains detailed, individually owned wall/foundation/terrace geometry. This prototype intentionally does not merge them or remove their three-layer structure. Conventional masonry silhouettes remain angular. Fogged surfaces are deliberately dark, so the new surface detail is subtle there. CPU turn/pathfinding/loading costs are outside this change. Future art tuning can adjust texture contrast or expand decorative edge treatment, but must preserve protected joins and be measured against the retained fallback.
