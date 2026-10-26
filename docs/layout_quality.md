# Layout quality diagnostics — Phase 1 baseline

The measurements below describe the original three-elevation generator. Current
two-level defaults and policy comparisons are documented in
[two_level_generation.md](two_level_generation.md). Use `--legacy` with the runner
below to reproduce this historical baseline.

This pass evaluates room geometry immediately after elevation assignment and before
rasterization. It never rejects, moves, repairs, or regenerates a layout. Existing
routing, traversal validation, placement exhaustion, fallback, and spawn rules remain
authoritative. The benchmark, legacy elevation fixture, and Demo boss arena bypass
the procedural evaluation hook.

## Configuration and reports

Edit `config/layout_quality.tres` in the Inspector or as text. The experimental
empty-tile separation thresholds are 1 for equal elevations, 5 for a one-level
difference, and 9 for a two-level difference. They are diagnostic values, not hard
generation requirements. Set `enabled = false` to disable evaluation. A procedural
`DungeonGenerationConfig` can optionally reference its own `quality_settings`
Resource; a null reference uses the shared defaults. No existing mode configuration
has been changed.

`TestDungeonFactory.last_quality_report` records the final layout.
`last_quality_attempts` records candidates that reached elevation assignment,
including candidates later rejected by existing routing/validation. Reports contain
room rectangles and elevations, stable room-index pairs, per-axis empty gaps,
required separation, deficits, violating pairs, and camera-risk flags. The existing
`last_statistics` also contains a compact `quality` summary. Reports are replaced
on each procedural generation; they do not accumulate across floors.

Separation is `max(empty_gap_x, empty_gap_y)`, equivalent to clearance measured with
square padding around rectangles. Rectangle ends are exclusive: a room occupying
columns 0–2 and another beginning at column 4 have one empty column between them.
A deficit is `max(0, required - separation)`. Every unordered room pair is evaluated,
including rooms that are not directly connected.

The camera flag is deliberately a **potential-overlap proxy**, not a visibility
test. It projects padded room envelopes from the fixed +Z camera side at the
configured 35-degree pitch, using `DungeonData.TILE_SIZE` and `ELEVATION_HEIGHT`.
It flags intersecting projected envelopes when the higher room is in front of the
lower room. Visual envelope height defaults to 1 world unit and edge padding to
0.25. It does not simulate the moving perspective camera, individual meshes,
corridors, ramps, filler, or player-specific occlusion, and can miss or overestimate
actual obstruction. No camera or renderer settings are changed.

## Running diagnostics

From the project directory, use the installed Godot console executable:

```powershell
& 'C:/Users/alexa/Downloads/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe' --headless --path . --script res://tests/diagnose_layout_quality.gd -- --seeds=250 --size=30x22
```

Optional arguments: `--start-seed=0`, `--one-level=5`, `--two-level=9`,
`--pitch=35`, and `--output=res://.godot/quality_diagnostics/layout_quality.json`.
The runner uses an independent procedural configuration, not the user-edited Limit
Testing configuration. Overrides are process-local and do not save Resources.
Console output provides an aggregate summary; JSON contains every candidate and
accepted room pair. Generated diagnostic artifacts remain in ignored `.godot/`.

## Findings: seeds 0–249, 30×22, Godot 4.4.1

| Measurement | Result |
| --- | --- |
| Accepted random floors | 250 |
| Floors violating experimental 5/9 thresholds | 245 / 250 (98.0%) |
| Floors with a potential camera-overlap flag | 116 / 250 (46.4%) |
| One-level pairs below 5 empty tiles | 698 / 1,797 (38.8%) |
| Two-level pairs below 9 empty tiles | 15 / 19 (78.9%) |
| Equal-elevation spacing violations | 0 / 1,622 |
| Mean total separation deficit per accepted floor | 7.856 tiles |
| Existing layout attempts | 554 (mean 2.216; maximum 10) |
| Floors needing existing generator retries | 134 / 250 (53.6%) |
| Existing elevated-route attempts | 990 |
| Fallback floors | 0 |

Among all 554 pre-rasterization proposals, 549 (99.1%) violate the thresholds and
350 (63.2%) have potential-overlap flags. These include candidates the existing
generator later rejected; they are separate from the accepted-floor statistics.
No retries or fallbacks were caused by quality evaluation.

Re-scoring the *same accepted room layouts* with milder thresholds gives:

| One-level / two-level threshold | Floors with spacing violations |
| --- | --- |
| 3 / 5 | 210 / 250 (84.0%) |
| 4 / 7 | 238 / 250 (95.2%) |
| 5 / 9 | 245 / 250 (98.0%) |

The 5/9 values are aggressive for the current 30×22 placement distribution.
These results do not establish whether bounded translations could satisfy them.
Do not turn them into hard rejection rules without first deciding the intended
tradeoff between spacing, room density, map size, and direction-specific risk.
Phase 2 repair is intentionally not implemented.

## Validation and visual review

`tests/validate_layout_quality.gd` checks exact spacing boundaries, deficits,
directional camera flags, invalid settings, deterministic results, evaluation
purity, identical generated data/RNG with evaluation enabled versus disabled,
forced fallback, and fixture exemptions. A comparison against a saved pre-change
generator also verified identical gameplay data and RNG state across 20 seeds,
including placement exhaustion.

Headless import succeeded. The full regression suite completed with 27 of 28
tests passing. `validate_attack_leap.gd:93` fails its restart-time assertion that
the old enemy is gone, the leap is inactive, and the sprite transform equals the
initial transform. The same assertion fails with quality evaluation disabled;
no attack, animation, restart, or rendering code was modified in this pass.
Expected forced-fallback/spawn-shortfall warnings occur in their existing tests.
Some runs also report existing shutdown resource-leak warnings.

For manual review, run the ordinary modes and inspect `last_statistics.quality`
in the existing generation diagnostics. Nothing should move or render differently.
Use seed records with camera flags to compare actual visual obstruction against
the proxy before treating those flags as a repair objective.
