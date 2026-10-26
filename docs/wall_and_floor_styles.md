# Short walls and deterministic floor styles

All settings are on the shared DungeonRenderer. The selected initial wall-height
scale is **0.5**. Restart/re-render to apply Inspector changes to existing meshes.

| Setting | Default | Meaning |
| --- | --- | --- |
| `conventional_wall_height_scale` | 0.5 | 1.0 = original, 0.75 = three-quarter, 0.5 = half-height. |
| `floor_variation_enabled` | true | Master switch for lower-floor appearance variation. |
| `floor_quarter_turns_enabled` | true | Coordinate-hashed 0/90/180/270-degree rotations of compatible standalone square floors. |
| `floor_color_variation` | 0.04 | Brightness variation of ±4%, quantized to nine neutral tints. Zero disables tint variation. |
| `floor_visual_seed` | 0 | Independent visual seed; does not consume any gameplay RNG. |

For the original appearance, use wall scale 1.0 and disable floor variation.
No imported OBJ, MTL, texture, camera, generation or gameplay files were changed.

## Asset handling

The renderer already separates imported floor-wall and corner mesh surfaces:
surface 0 is the floor component; remaining surfaces are the wall components.
Standalone `wall.obj` instances and those isolated wall surfaces receive the same
Y scale, anchored at the existing floor contact plane. X/Z dimensions, rotations,
corner connections and floor geometry remain unchanged. No procedural replacement
or new Blender asset is required.

Ordinary lower-level boundary filler caps follow the scaled wall top through
`TerrainFillVisuals.wall_top_offset()`, including the validated environmental plan.
Leaving those caps at their original height would defeat the visibility experiment.
Walkable elevation-0 surfaces stay at Y=0.1 (the existing surface offset).

The current imported wall extends approximately 0.8412 units above that plane:

| Scale | Visible rise above floor | Approximate top Y |
| --- | --- | --- |
| 1.0 | 0.8412 | 0.9412 |
| 0.75 | 0.6309 | 0.7309 |
| 0.5 | 0.4206 | 0.5206 |

Upper room floors, full three-unit foundations, shallow upper-corridor supports,
ramps and their buffers are excluded from these changes. The original occlusion
fallback continues to operate on each mesh's actual scaled bounds.

## Floor variation limits

Rotation applies only to standalone square floor assets at elevation 0. Combined
floor-wall/corner surfaces keep their authored orientation. Their floor components
can receive the subtle tint variation, but their walls do not. Staircase tiles,
ramps, reserved buffers and upper platform/walkway geometry retain their original
appearance and orientation.

Quarter turns rotate the existing geometry and UVs together. No vertex, UV, texture
or source material is edited. Shared material variants preserve the existing fog
brightness states. A mixed coordinate hash avoids regular low-bit rotation patterns;
the separate visual seed does not affect placement, routing, spawns or turn order.

## Inspection and tests

The normal Forward+ renderer was inspected at 1920×1080 and the unchanged 35-degree
camera, using identical fixed room/corridor/corner layouts for all three heights.
50% makes the character and foreground tiles most readable. 75% preserves more
wall height but still covers more of the lower sprite. Neither setting eliminates
all obstruction, especially in corners; keep selective fading enabled.

Coarse opaque-wall sprite-ray probes recorded:

| Location | 100% | 75% | 50% |
| --- | --- | --- | --- |
| Room edge | 3/9 | 3/9 | 3/9 |
| Narrow corridor | 0/9 | 0/9 | 0/9 |
| Corner | 9/9 | 6/9 | 6/9 |

These bounds probes are not pixel occlusion measurements and do not quantify all
the visible improvement in the screenshots. Opaque comparisons temporarily used
wall opacity 1.0 in the capture tool only; the final fallback screenshot restores
normal fading. These are visual captures, not performance benchmarks.

`tests/validate_wall_styles.gd` compares all three ratios across 12 seeded 42×32
floors. It verifies anchors, corner/wall X/Z bounds, floor alignment, filler caps,
unchanged upper/ramp geometry, all four rotations, tint limits, deterministic
re-rendering, visual-seed independence, fog materials, rollback, and complete
DungeonData/factory-RNG equality. The original asset/filler tests explicitly select
100% height for their original-shape assertions.

The full regression suite passed all 33 scripts. Final half-height restart, mode,
fog and appearance checks also passed. The previously failing attack-leap restart
assertion passes with the shorter-wall configuration; attack code was not changed.
Some presentation tests still print existing shutdown resource warnings.

Run `tests/capture_wall_styles.gd` **without** `--headless` to recreate the images
under `res://.godot/wall_styles/`. The capture uses the existing benchmark layout
as a deterministic diagnostic fixture; normal mode selection/configuration is not
changed. `room_100.png`, `room_75.png`, `room_50.png`, corridor/corner counterparts,
and `room_75_fallback.png` are saved there.

Manual follow-up: compare the three Inspector ratios at room edges, turns and
doorways; walk ramps both ways; inspect upper foundations/walkways; verify fog and
fading after attacks, stairs and restart. Try disabling rotation or tint separately.
Source stone/brick relief is vertically compressed at shorter ratios. Dedicated
half-height assets would improve masonry/bevel proportions during art polish, but
are not necessary for the reversible prototype.
