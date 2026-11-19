# Enemy pursuit comparison

This report compares the existing `Skeleton.next_step_toward()` occupancy-aware BFS with `EnemyFlowMap.build()` and `Skeleton.flow_step_toward()`, including its BFS fallback. Run the reproducible fixture with:

```sh
godot --headless --path . --script tests/compare_enemy_pathfinding.gd
```

The test uses three fixed 11×7 level-zero maps: open terrain, a wall with two passages, and a single-tile chokepoint. For each map it tests one through five enemies against a stationary player. Both methods begin at identical coordinates, use the same deterministic rotating sequential action order, and check occupancy after each action. Once adjacent, an enemy holds its tile as though attacking; attacks, damage, player movement, projectiles, ramps, fog and animation are not simulated. Each run stops when no enemy moves in a round or after 30 rounds. At most four enemies can occupy cardinal attack positions.

`Moves` counts all enemy tile changes until the run stops. `Reached` counts enemies that reached an adjacent attack tile. `First` is the round when the first enemy reached such a tile. An unfinished run can accumulate extra moves through oscillation, so move totals should be read alongside reached counts and the 30-round limit. Full per-enemy paths, arrival rounds, and single-run pathfinding timings are printed as JSON.

Results from Godot 4.7.2 headless on 2026-11-18, **before the fallback fix**:

| Map | Enemies | BFS moves | Flow moves | BFS reached | Flow reached | BFS first | Flow first | Different paths |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Open | 1 | 7 | 7 | 1 | 1 | 7 | 7 | 0 |
| Open | 2 | 15 | 15 | 2 | 2 | 7 | 7 | 0 |
| Open | 3 | 23 | 23 | 3 | 3 | 7 | 7 | 0 |
| Open | 4 | 36 | 53 | 4 | 3 | 7 | 7 | 1 |
| Open | 5 | 48 | 83 | 4 | 3 | 7 | 7 | 2 |
| Two passages | 1 | 11 | 11 | 1 | 1 | 11 | 11 | 0 |
| Two passages | 2 | 21 | 21 | 2 | 2 | 10 | 10 | 0 |
| Two passages | 3 | 33 | 50 | 3 | 2 | 10 | 10 | 1 |
| Two passages | 4 | 50 | 80 | 4 | 2 | 10 | 10 | 2 |
| Two passages | 5 | 60 | 64 | 4 | 4 | 10 | 10 | 2 |
| Chokepoint | 1 | 7 | 7 | 1 | 1 | 7 | 7 | 0 |
| Chokepoint | 2 | 17 | 17 | 2 | 2 | 7 | 7 | 0 |
| Chokepoint | 3 | 27 | 27 | 3 | 3 | 7 | 7 | 0 |
| Chokepoint | 4 | 46 | 55 | 4 | 3 | 7 | 7 | 3 |
| Chokepoint | 5 | 57 | 83 | 4 | 3 | 7 | 7 | 4 |

The current flow-map approach can oscillate when a successful BFS fallback takes an enemy away from the player and the following turn's terrain-only gradient leads it back. For example, in the open four-enemy fixture, the fourth enemy alternates between (9, 1) and (10, 1), while BFS continues via (10, 2) to the open attack tile (10, 3). Similar cycles occur in the two-passage and chokepoint cases. The first enemy arrives on the same round in all these fixtures; BFS gets more enemies into attack positions in six cases and uses fewer moves in seven, with no case where flow uses fewer moves. This comparison does not prove either method is always better on other maps or action orders.

The JSON timings include flow-map construction once per simulated round and movement searches; they exclude rendering, animations, combat and other game work. These are single, short headless samples, so they are diagnostic only and not a reliable performance comparison. The map can cost more than an early-exit BFS for one enemy; congestion can also invoke individual BFS fallbacks.

After the fallback fix, all 15 fixtures matched BFS exactly for every enemy's path, moves, and arrival round. The flow-map pathfinder now checks the complete preferred terrain-shortest route for live blockers; if any tile is blocked, it uses occupancy-aware BFS for that action. It repeats that check each turn, preventing the gradient from pulling an enemy out of an ongoing detour. The comparison now asserts exact parity. A separate deterministic test checks 200 varied occupancy arrangements. These tests do not prove equivalence on every map or establish a performance improvement; validating an entire route and running fallback searches adds cost in congested cases.

## Paired timing comparison

Run `godot --headless --path . --script tests/benchmark_enemy_pathfinding.gd`. Three fixed 24×17 level-zero maps contain open ground, two walls each with two openings, or two walls each with one opening. A stationary player and 3, 4, 5, 10, or 15 enemies use identical occupancy snapshots and rotating action order for 12 phases. BFS produces the snapshots; both methods must return the same step for every action. One warmup per method is followed by 12 repetitions, alternating measurement order: 144 phase samples per method and case. Reported time includes building the shared flow map once per phase and selecting every enemy's step, including fallbacks, but excludes game rendering, animation, combat, and snapshot creation. It is elapsed wall time, not a full frame or CPU profile. The 144 measurements repeat only 12 distinct states and are not independent generated floors.

Godot 4.7.2 headless on 2026-11-18, mean milliseconds per phase:

| Map | Enemies | BFS | Shared flow | Mean reduction | BFS p95 | Flow p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Open | 3 | 3.52 | 1.94 | 45.0% | 3.78 | 3.90 |
| Open | 4 | 4.80 | 3.00 | 37.4% | 5.11 | 5.22 |
| Open | 5 | 5.99 | 3.06 | 49.0% | 6.38 | 5.21 |
| Open | 10 | 11.80 | 6.98 | 40.9% | 12.57 | 10.19 |
| Open | 15 | 18.19 | 11.41 | 37.3% | 19.46 | 14.48 |
| Two passages | 3 | 3.43 | 3.37 | 1.9% | 3.64 | 3.91 |
| Two passages | 4 | 4.60 | 4.29 | 6.7% | 4.86 | 5.19 |
| Two passages | 5 | 5.41 | 4.25 | 21.5% | 6.09 | 5.13 |
| Two passages | 10 | 9.31 | 7.78 | 16.5% | 11.97 | 10.43 |
| Two passages | 15 | 14.64 | 12.90 | 11.9% | 18.71 | 17.70 |
| Chokepoints | 3 | 2.69 | 2.77 | −3.2% | 3.25 | 3.60 |
| Chokepoints | 4 | 3.46 | 3.37 | 2.7% | 4.28 | 4.65 |
| Chokepoints | 5 | 4.45 | 4.31 | 3.1% | 5.37 | 5.74 |
| Chokepoints | 10 | 8.43 | 7.86 | 6.8% | 10.97 | 11.35 |
| Chokepoints | 15 | 11.78 | 11.11 | 5.7% | 16.45 | 15.13 |

The open-map average favors the shared map in this fixture, whereas chokepoints show little average advantage and sometimes worse p95. These synthetic results are not evidence of actual game frame rate or sustained 60 FPS. The separate seeded-floor experiment below adds player movement, shuffled order, ramps and generated terrain; representative gameplay and Godot 4.4.1 remain unmeasured.

## Seeded generated floor

Run `godot --headless --path . --script tests/benchmark_generated_pathfinding.gd`. This uses the production default generation resource and seed `5492026`, on Godot 4.7.2. The resulting non-fallback 42×32 floor has nine rooms, three ramps and 425 recorded tiles. The player starts at (9, 7); the five generated enemies start at (28, 26), (27, 28), (34, 11), (30, 4), and (32, 23). The three- and four-enemy cases use the first three or four generated spawn positions. The sorted tile-type/elevation SHA-256 is `a80a17bc5c34dfa71d2a1c29adbb81a9cc00934da7cfcb0f649faa7b4e6d617e`; it is an identifier for the recorded tiles and elevations, not a hash of all ramp metadata.

The fixture builds 16 sequential phases with a reproducible shuffled enemy order (independent seed `82731`). The player moves to an available traversable neighbor every fourth phase; otherwise the position stays fixed. Adjacent enemies remain in position as if attacking; no combat or presentation is simulated. BFS generates identical per-action positions and live occupancy snapshots for both methods, and each measured result is checked against its BFS step. After warmup, 12 alternating-order repetitions yield 192 phase samples per method and count. Times include one shared-map build per phase and all movement decisions, but omit rendering, animation, combat and snapshot generation. The repeated measurements cover 16 states, not 192 independent floors or turns.

| Enemies | BFS mean | Flow mean | Mean reduction | BFS p95 | Flow p95 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 3 | 4.016 ms | 3.490 ms | 13.1% | 5.019 ms | 4.345 ms |
| 4 | 5.009 ms | 4.172 ms | 16.7% | 6.598 ms | 5.323 ms |
| 5 | 6.003 ms | 5.173 ms | 13.8% | 8.018 ms | 6.531 ms |

All compared steps matched. This is one seeded floor in one engine version, with prescribed player movement and stationary adjacent enemies. It supports reporting the result for this fixture only; it does not establish an average for standard gameplay or a frame-rate gain. Different seeds, battle situations, and Godot 4.4.1 remain unmeasured.
