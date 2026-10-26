# Spacious rooms and bounded cave backing

The standard configuration remains **42×32**, now requesting **6–9 rooms**, widths
**5–8**, and heights **5–7**. Edit `config/standard_generation.tres` to change these
ranges. Limit Testing keeps its own Resource and fixed benchmark. Legacy generation
settings and the boss arena were not changed.

Only standard configuration values and explicit map-extent metadata were added to
generation. Placement, room-order connections, two-level assignment, flat routing,
ramps, retry bounds, and the forbidden camera-hidden ramp orientation are unchanged.
The permissive placement-exhaustion behavior is retained; no new hard room minimum
was introduced.

## Seeded room comparison

Godot 4.4.1, seeds 0–99 per configuration, map 42×32. Every profile had **100% random
generation success, zero fallbacks, zero room-count shortfalls, no room overlaps,
and valid ramp/room/staircase/enemy reachability**.

| Configuration | Actual count distribution | Mean room area | Floors retried | Mean layouts | Mean ramp candidate attempts | Mean corridor cells |
| --- | --- | --- | --- | --- | --- | --- |
| Previous 5–7, widths 4–7, heights 4–6 | 5:46, 6:29, 7:25 | 26.55 | 44% | 1.78 | 2.45 | 66.25 |
| 6–8, widths 5–8, heights 5–7 | 6:38, 7:32, 8:30 | 37.89 | 76% | 3.12 | 6.38 | 73.85 |
| Selected 6–9, widths 5–8, heights 5–7 | 6:39, 7:32, 8:19, 9:10 | 37.99 | 74% | 3.27 | 6.37 | 72.24 |
| 6–8, widths 6–9, heights 5–8 | 6:52, 7:24, 8:24 | 47.04 | 64% | 2.85 | 3.88 | 61.33 |

Room-to-room chain traversal distances (median / 90th percentile / maximum):

- Previous: 20 / 37 / 88 tiles.
- 6–8 moderate rooms: 21 / 38 / 84 tiles.
- Selected 6–9 moderate rooms: 20 / 35 / 82 tiles.
- Larger 6–8 rooms: 21 / 35 / 59 tiles.

Distances use actual `can_traverse()` flood-fill between successive room centers,
including room interiors and shared routes. They are not isolated carved corridor
polyline lengths. Corridor-cell totals separately count actual CORRIDOR tiles,
including buffers. No distance measurement affects acceptance or routing. The
selected profile offers count variety with about 43% larger mean rooms, at the cost
of more generation retries. Nine-room floors remain less frequent because existing
routing/acceptance constraints naturally bias the accepted sample.

Run `tests/diagnose_spacious_rooms.gd` to reproduce all 400 floors. JSON output is
`res://.godot/quality_diagnostics/spacious_rooms.json`.

## Why empty regions existed

The original nearest-source filler covered an expanded bounding rectangle, but the
validated renderer correctly removed upper/ramp-owned arbitrary backing. Remaining
cells could consequently have no visible terrain. Also, only first-ring lower filler
used the modeled ceiling cap; farther filler was a plain box.

`DungeonData.map_bounds` now records the actual configured map extent, including
fallback generation. It is metadata, not additional tiles or gameplay occupancy.
The renderer never infers background extent from room bounding boxes.

## Fill rules

On standard validated floors, the rendering-only background partitions every
nonwalkable cell inside map bounds:

1. Keep existing lower backing or an intentional terrace where already present.
2. Leave protected voids around reserved ramps, both approaches, and upper
   corridor walkways. Walkable cells are always excluded.
3. Fill remaining cells with a one-unit-deep stone backing whose top is **Y=0**,
   below the existing lowest walkable surface at **Y=0.1**. This cannot add a
   foreground obstruction at character height.

The low backing is distinct from half-height conventional walls, three-unit room
foundations, terraces, and shallow walkway undersides. It does not extend those
structures upward or add another gameplay elevation. Protected voids and space
outside the map can remain visible; complete solid coverage there would conflict
with the requested platform/ramp presentation.

The new backing uses **two MultiMeshInstance3D nodes per 8×8 spatial group** (bodies
and caps), not one node per cell. There are at most 48 new mesh nodes at 42×32.
Grouping lets the renderer cull distant model detail instead of drawing a single
map-wide instance batch. Existing boundary/terrace nodes retain their selective
occlusion registration. Low background is excluded from sprite occlusion because
its complete bounds are below all supported gameplay surfaces. It receives lighting
and shadows but does not cast unnecessary background shadows onto gameplay.

## Ceiling appearance and controls

Existing boundary and terrace filler receives modeled ceiling caps at all distances,
not just one ring. Caps reuse the existing gray ceiling material and floor relief;
no new bitmap textures or source assets are introduced. Vertical sides have their
own stone material surface. Foundations, ramps, wall/corner transitions, and bridge
placeholders keep their existing geometry/material roles.

Inspector settings on DungeonRenderer:

- `cave_fill_enabled` (true): disable to compare against the preceding geometry.
- `cave_ceiling_variation_enabled` (true): coordinate-hashed quarter turns and tint.
- `cave_ceiling_color_variation` (0.03): neutral ±3% brightness, nine discrete tints.
- `cave_batch_chunk_size` (8): spatial batch width; smaller groups improve culling
  but add draw/scene overhead, larger groups draw more off-screen instances.
- Existing `floor_visual_seed`: shared independent visual seed, no generation RNG.

Rotation is applied only to square cap/body pieces, never directional art. The cap
and side surfaces are separate; color variation affects caps rather than wall faces.
Fog colors derive from existing bright state/adjacent ownership and reference
elevation. Instance multipliers are calculated in linear color space to match the
existing per-mesh albedo brightness, rather than making batched fog too bright.
No visibility, discovery, movement or enemy rules were changed.

The feature is limited to explicitly bounded, validated two-elevation procedural
floors. Benchmark, legacy fixture, boss arena, and rendering bypass modes retain
their previous presentation.

## Coverage, performance and testing

Twenty selected-profile floors yielded 20,068 nonwalkable cells:

- 9,154 already covered by existing terrain.
- 9,350 filled by the new backing.
- 1,564 intentionally protected voids.
- 836 added mesh nodes across all 20 floors (41.8 average, at most 48 per floor),
  covering 18,700 body/cap instances; zero unresolved coverage violations.

`tests/validate_cave_background.gd` checks complete gameplay-data/RNG equality
before/after rendering, bounded disjoint coverage, protected areas, unchanged
foundations/walkways/ramps, deterministic cap transforms/tints, two-surface ceiling
materials, fog colors, repeatability, and exempt fixtures.

Godot's headless Dummy RenderingServer returns identity for MultiMesh transform
readback. CPU plans are validated headlessly; the normal-renderer capture script
independently reads actual transforms and colors back after submitted frames.

Run `tests/capture_cave_background.gd` without `--headless` for Forward+ captures
and short 180-frame before/after samples on an identical seeded layout. Output is
`res://.godot/cave_background/`: PNGs plus `performance.json`. This comparison
isolates the visual cave changes on the selected larger-room configuration; it does
not isolate the performance effect of changing room sizes. It does not change
camera, VSync, FPS caps, lighting, or resolution settings. The capture tool blocks
gameplay/restart input only during its comparison, so keyboard input cannot move
the player/camera or trigger enemy turns between samples.

On the available AMD Radeon RX 6800 XT, the final fixed-view Forward+ sample at
1920×1080 measured 15.99 ms average before versus 16.38 ms after (about 0.39 ms added;
62.6 versus 61.1 sampled FPS). The 95th-percentile intervals were 26.51 and 23.89 ms.
These short desktop samples include scheduling noise and are **not evidence of
sustained 60 FPS**; both modes had frames above 16.67 ms. Repeat representative
exploration/combat and OBS recording locally. Geometry/transform/color readback
passed in the actual normal renderer, and before/after images were inspected.

Headless import and the full 34-script regression suite passed. Final cave/fog/
lighting/mode checks and the spatial-batch test also passed. Existing shutdown
resource warnings still occur in some presentation tests.

Manual review should cover lower-room borders, upper walkways, ramps in both
directions, staircase transitions, fog and fading restoration, all three modes,
and 1080p recording performance with OBS. Tiny cracks/relief are from the source
tile artwork; protected void cutoffs remain a deliberate prototype limitation.
