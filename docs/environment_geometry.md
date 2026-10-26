# Validated environmental geometry

The default two-elevation renderer now builds and validates an environmental plan
before instantiating support/filler meshes, then checks the instances before Main
reveals the floor. Dungeon generation, gameplay tiles, movement, combat, routing,
elevations, stairs and logical fog/discovery are unchanged.

## Defects found

The preceding terrace prototype deliberately omitted some supporting skirts near
lower visibility stripes. These omissions left open upper-room undersides. Its
nearest-source filler also retained cells owned by ramp tiles, inheriting intermediate
ramp heights and producing raised blocks around transitions. Camera fading could
make an existing block appear missing without the mesh actually being absent.

The old filler boxes were generally grounded, despite looking isolated or floating.
The defects were ownership, continuity, and missing room support—not extra walkable
rooms in the gameplay generator. The user's original screenshot was not attached;
the investigation used code, seeded comparisons, and a newly captured fixture.

## Contract

`EnvironmentGeometryPlan` derives a surface contract and explicit structural and
decorative records from DungeonData. Records contain a stable ID, purpose, source
cell, owner, layer and bounds. Terrace records also contain a predecessor and
distance. Imported base floors, walls, shared ramp meshes and staircase markers
receive purpose/owner metadata through the existing renderer registration path.

- Every upper-room walkable tile has three stacked solid stone layers, each one
  third of `DungeonData.ELEVATION_HEIGHT`. Foundations occupy the room's own X/Z
  footprint. They meet the imported floor's actual underside, extend three world
  units downward, and are never removed by a terrain clearance mask.
- Upper corridors have separate shallow supports. Validated depth is clamped to
  0.1–1.0 world units (default 1.0); an out-of-range setting is reported as a repair.
  The corridor is not given a room foundation. Ramp buffers remain flat corridors.
- Lower conventional floor/wall assets and ordinary lower boundary filler are
  retained. Ramp-owned and upper nearest-source filler is excluded from this plan.
- Terraces are grounded, bounded expansions from upper rooms. A cell is retained
  only when its predecessor was retained, belongs to the same owner, and is at
  least as high. Clipping cannot leave detached outer bands. Void bounds alone
  never authorize decorative geometry; there is no replacement ground-box flood
  across the remainder of the map.
- Decoration excludes all walkable cells, lower backing, corridor/stair clearance,
  reserved ramps, both ramp approaches, and the existing conservative lower-camera
  visibility stripe. Required foundations use selective fading instead of holes.

The grid supports one surface per X/Y coordinate. A foundation cannot occupy a
valid lower passage at the same coordinate in the current representation. It can
project in front of another passage; existing mesh-bound sprite occlusion then
fades it and restores it afterward. Faded geometry still counts as structurally
present; validation does not confuse transparency with missing support.

## Validation and repairs

Pre-render validation checks required supports, layer bounds and continuity,
ownership, protected cells, terrace predecessor chains, expansion limits and
camera-risk flags. An invalid plan is reconstructed deterministically from its
unchanged DungeonData/options, with the detected defects retained as repair records.

Post-render verification checks planned IDs, actual local transformed bounds,
required mesh types, owners, duplicates, floor-height alignment, and floor/wall/
ramp/staircase coverage. Missing, misplaced, duplicate and orphaned planned
instances are repaired in one local pass. Unregistered renderer-owned meshes are
removed and reported. No RNG is consumed.

If unresolved violations remain, there is one structure-only visual rebuild with
terraces omitted. Its diagnostics preserve the reason for fallback. A second
failure returns false; Main retains its existing black introduction/input lock
instead of revealing an incomplete floor. It never regenerates gameplay topology.

`expected_surface_cells` counts logical coverage: three ramp cells can be covered
by one continuous mesh, and one corner model may cover two wall directions.
`expected_planned` and `actual_meshes` count individual structural/decorative meshes.

## Configuration and diagnostics

On DungeonRenderer:

- `geometry_validation_enabled = true`: use the new geometry contract. Disabling
  it restores the preceding terrace prototype, including its known limitations.
- `geometry_diagnostics_enabled = true`: print expected/actual counts, initial
  violations, repairs, fallback reasons and unresolved issues with IDs/cells/owners.
- Existing `upper_terrain_mode`, maximum distance, band width, irregularity,
  clearance and shallow-support properties remain available.
- `upper_terrain_mode = UNLIMITED` explicitly selects the original filler path.
  `upper_elevation_open_platforms = false` retains the original all-walled renderer.

Main preserves benchmark, legacy fixture and boss arena presentation explicitly.
Lower-only and legacy three-elevation/one-tile-ramp layouts bypass the new contract.
Debug bypasses are reported with `geometry_diagnostics.active = false` and are not
claimed to satisfy the new contract.

Use Remote Inspector metadata `geometry_purpose`, `geometry_owner`, and
`geometry_id` to trace generated mesh nodes. `geometry_plan` and
`geometry_diagnostics` are available on the renderer. These diagnostics do not
introduce another authoritative dungeon grid.

## Results

Godot 4.4.1, seeds 0–29, current 42×32 standard configuration, identical gameplay
data rendered before/after:

| Measurement | Result |
| --- | --- |
| Previous unbacked/partially exposed room edges | 561 |
| Missing required foundations after validation | 0 |
| Foundation layer meshes | 6,921 (2,307 complete room columns) |
| Shallow walkway supports | 1,004 |
| Grounded, connected terrace cells | 2,162 |
| Previous ramp-owned filler meshes excluded | 806 |
| Unexpected visual fallbacks | 0 |
| Unresolved violations | 0 |

Tests compare every scripted DungeonData property and factory RNG state across
rendering modes, preserve lower backing bounds/transforms within float tolerance,
and test deterministic replay. Fault injection covers missing/misplaced foundation
instances, oversized walkway plans, orphan terraces, unregistered meshes, and a
missing base floor that forces the automatic structure-only fallback. Foundation
fog/fade/shadow restoration and exempt fixtures are checked too.

The full regression suite passed 31 of 32 scripts; the previously reported
`validate_attack_leap.gd:93` restart assertion remains. Existing shutdown resource
warnings still occur. A warning naming a deliberately missing floor/wall is expected
in the injected-fallback test.

Run `tests/validate_environment_geometry.gd` headlessly. Measurements are written to
`res://.godot/quality_diagnostics/environment_geometry.json`.

## Normal renderer inspection

`tests/capture_environment_geometry.gd` must run **without** `--headless`:

```powershell
& 'C:/Users/alexa/Downloads/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe' --path . --audio-driver Dummy --script res://tests/capture_environment_geometry.gd --quit-after 600
```

Before/after/walkway/lower-path PNGs are saved in `res://.godot/environment_geometry/`. These
were captured and inspected in the actual Windows Forward+ Vulkan renderer on an
AMD Radeon RX 6800 XT, at 1920×1080 with the unchanged 35-degree perspective camera.
The fixture's previously open room edge is backed by stone; the walkway retains
its shallow underside and readable player sprite. A seeded lower-path view
(seed 1, player tile `(5, 11)`) also confirmed selective foundation fading with
the player readable. This is visual inspection, not
a sustained-performance benchmark; startup, shader work and PNG readback affect
the on-screen FPS numbers.

Manual follow-up: explore seeded normal floors, view foundations from lower paths,
traverse all allowed ramps both ways, test attack leaps near edges, verify fading
restores, and exercise stairs/restart and Demo 5F. Check recording performance.
Box-based layered stone and hard terrace corners remain placeholder art. The
validator guarantees declared structure/ownership and tested continuity, not
universal artistic quality or perfect lighting from every possible camera pose.
