# Procedural elevation

`DungeonData.ELEVATION_HEIGHT` is the single height setting: 3.0 world units
(previously 1.0). `DungeonData.TILE_SIZE` remains 1.0. A procedural slope rises
one level across exactly three tiles: atan(3 / 3) = 45 degrees. Changing the
height to 4.0 later does not change its footprint.

Rooms are flat at -1, 0, or +1. The first room is 0. Chain connections roll
10%, 40%, 70%, then 100% after successive unchanged heights; changing height
resets the next roll to 10%. Same-height corridors retain the two original
L-shaped choices. Incompatible layouts are retried rather than flattened.

Each transition reserves five straight tiles outside rooms: lower buffer,
three ramp tiles, upper buffer. Approach corridors can turn before or after
this footprint. Its side cells remain empty. Same-height intersections away
from transitions remain supported. Overpasses are unsupported: each grid
coordinate has exactly one walking surface.

The router validates candidates before committing terrain. It tries at most
160 footprint candidates per changing-height connection and at most 32
layouts per floor. Exhaustion prints a warning and uses a known-valid two-room
floor with a standardized ramp; it does not silently return a flat map.
`TestDungeonFactory.last_statistics` and the `ELEVATION FLOOR` log expose
layout attempts, footprint attempts, fallback use, dimensions, room heights,
and ramp coordinates. Spawns are placed only after traversal-based flood-fill.

## Ramp asset contract

One mesh represents all three ramp tiles. Buffers are separate floor meshes.
The placeholder prism is produced by `DungeonRenderer.create_slope()`.
Its local origin is the center of the lower edge of the walking surface;
+X is uphill and Z spans the width. Its walking surface runs from X=0,Y=0
to X=3,Y=3, with Z=-0.5 to +0.5. The renderer places that origin at the lower
buffer/ramp boundary, at the lower floor surface, then rotates around Y.
Replace the placeholder mesh in this method with the model, or adapt the
model's pivot and axes to this contract. Keep the geometry width/run fixed;
the authoritative height controls rise.

Entity centers use 1/6, 1/2, and 5/6 of the rise above the lower buffer surface.
Floor surface height includes half the floor thickness. Geometry endpoint and
normal tests cover all four rotations.

`DungeonData.can_traverse()` is shared by movement, BFS, generation validation,
and combat adjacency. It rejects cliff steps and side entry to reserved
transitions, independently of entity occupancy. Space misses still consume
a turn; moving into a skeleton only blocks movement.

## Legacy fixture

Main's **Use Elevation Test** keeps the original room coordinates, spawn,
stairs, and one-tile +X debug ramp. It uses the same 3.0 height setting; its
slope is consequently steeper than procedural ramps. This explicit legacy
exception is never emitted by procedural generation.

## Validation

Run Godot headless with `--path . --script tests/validate_elevation.gd`.
The suite covers 250 seeds each at 30x22 and 36x28, height assignment,
footprints, bidirectional traversal, mesh endpoints/normals, atomic routing
failures, cliff combat, and reachability. Existing floor, turn, combat, and
Space-attack suites remain available in `tests/`.

Manual checks: use F5 in procedural mode; read the printed lower buffer and
uphill direction, walk four steps from that buffer to the upper buffer and
back, inspect ramp seams and standing heights, and lead a skeleton across.
Check Space combat, stairs preserving HP, and R restart. In legacy mode,
clear the pursuing skeleton before traversing (7,2), then use stairs at (11,3).
