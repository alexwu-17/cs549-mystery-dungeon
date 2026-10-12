# Game modes and exports

All entry scenes share `scenes/main/main.tscn`, its script and child nodes.

| Entry scene (F6) | Mode | Progression |
| --- | --- | --- |
| `scenes/main/main.tscn` | INFINITE | Procedural floors indefinitely |
| `scenes/main/demo_main.tscn` | DEMO | Procedural 1–4; Minotaur arena on 5 |
| `scenes/main/limit_testing_main.tscn` | LIMIT_TESTING | Configurable procedural floors indefinitely |

R resets the run but preserves mode and configuration. The legacy elevation
fixture remains an explicit Inspector debug override in all scenes; leave
`use_elevation_test` disabled for normal play and exports.

Demo floor 5 is an 11x11 diamond (61 walkable tiles) at elevation zero. Rows are
counted from 1 at the bottom: the player starts at the center of row 3, (13,13).
The future boss center is reserved as DemoArenaFactory.BOSS_CENTER at (13,9),
the center of row 7. The Minotaur occupies its upper anchor tile and the tile
immediately below it (1x2 along grid Y), starts at 30 HP, and charges its surrounding
ring for 18 damage. The icon is two tiles wide visually, centered on the one-tile
body centerline; its half-tile side extensions are decorative. The green rising
arrow is visual only; persistent orange/red floor markers show the next attack. A charge
starts on one enemy turn, resolves on the next, then spends one turn cooling down.
There is no boss lifesteal. Victory blocks play and R starts a fresh Demo run.

The ring includes cardinal/diagonal neighbors of the body, excludes its two tiles,
and excludes invalid terrain (10 unique tiles in open space). Its saved tiles and
markers stay locked through charging, independently of the arrow's 0.3-second
Tween. The unchanged diamond provides 50 valid boss anchors. Corner trapping is an
intentional hazard; no guaranteed escape is added and the arena has not been widened.
Stat arrows use 60% of their original size, screen-left positioning, half-tile
vertical travel, quick fade-in and late fade-out; red-down reverses the green-up
path. Optional anchor offsets do not change travel distance or timing.

## Limit Testing

Edit `config/limit_testing.tres` in the Inspector. Main and Demo do not reference
this resource. Values are read without mutation and retained across floors/R.
Normal modes retain their original generator defaults and placement-exhaustion
behavior. `require_minimum_rooms` applies only to configured experiments.

Maps must be 16x8 through 128x128, with room sizes fitting map margins. Minimum
room dimensions are 3x3. Counts/ranges/retry limits are validated before generation.
Invalid configurations log errors and leave gameplay disabled; correct the resource
and rerun. Retry exhaustion uses the original reported fallback: two 4x4 rooms and
a standardized ramp, which may differ from requested room settings. Enemy counts
are capped by unique reachable room spawn tiles, with shortfalls logged.
Large maps/enemy counts can be slow: routing and sequential enemy BFS share the
existing algorithms. No performance guarantee is implied by the validation bounds.

## Export startup

Godot 4.4 supports custom feature overrides of ProjectSettings. The default
`application/run/main_scene` remains the infinite entry. Export presets must use:

| Build | Custom feature |
| --- | --- |
| Infinite | Neither feature below |
| Assignment 3 Demo | `demo_build` |
| Limit Testing | `limit_testing_build` |

Project settings map these features to their respective entry scenes. Never put
both tags in one preset. Naming a preset or marking it Runnable does not select a
startup scene. Custom export tags do not apply to ordinary editor F6 runs.
Use Export All Resources initially, or explicitly include the chosen entry scene
and all shared dependencies, including the Limit Testing resource when needed.

For Assignment 3, create a Windows Desktop preset with `demo_build`, install
templates matching the exporting Godot version, export, then launch the executable
without arguments. Verify four procedural floors, the fifth boss arena, the floor cap,
and R restarting Demo. No per-build edits to project.godot are needed. No presets
or binaries are created by this architecture milestone.

Web requires Compatibility/WebGL 2.0; the desktop project uses Forward Plus.
Do not change desktop rendering for export. Before a Web release, validate the
Web renderer configuration, StandardMaterial3D lighting/shadows, Sprite3D,
texture alpha sampling, HUD, and performance in a browser. Hosting/deployment and
renderer adjustments remain separate work requiring visual review.

References:
- https://docs.godotengine.org/en/4.4/tutorials/export/feature_tags.html
- https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_web.html
