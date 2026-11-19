# Validation workflow

Choose checks using the [Codex Efficiency and Testing Policy](../AGENTS.md#codex-efficiency-and-testing-policy).
Small changes need only relevant syntax/import checks; gameplay features use focused
tests and one headless validation. Major shared-system changes may need broader
regressions. Do not run the full suite automatically after changes or at checkpoints.
When an import is needed, let it finish before running dependent checks.
Set `GODOT_BIN` or pass `--godot` with your installed executable path.

```sh
"$GODOT_BIN" --headless --path . --editor --import --quit --log-file /tmp/dungeon-import.log
python tests/run_validations.py --godot "$GODOT_BIN"
python tests/run_validations.py --godot "$GODOT_BIN" --suite full
```

The default `gameplay` group contains 22 checks. `full` discovers every
`validate_*.gd` script (currently 59). Logs default to `.godot/validation/`;
`--log-dir` selects another folder. The runner requires a zero exit, a `PASS:`
message, and no script/parse/assertion errors. It stops failed scripts promptly
and returns nonzero if any check fails. Engine cleanup/certificate warnings are
still recorded for inspection, rather than automatically treated as assertions.

For a smaller change, run the owning script directly with Godot and inspect its
log for errors as well as its final PASS. Headless checks do not verify particle
appearance, shadows, transparency, GPU readback or frame rates.

| Change | Primary checks |
| --- | --- |
| Final-floor three-wide corridor/camera, textured bounds/upper torches, repeatable recovery, sealed arena/light, Drapion stairs, row4 music and floor-only controls | `validate_final_floor`, `validate_held_movement`; normal-render map/audio review |
| Open elevation+1 projectile air extension, same-height hits and lower-floor immunity | `validate_upper_air_projectiles`, `validate_projectile_impact` |
| Scratch/Tackle/Pound visual hit feedback and unchanged melee damage/PP | `validate_melee_impacts` |
| Enemy hurt recovery timing, held hurt pose and cancellation | `validate_damage_recovery`, `validate_projectile_impact`, `validate_sequential_rounds` |
| Projectile impact timing/particles, delayed damage, cancellation and turn locks | `validate_projectile_impact`, `validate_projectile_moves` |
| Species stats or actor initialization | `validate_battle_state`, `validate_hud` |
| Species types/STAB, Floor 3 move unlock, projectile lane/targeting, O slot | `validate_projectile_moves`, `validate_pokemon_moves`, `validate_battle_state` |
| Demo startup, starter choice or player profiles | `validate_starter_selection`, `validate_pokemon_sprites`, `validate_modes` |
| Damage formula, move data, PP and move input | `validate_pokemon_moves`, `validate_battle_state`, `validate_starter_selection` |
| Five-turn stage expiry/refresh and move/stat/damage messages | `validate_status_duration`, `validate_status_moves`, `validate_dialogue`, `validate_sequential_rounds` |
| Stat stages, status move targeting/PP and stat arrows | `validate_status_moves`, `validate_stat_effect`, `validate_pokemon_moves`, `validate_battle_state`; normal-render inspection |
| Move-specific clips and floating damage | `validate_pokemon_moves`, `validate_pokemon_sprites`, `validate_damage_numbers`; normal-render captures |
| Enemy move selection, per-instance PP and attack-only randomness | `validate_enemy_moves`, `validate_pokemon_moves`, `validate_sequential_rounds` |
| Temporary Spiritomb starter, screen Ominous Wind, Shadow Ball and cancellation | `validate_spiritomb_moves`, `validate_enemy_variety`, `validate_sequential_rounds`, `validate_effectiveness_dialogue` |
| Four defeats -> Spiritomb reveal/audio/circular arena, HP/PP and cancellation | `validate_spiritomb_reveal`, `validate_final_encounter`, `validate_sequential_rounds`; manual transition/audio review |
| Final arena center trigger, blackout/music timing, four-enemy formation and cancellation | `validate_final_encounter`, `validate_final_floor`, `validate_sequential_rounds` |
| Prepared Budew/Feebas/Riolu/Gible, Splash and Dragon Breath | `validate_encounter_species`, `validate_enemy_variety`, `validate_sequential_rounds`; manual native/Frost Breath presentation |
| Prepared enemy species scenes, action mappings, eligible enemy projectiles and cancellation | `validate_enemy_variety`, `validate_enemy_moves`, `validate_sequential_rounds`; normal-render scale/release review |
| Combat/input/targeting | `validate_combat`, `validate_sequential_rounds`, `validate_pokemon_moves` |
| Floor repopulation, hidden pursuit and spawn safety | `validate_repopulation`, `validate_sequential_rounds`, `validate_visibility_refresh` |
| Floor/player-type weighted enemy selection, initial spawns and respawns | `validate_enemy_spawn_rates`, `validate_repopulation` |
| J waiting, visibility interruption and peaceful healing | `validate_recovery`, `validate_sequential_rounds`, `validate_held_movement` |
| Shared enemy flow map, occupied-route fallback, ramps and topology changes | `validate_enemy_flow_map`, `validate_sequential_rounds` |
| Pursuit comparison for one through five enemies | `compare_enemy_pathfinding.gd`; methodology and sample results in [pathfinding comparison](../docs/pathfinding_comparison.md) |
| Paired pursuit timing on standardized maps | `benchmark_enemy_pathfinding.gd`; methodology and results in [pathfinding comparison](../docs/pathfinding_comparison.md) |
| Paired pursuit timing on a seeded generated floor | `benchmark_generated_pathfinding.gd`; seed and results in [pathfinding comparison](../docs/pathfinding_comparison.md) |
| Held movement | `validate_held_movement` |
| Attack rendering priority, rounded3x3 occlusion, fog and doorway diagonals | `validate_visibility_refresh`, `validate_presentation`, `validate_fog`, `validate_continuous_terrain`; normal-render corridor/doorway/attack captures (headless skips the visual light overlay) |
| Type-effectiveness dialogue after player/enemy/boss move damage | `validate_effectiveness_dialogue` |
| Move display | `validate_move_panel`, `validate_hud` |
| Drapion species, charged move/basic selection, deferred PP and balance | `validate_drapion_moves`, `validate_enemy_moves`, `validate_battle_state`, `validate_boss`, `validate_drapion_swing` |
| Boss/defeat | `validate_boss`, `validate_drapion_swing`, `validate_enemy_defeat` |
| Floors, modes, reset or input locks | `validate_battle_state`, `validate_modes`, `validate_floor_introduction`, full regression for shared lifecycle changes |
| Character animation | `validate_attack_leap`, `validate_character_sprites`, `validate_pokemon_sprites`, relevant ramp tests and normal-render inspection |
| Terrain, generation, atmosphere or rendering | Relevant subsystem checks; full regression when shared data/rendering contracts change |

## Consolidated combat coverage

`validate_combat.gd` replaces the separate `validate_space_attack.gd` and
`validate_turns.gd` entry points. It shares one deterministic dungeon instance
across health, movement/pathfinding and attack-input scenarios. It covers health
boundaries/death-once, successful/blocked turns, no bump damage, occupancy,
BFS detours/no path, stairs cleanup without an outgoing phase, Space mapping,
facing, wall/empty misses, echo/release filtering, hit/kill/healing bookkeeping,
loading/death guards and R restart.

The consolidated test uses live species resources and derives HP expectations
from actor stats. One explicitly two-hit enemy fixture keeps kill checks short;
it does not require production Stunky HP to equal 6. Numerical species values
belong in `validate_battle_state.gd`, not unrelated input tests.

`validate_sequential_rounds.gd` owns shuffled once-per-round order, presentation
serialization, hidden-enemy actions, scheduled-dead-enemy skipping, lethal phase
termination and cancellation. `validate_battle_state.gd` owns production stat
binding, isolated mutable state, cross-floor persistence and fresh reset.
`validate_attack_leap.gd` retains exact transform/timing and cancellation checks;
its repeated lethal/restart scenario was removed because lifecycle tests own it.
Default-profile recovery is native Pokemon. Generic procedural transform tests
use static Pokemon atlas fixtures, without requiring retired artwork.

## Normal-render captures

Sixteen old capture entry points are consolidated into five groups, plus
`capture_support.gd` for shared dispatch, scene setup, PNG writes, frame readback,
and diagnostic statistics. Each group defaults to its first scenario. Use `all`
to run every scenario in that group. Existing image output folders are retained.

```sh
"$GODOT_BIN" --path . --script res://tests/capture_characters.gd -- --scenario=sprites
"$GODOT_BIN" --path . --script res://tests/capture_ramps.gd -- --scenario=all
"$GODOT_BIN" --headless --path . --script res://tests/capture_atmosphere.gd -- --list
```

| Entry point | Scenarios (old script suffix -> new option) |
| --- | --- |
| `capture_characters.gd` | `pokemon_sprites` -> `sprites`; `pokemon_native_motion` -> `motion`; `drapion_swing` -> `boss`; `enemy_defeat` -> `defeat` |
| `capture_ramps.gd` | `ramp_attacks` -> `attacks`; `front_ramp_sprites` -> `poses` |
| `capture_environment.gd` | `environment_geometry` -> `foundations`; `cave_background` -> `backing`; `continuous_terrain` -> `terrain`; `wall_styles` -> `walls`; `upper_floor_variation` -> `rotation` |
| `capture_atmosphere.gd` | `lighting_presets` -> `lighting`; `sunlight_atmosphere` -> `sunlight`; `sunlight_fog` -> `fog`; `ground_mist` -> `mist` |
| `capture_visibility.gd` | `pokemon_visibility` -> `pokemon` |

Existing diagnostic options `--exits`, `--edge`, `--before` and `--preview` remain
available for their relevant scenarios. `--list` parses/discovers scenarios without
a GPU; actual captures reject the headless renderer. Scenario completion is checked before
reporting group success; also inspect logs for script/assertion errors. The backing scenario
explicitly enables the retained batched backing path for real MultiMesh readback;
terrain covers the current continuous mesh. Keep shader/frame statistics separate
from any claim of sustained performance; these screenshot runs are not certified
benchmarks. `profile_pokemon_sprites.gd` remains a separate profiling tool.

## Native role-default fallback

Player/enemy/boss default to Chimchar/Stunky/Drapion when their configured
profile is missing or invalid. `validate_pokemon_sprites` and
`validate_ramp_sprites` cover the defaults. `profile_pokemon_sprites.gd --
--defaults` profiles role defaults; the retired `--placeholder` comparison and
legacy sprite-extraction Python test/tool no longer exist.

Recovery move: `godot --headless --path . --script tests/validate_recovery_move.gd` verifies starter reveal learning, healing/PP/Charge/popups, turn completion, cancellation and reset.

Species editor serialization: `godot --headless --editor --path . --script tests/validate_species_editor_save.gd`. Editor mode is required to exercise non-tool Resource placeholders and catch packed-array default/serialization regressions; normal runtime loading cannot certify this path.

Stairs confirmation/UI priority: `godot --headless --path . --script tests/validate_stairs_prompt.gd`. Real stair entry now requires explicit choice; fixtures intending to advance must call `main.stairs_prompt.choose(true)` before completing introduction. `validate_final_floor.gd` covers the recovery-tile notice and final-floor flow.
