# Two-level procedural generation

## Configuration

Infinite and Demo exploration floors use
`config/standard_generation.tres`: **42×32**, now 6–9 requested rooms, room widths
5–8, room heights 5–7, three skeletons, 250 placement attempts, and 32 layout
attempts. Placement exhaustion keeps its existing permissive behavior
(`require_minimum_rooms = false`). Increasing map dimensions does not change room
dimensions. Movement speed, camera, rendering, combat, and turns are unchanged.
Longer routes can naturally take more player steps; visual pacing needs playtesting.

Current larger-room/cave-fill measurements are in
[spacious_cave_floors.md](spacious_cave_floors.md). The comparison tables below
retain the original 5–7-room, 4–7-width, 4–6-height experimental baseline.

Edit this Resource to try 30×22 or 36×28, adjust sizes, or reverse the policies.
Main's existing `generation_config` Inspector property now also accepts an override
in Infinite/Demo. Null uses the shared standard Resource. Assign
`config/legacy_generation.tres` for the original 30×22, three-elevation,
unrestricted procedural generator. Duplicate either Resource for independent
scene-specific experiments instead of editing a shared Resource.

Limit Testing retains its own `config/limit_testing.tres`; its fixed benchmark
continues to bypass procedural generation entirely. The legacy fixed-ramp fixture
and Demo 5F diamond arena are unchanged.

New `DungeonGenerationConfig` fields:

- `elevation_mode`: `TWO_LEVEL` (0/+1) or `LEGACY_THREE_LEVEL` (-1/0/+1).
- `prefer_both_elevations`: for two-level layouts with fewer than five rooms,
  change the final assignment if necessary to avoid an all-one-height floor.
  This consumes no extra random values and never rejects a layout.
- `restrict_camera_hidden_ramps`: exclude the camera-hidden orientation when
  selecting an elevated route. Disable explicitly for unrestricted routing.

Two-level assignment chooses the starting height randomly, then uses the existing
10%, 40%, 70%, 100% change progression along the room chain. A change flips 0↔1
and resets the probability. Five-room layouts already guarantee both heights.
Legacy mode retains the original assignment and RNG sequence, including a height-0
start. The original known-valid fallback remains two 4×4 rooms at 0/+1 with an
east-uphill ramp; it obeys the strict policy. Exhaustion is explicitly logged;
the restriction is never silently relaxed.

## Ramp direction

The perspective camera remains at 35 degrees, zero yaw, on the +Z side of its
target. Moving away from it is logical `UP`, world −Z. A downhill path in that
direction is the reverse of **uphill `DOWN` (+Z)**, so that is the excluded segment
orientation. Uphill left, right, and up remain allowed. This is a routing policy,
not a traversal restriction: every accepted ramp still works in both directions.
The policy is tied to the current camera yaw; reassess it if camera orientation
changes. Rise stays 3 world units; footprint stays buffer + three ramp tiles + buffer.

## Seeded comparison

Godot **4.4.1**, seeds **0–99 independently for each profile**, same room counts,
sizes, retry limits, spawn rules, and experimental quality thresholds (1/5/9).
All **1,100** generated floors passed actual `can_traverse()` flood-fill checks
for every room tile, staircase, and enemy spawn; allowed ramp orientations were
bidirectionally traversable. No profile used a fallback. Five seeds per profile
also passed exact replay and RNG-state checks.

`U` means unrestricted ramps; `R` means camera-restricted ramps.

| Size | Elevations / ramps | Random success | Floors retried | Mean layout attempts | Mean footprint attempts | Floors with spacing deficits | Camera-risk floors |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 30×22 | Legacy / U | 100% | 56% | 2.27 | 4.43 | 97% | 52% |
| 30×22 | Two / U | 100% | 58% | 2.25 | 3.17 | 99% | 37% |
| 30×22 | Two / R | 100% | 57% | 2.32 | 3.51 | 99% | 48% |
| 36×28 | Legacy / U | 100% | 53% | 2.12 | 3.60 | 94% | 39% |
| 36×28 | Two / U | 100% | 51% | 1.92 | 3.65 | 80% | 36% |
| 36×28 | Two / R | 100% | 52% | 2.11 | 2.84 | 85% | 37% |
| 42×32 | Legacy / U | 100% | 46% | 1.87 | 2.53 | 81% | 35% |
| 42×32 | Two / U | 100% | 46% | 2.02 | 2.65 | 77% | 33% |
| 42×32 | Two / R | 100% | 44% | 1.78 | 2.45 | 73% | 28% |

Footprint attempts include elevated-route candidate attempts across rejected
layouts, averaged per finalized floor; they are not frame times or BFS expansion
counts. Spacing/camera flags never reject a layout. Camera risk remains the
Phase 1 padded, parallel-projected room-envelope proxy, not a GPU occlusion test.
Different policies consume different routing RNG values, so resulting rooms can
differ for the same seed after retries; each seed/configuration remains repeatable.

| Two-level profile | Starts at 0 / +1 | Floors containing both |
| --- | --- | --- |
| 30×22 U | 49 / 51 | 100/100 |
| 30×22 R | 49 / 51 | 100/100 |
| 36×28 U | 52 / 48 | 100/100 |
| 36×28 R | 57 / 43 | 100/100 |
| 42×32 U | 56 / 44 | 100/100 |
| 42×32 R | 56 / 44 | 100/100 |

Strict routing remains practical in this sample. It removes the specified hidden
ramp case, but does not guarantee lower overall room overlap: at 30×22 it increased
that proxy rate. **42×32 is the selected starting default**, with 36×28 a more compact
alternative. Quality flags remain common, so this does not replace future room
separation/repair work. No translations or repair were implemented.

### Larger-room experiment

Separate 100-seed profiles used widths 5–8 and heights 5–7 with two levels and
restricted ramps. Requested room counts stayed 5–7.

| Size | Success / fallback | Mean room area | Mean layouts | Mean footprint attempts | Spacing-deficit floors | Camera-risk floors |
| --- | --- | --- | --- | --- | --- | --- |
| 36×28 | 100% / 0 | 38.24 | 2.25 | 3.28 | 91% | 34% |
| 42×32 | 100% / 0 | 38.87 | 2.01 | 4.39 | 91% | 36% |

Current-size rooms average about 27 tiles. Larger rooms provide about 45% more room
area, but at 42×32 worsen the measured overlap/spacing and routing effort. They
remain an optional experiment; standard room dimensions were not increased.

## Diagnostics and validation

```powershell
& 'C:/Users/alexa/Downloads/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe' --headless --path . --script res://tests/diagnose_generation_profiles.gd -- --seeds=100
```

This runs the nine baseline comparisons plus two larger-room profiles. JSON output
is `res://.godot/quality_diagnostics/generation_profiles.json`. The full per-pair
runner `tests/diagnose_layout_quality.gd` remains available; add `--legacy` to replay
the old policy or `--unrestricted` for two-level unrestricted ramps. Its `--size`
argument defaults to the original diagnostic baseline 30×22, independently of the
new standard Resource. Resources are not modified by either runner.

`tests/validate_generation_policies.gd` covers assignment/progression, starting
height variety, both-level preference, legacy support, camera side, deterministic
replay, orientation policy, bidirectional traversal, and forced fallback. A saved
pre-change generator comparison additionally passed exact data/RNG equality across
20 seeds in legacy mode, including placement exhaustion.

Godot 4.4.1's script-loading order exposed an uninitialized scripted Resource when
it was preloaded from the factory in the benchmark test. The standard Resource is
now loaded lazily after script initialization, with an explicit typed cached
reference. The benchmark-to-normal-scene regression verifies this startup path.

Final validation: headless import passed; **28 of 29 regression scripts passed**.
`validate_attack_leap.gd:93` retains the Phase 1 failure at its restart-time
enemy/leap/sprite-transform assertion. No attack-leap implementation or test was
changed here. Existing shutdown ObjectDB/resource warnings still occur in some
presentation tests; forced-fallback warnings are expected in exhaustion tests.

## Future environmental rendering

No new tile type or renderer change is needed yet. Existing authoritative data
already distinguishes:

- Lower/upper surfaces: `get_elevation(tile)` and `room_elevations`.
- Rooms/corridors: `get_room_id(tile)` and `TileType.CORRIDOR`.
- Ramps/buffers: `ramp_tiles`, `ramp_segments`, and `reserved_transitions`.
- Boundary edges: cardinal neighboring tile type and surface elevation.

Bridges do not currently have distinct metadata. The smallest future addition is
an optional presentation-role map keyed by `Vector2i` (e.g. ordinary/bridge), with
bridge cells retaining their walkable `CORRIDOR` topology and elevation. The
renderer could select upper-platform materials, omit upper walls, draw exposed
edges, and use bridge art from those fields. Keep visual roles separate from
`can_traverse()` unless a future bridge introduces genuinely new traversal rules.
The current grid cannot represent two independently walkable layers at the same
X/Y coordinate; an underpass would require a separate design. None is implemented.

## Manual checks

1. F6 Main and Demo: explore several floors, including starts at +1. Confirm normal
   sprite grounding, fog reference height, minimap, HP, turns, and transitions.
2. Traverse each allowed ramp orientation uphill and downhill; verify the formerly
   hidden downhill-away orientation is absent. Art visibility still needs GPU review.
3. Assign a duplicate legacy Resource to Main's `generation_config`; verify -1/0/+1
   generation and unrestricted orientations return. Clear the override afterward.
4. Compare 30×22, 36×28, and 42×32 by editing a duplicate standard Resource. Judge
   actual room overlap, travel distances, and 1080p performance with recording active.
5. Run Limit Testing's fixed benchmark, the legacy fixture, and Demo 5F. Their layouts
   and gameplay should remain unchanged. Restart should preserve the selected config.
