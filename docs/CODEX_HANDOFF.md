# Codex project handoff

Checkpoint 2 handoff updated **2026-10-27** for branch **Midterm**, commit message **Checkpoint 2. Added lighting, fog, and smoothed out rocky areas.** This documents current source, not release certification. Actual scripts, resources, and scene overrides take precedence over historical discussion. Inspect the working tree before continuing; never reset/clean indiscriminately. Historical measurements below retain their original dates and scope.


## Resume on another PC ? Checkpoint 2

1. Transfer this commit or fetch/checkout `Midterm` after it has been pushed. A local commit alone does not update GitHub. Use `git status` and `git log -1` to verify the exact checkpoint message above before making changes. Do not overwrite later local work.
2. Install **Godot 4.4.1**, open the repository's `project.godot`, and allow a complete editor import. Use desktop **Forward+**. The executable path in this document is specific to the original PC; substitute your own path. Tracked source assets, scripts, shaders, resources and `.uid` files are sufficient; stone maps are baked from the existing FLOOR mesh at runtime. No manually copied generated textures are required.
3. Do not transfer `.godot/` imports, shader caches, screenshots or logs. Those ignored local artifacts contain the original raw benchmark evidence and are not included in the checkpoint. Reimport and capture fresh evidence on the new GPU; timings below are hardware-specific, not promises for another machine. Python/Pillow/NumPy are only needed for the optional sprite integrity tooling.
4. F5 starts ordinary Demo, with baseline lighting A, automatic room beam and automatic ground mist. F6 on `scenes/demos/sunlight_demo.tscn` starts the inherited demonstration with lighting B. F4 cycles A/B/C in debug builds; F3 shows actual internal resolution/performance. There are no F7/L beam switches or activation buttons. Stop/restart after source changes.
5. Run headless import and the full `tests/validate_*.gd` suite using the commands below. Latest result: **41/42 passed first run; music restart playback-position assertion (`validate_music.gd:35`) passed on isolated repeat**, giving passing results for all 42. Do not conceal the timing flake. Require PASS messages and inspect assertions, not just exit codes. The latest import and normal Forward+ lower/upper-room captures completed without script/shader compilation errors.
6. Inspect normal-renderer rooms, corridors, ramp approaches, upper platforms, occlusion, fog reveal/conceal and floor/reset lifecycle. Ground mist is deliberately subtle and see-through, with low drifting layers and nearby cave-space coverage. It is layered transparent geometry, not physically volumetric fog. The mesh beam is room-sized and stationary within each room, hides in corridors and reuses cached placement on return.

**Latest measured scope:** short 1080p seed-4 ground-mist check added one draw and about 0.109 ms GPU (1.627 to 1.736 ms); frame means/p95 were 13.222/16.511 ms hidden and 12.904/16.414 ms visible. The apparent frame-time decrease is noise, not a speedup. Visibility-mask rebuild was about 1.7 ms in the focused headless room and occurs on dirty visibility changes, never warmed idle. Room-beam latest timing was variable even disabled. Native action frames still exceed 16.67 ms in previous checks. Sustained smooth 60 FPS, OBS impact and new-PC behavior require verification.

**Continue from here:** user considers lighting adequate for now; do not redesign or retune it without a new request. Review remaining terrain/ramp seams, cliff textures/material variation and the Alpha presentation on the target PC. Preserve existing gameplay/generation, camera framing, sprite/fog optimizations and current visual detail. No export regeneration/publication is part of this checkpoint. Detailed reports: [rocky terrain](rocky_terrain_slopes.md), [lighting](lighting_presets.md), [sunlight and ground mist](sunlight_atmosphere.md).

## Project and priorities

Offline 2.5D Mystery Dungeon crawler with 2D cardinal-grid gameplay, 3D terrain, and pixel-art characters. The Assignment 3 swordsman/skeleton MVP is playable; development is now environmental/Alpha refinement, including DPPt-inspired exposed upper platforms. Current priorities: **restore/verify sustained 1920×1080 at 60 FPS while preserving graphics**, improve environmental readability, and retain extensibility for future Pokémon gameplay. Pokémon mechanics are not implemented.

## Engine, startup, dependencies

Verified engine: **Godot 4.4.1.stable.official.49a5bc7b6**, GDScript, desktop Forward+. The previous AGENTS.md incorrectly said 4.7.2 and listed working systems as absent. No external runtime AI/network dependency. Python sprite tooling requires Pillow and NumPy; runtime uses imported assets, not Blender.

| Entry scene | Behavior |
| --- | --- |
| `scenes/main/main.tscn` | Shared gameplay; INFINITE procedural progression |
| `scenes/main/demo_main.tscn` | Inherits Main; DEMO, four exploration floors and fixed Floor 5 boss |
| `scenes/main/limit_testing_main.tscn` | Inherits Main; LIMIT_TESTING, fixed benchmark enabled |

**F5 currently starts Demo**: project main-scene UID resolves to `demo_main.tscn`. F6 runs the selected scene. There is no mode-selection/main-menu/pause/settings screen.

Export caveat: project main-scene feature overrides exist for `demo_build` and `limit_testing_build`. Only one Web export preset exists, with empty custom features and output `docs/index.html`; no native preset or explicit `infinite_build` override exists. With current startup an empty-tag export starts Demo. Independent Infinite export needs explicit configuration work. Existing `docs/index.*` outputs are not proof of freshness, working browser rendering, or validated startup; do not regenerate/publish without authorization.

## System ownership

| Owner | Responsibilities |
| --- | --- |
| `scripts/core/main.gd` | Run/floor lifecycle, occupancy, sequential turns, mode and presentation coordination |
| `scripts/core/game_mode_config.gd` | Three modes and Demo final-floor policy |
| `scripts/dungeon/dungeon_data.gd` | Tiles, room rectangles/IDs, connections, elevations, ramps, bounds, spawns, fog; authoritative `can_traverse()` |
| `test_dungeon_factory.gd`, `corridor_router.gd` | Procedural placement/routing, atomic route candidates, reachability/retries/fallback |
| `dungeon_generation_config.gd`, `config/*.tres` | Generation policies and per-mode resources |
| `dungeon_layout_quality.gd`, `dungeon_quality_settings.gd` | Evaluation diagnostics, not placement repair |
| `dungeon_renderer.gd` and renderer helpers | Geometry, fog presentation and occlusion; no gameplay topology ownership |
| `scripts/player/player.gd`, `scripts/enemies/skeleton.gd` | Player input/actions; skeleton BFS/actions |
| `scripts/enemies/minotaur.gd` | Boss footprint, greedy AI, charge state and telegraphs |
| `scripts/entities/health.gd` | Reusable health/damage/healing, explicitly preloaded by dependents |
| `scripts/effects/character_visual.gd`, `attack_leap.gd` | Sprite/frame selection versus attack visual transforms |
| `scripts/core/presentation_camera.gd` | Immediate perspective follow and sprite obstruction samples |
| `scripts/ui/*`, `scenes/ui/*` | Shared HUD, minimap, dialogue, introductions, benchmark and performance overlay |
| `scripts/audio/music_manager.gd` | Autoload; one persistent AudioStreamPlayer with ownership checks |

Gameplay uses `Vector2i`, logical occupancy and DungeonData, without physics collision or CharacterBody3D. Keep typed preloads rather than hiding class-registration problems with Variant.

## Dungeon generation

### Current settings

- **Main/Demo:** `config/standard_generation.tres`: **42×32**, 6–9 rooms, widths 5–8/heights 5–7, skeleton limit 3, 250 placement attempts, 32 layout attempts. Placement exhaustion can accept fewer rooms (`require_minimum_rooms=false`).
- **Limit procedural resource:** current user experiment is 30×22, 8–11 rooms, widths 4–7/heights 4–6, skeleton limit 100, 1000 placement attempts, 32 layout attempts, strict minimum rooms and invincibility. Preserve these user settings.
- **Important:** default Limit `benchmark_enabled=true` bypasses procedural layout/spawn counts. Disable it to exercise its resource. Strict room counts in cramped maps can exhaust retries and explicitly fall back to two rooms.
- Constructor defaults are different: `DungeonGenerationConfig.new()` is 30×22, 5–7 smaller rooms, strict minimum. Do not assume these describe Main.
- `config/legacy_generation.tres` retains older three-height/unrestricted-orientation policy. Main retains a selectable hardcoded two-room ramp fixture.

### Order and contracts

1. Place random room rectangles with overlap checks using `grow(1)`.
2. Assign heights in room order; evaluate quality **before rasterization**.
3. Rasterize rooms; connect intended chain **0→1→2→…**, not MST/all-pairs.
4. Retain ordinary L routes for equal heights; special routing for height changes.
5. Validate under actual `can_traverse()`; assign reachable player/stairs/enemies; report attempts/fallback.

Standard heights are **0 and +1**; starting room is randomized between them. DungeonData owns `TILE_SIZE=1.0` and `ELEVATION_HEIGHT=3.0`. Chance of height change progresses 10%, 40%, 70%, 100%, resets after a change, and flips between levels. Preference ensures both levels when possible. Legacy supports -1/0/+1.

Transitions reserve exactly five straight tiles outside rooms: buffer + three ramp tiles + buffer, with no branches/intersections/side entry. Metadata records lower elevation, uphill direction, segment and index. Logical ramp-center heights are 1/6, 1/2, 5/6 of the rise; three-unit rise across three tiles gives a 45° logical slope. Standard camera policy rejects uphill `Vector2i.DOWN` (+Z toward camera); RIGHT/LEFT/UP remain eligible, with travel in both directions. Legacy can allow all orientations.

Candidate routes validate before carving; failures leave no partial data. Retries are bounded. Exhaustion logs a known-valid two-room fallback rather than silently flattening selected heights. Stairs are random reachable **room tiles**, excluding player, ramp reservations and any tile with an eight-neighbor corridor. They need not be farthest or in a different room. Enemy positions are unique, reachable, exclude reserved positions and report capacity limits. `map_bounds` records full configured bounds without creating walkable tiles.

### Quality diagnostics versus repair

`config/layout_quality.tres`: same-level gap 1, one-level gap 5, two-level gap 9. Evaluates rectangle empty separation, height differences, deficits/violations and approximate camera-direction overlap. These are **experimental evaluation-only thresholds**. No room translation/placement repair is implemented. Repositioning rooms would require rebuilding dependent corridors/ramps/spawns and validation.

Existing spacious-room diagnostic ran four profiles × seeds 0–99. Selected 42×32, 6–9 profile: 100% success, zero fallback, 74% retried layouts, mean 3.27 layout attempts, mean room area 37.99; chain traversal distance median 20 / p90 35 / max 82. Historical local evidence, not a universal guarantee. Random long connections are accepted; do not optimize them away casually. See [spacious floors](spacious_cave_floors.md), [two-level generation](two_level_generation.md), [quality](layout_quality.md).

## Rendering

### Imported models and conventional walls

`assets/environment/modular_dungeon/` contains floor, wall, floor-wall, corner, up/down stairs and torch OBJ/MTL assets. Materials mostly provide colors and modeled detail, not photographic textures. Preserve source artwork.

`modular_dungeon_visuals.gd` scales approximately 2×2 source floors by 0.5 to fit one tile. Combined meshes separate floor and wall surfaces. **`wall.obj` is used**, including standalone/multiple-edge cases. Current conventional elevation-0 walls are **50% height**, adjustable using `conventional_wall_height_scale` (1.0 / .75 / .5). Only wall components scale about contact planes; floor height and horizontal corner alignment remain unchanged. Masonry proportions compress; dedicated half-height assets could improve them later.

Compatible ordinary lower floors use coordinate-hashed quarter-turn rotation and subtle ±4% tint, independent of generation RNG. Directional combined surfaces, ramps/buffers, stairs and upper platforms are protected from inappropriate rotation.

Upper rooms have no conventional walls. Mandatory foundations remain under actual upper room tiles: three approximately one-unit stone layers. Upper corridors have regular floors with shallow approximately one-unit undersides, not full walls or actual bridge assets. Model bounds/offsets determine surface alignment; don't hardcode visual offsets into gameplay.

### Ramp art is not exit-stair art

Each ramp uses **three `up_stairs` model copies**, one per ramp tile, with seam/backing treatment. The exit staircase still uses a raised marker plus `scenes/environment/stairs_placeholder.tscn`: fixed camera-aligned Sprite3D, original 200×163 RGBA PNG, preserved aspect ratio, nearest filtering. A future exit model replaces this component without generator changes.

### Terrain and cave backing

`environment_geometry_plan.gd` distinguishes foundations, shallow walkway support, lower boundary filler, decorative terraces and surface contracts using stable ownership/purpose IDs. Visual candidates undergo bounded deterministic repair, then actual mesh bounds/coverage validation. Structural fallback is available; unresolved visual validation leaves loading/input locked behind black. This is **visual repair**, not room placement repair.

Upper terrain modes retain original UNLIMITED filler, bounded filler and TERRACES for comparison. Current terrace settings include maximum distance 3, band width 1, deterministic jitter and protected clearance 1. Decorative bands descend visually toward lower terrain, without becoming gameplay elevations. Lower rooms/walls, ramps/approaches and upper walkways are protected; bands truncate when space is insufficient. Unlimited rollback can reproduce excessive raised patches.

`cave_terrain_backdrop.gd` now fills all remaining in-bounds ground voids, including formerly excluded ramp/walkway halos. Ramp cells and elevated corridor footprints receive low ground underlays, leaving their actual ramps and shallow supports unchanged. Protected ground stays at Y=0. Terrace plinths/adjacent ground meet terrace bottoms at Y=0.1; existing three-layer room foundations already extend below zero. Structural adjacency includes the eight-neighbor ring of foundations/terraces, and excludes these joins from height randomness. Distant filler beyond Manhattan distance 2 from all walkable tiles, outside ramp/approach/walkway protection, uses a salted coordinate/visual-seed hash: 40% full-height cap (~Y=0.94), 60% half-height (~Y=0.52), matching asset wall heights. This also applies to eligible distant lower-boundary filler; conventional wall components remain unchanged. Both height choices are independent of gameplay RNG and do not enforce a per-map quota.

The renderer exposes `cave_ground_blending_enabled` and `cave_ground_height_variation_enabled` for staged comparisons; both default true. Flat configured maps with explicit bounds now also receive ground backing. Body/cap MultiMeshes retain 8×8 chunks (at most 48 nodes on standard 42×32 maps), per-instance body scaling, coordinate rotation/tint and existing linear/sRGB fog colors. Ground underlays keep receive-only shadows. No collision/navigation or DungeonData changes are introduced. Explicit preserved benchmark/boss/legacy fixtures, negative-height layouts and UNLIMITED comparison mode retain their exemptions. Coverage means geometry exists, not that fogged faces or the air beneath shallow supports become bright.

Terrain refinement checks (2026-10-26): 20 identical seeds verify complete coverage, protected low underlays, terrace-base contact, deterministic height eligibility, unchanged required foundations/walkways/ramps, all DungeonData fields and generation RNG. Normal Forward+ 1080p captures compare seeds 4 and 17 before/fill-only/blended/final, each at spawn, lower room, upper corridor and ramp approach. Actual MultiMesh transform/color readback passed; added/raised filler bounds did not intersect opaque player sight samples in those views. Backing mesh nodes changed 34→38 and 42→44; formerly protected nonwalkable void counts changed 109→0 and 80→0, plus 58 and 43 low walkable-footprint underlays. Local captures/helper: `.godot/terrain_refinement/`. No fresh sustained-FPS claim is made.

See [environment contracts](environment_geometry.md), [terraces](decorative_terraces.md), [assets](modular_dungeon_assets.md), [wall/floor styles](wall_and_floor_styles.md). Earlier documents may describe superseded intermediate versions.

Stage-1 scenery border (2026-10-26): `cave_scenery_border_width=6` extends only the visual filler rectangle. Width 0 restores the previous footprint. An eight-triangle `CaveSceneryApron` covers farther ground, sizing its guard from camera corner rays/max floor height (18-cell total margin for the current camera), rebuilt on viewport resize only. External scenery has no discovery state and receives color changes only for global elevation-palette changes; ordinary fog work still visits interior indices only. Logical map bounds, foundations, shallow bridges, clearance, collision and optimized gameplay/presentation paths are unchanged. Fixed-seed 1080p spawn/edge A/B samples remained near 10 ms average; visible draw-call changes were +1…+9. Ground nodes changed 38/44→81 (80 batched mesh nodes plus one apron). See [scenery border and initial architecture review](cave_scenery_border.md).

Stages 2-4 (2026-10-26, included in Checkpoint 2 after Midterm checkpoint `60aac1a`): continuous ArrayMesh ground, shared world stone mapping and rocky slope controls default true. The initial narrow-bevel prototype was superseded after user visual review. `CaveRockSlopes` now joins angular ground plateaus to neighboring corner heights and slopes decorative terrace roofs continuously toward the upper foundation underside. Required three-layer foundations, shallow bridge supports, ramp/approach protection and conventional walls retain their geometry. Camera-risk clips retain safe original faces. `CaveStoneMaterial` restores original FLOOR-model relief through shared baked albedo/normal/roughness maps. Fog ownership/events, small lookup palette and sprite cache remain unchanged. Sloped planned records declare their actual expanded bounds; identical local shapes share floor-owned meshes. Disable `cave_weathered_edges_enabled` for stepped continuous ground, and disable continuous ground/stone mapping too for checkpoint appearance. All 39 validation scripts and Python 29-frame integrity checks pass. Ten matched 1080p poses: mean GPU 4.315 -> 4.277 ms, frame mean/p95/p99 10.004/11.161/13.649 -> 9.998/10.804/12.643 ms; one of 1,200 frames above 16.67 ms in each half. Draw calls rise ~353 -> 432, ground nodes stay 41, engine static memory increases ~1.58 MiB with bounded floor resources. Comparable measured idle headroom, not sustained combat/OBS or spike-free certification. See [rocky terrain slopes](rocky_terrain_slopes.md) for latest construction, clearance, rollback and full results; [continuous terrain](continuous_cave_terrain.md) retains the earlier prototype history.


### Camera, light and visibility

Camera is **perspective**, about **35° downward**, yaw 0 from +Z, FOV about 23.13°, follow distance about 12.81. Immediate follow uses rendered player position including ramp heights. Preserve angle/framing unless requested.

DirectionalLight3D energy .9 and WorldEnvironment ambient .25 provide shadows/ambient lighting. Sprites remain unshaded, nearest-filtered, billboarded, with depth-prepass alpha and double-sided shadow casting. Foot anchors, ramp-clearance and perspective-size compensation are deliberate fixes.

Alpha lighting presets (2026-10-26): the shared Main scene adds a standalone `LightingPresets` controller, inherited by all modes. A (default) captures/restores the exact original scene light/environment; B uses warm angled sunlight with cool ambient fill; C adds restrained SSAO and modest source softness. F4 cycles presets in debug builds without consuming turns; Inspector startup selection and `config/lighting/*.tres` resources are editable. Selection survives restart/floor transitions. No geometry, material maps, fog/sprite settings, renderer or gameplay code changed in this lighting pass. All 40 validation scripts pass, including exact baseline roundtrip/resource isolation and unchanged camera/fog/material/data/RNG contracts. Eight fixed Forward+ 1080p views per preset: A/B/C mean GPU 3.949/3.878/4.413 ms, frame mean 10.005/9.991/10.083 ms and p95 10.735/10.699/11.601 ms. B is recommended for Alpha; A remains startup default. One C sample exceeded 16.67 ms; idle-only evidence, not sustained combat certification. Settings, material limits, shadow-associated differential timings, screenshots and reproduction: [lighting presets](lighting_presets.md).

Sunlight beam follow-up (2026-10-26, included in Checkpoint 2): shared Main now includes one automatic mesh beam, inherited by Main/Demo/Limit and F5 startup. All beam hotkeys, debug button and exported mode selector were removed after user feedback; no activation input is required. `sunlight_demo.tscn` only overrides lighting to B and inherits the same single effect. One reusable mesh now expands to the current room, with actual sun alignment, overhang rejection and bright-region masking. It remains fixed within each room, hides in corridors, and restores cached anchors on revisits. Room caches reset on floor/lighting changes; static terrain bounds are spatially indexed once per floor. Empty-map-bound fixtures use the union of rooms for mask coverage. All 41 validations passed; normal rendering confirmed broad lower/upper-room coverage. The short latest 1080p comparison had frame-time variability even without the effect, so stable 60 FPS is not certified; the mesh still adds one draw. See the detailed report for measured timings. Normal Demo startup was rendered and confirmed visible without input; startup/reset checks cover all three entries. Historical Original/Mesh/Volumetric comparison API is retained only for tests/benchmark, not connected to gameplay input/UI. Existing F4 lighting controls remain unchanged. Details, previous benchmark and limitations: [sunlight atmosphere](sunlight_atmosphere.md).


Occlusion samples opaque sprite points and camera-to-sprite segments against transformed mesh bounds. Front walls/filler fade to roughly 20% opacity; obstructing higher floors/ramp units can hide. Rear walls should stay visible. Fog is separate and restored correctly; hidden/faded geometry must not cast unintended shadows. Occlusion remains necessary despite improved terrain.

## Gameplay and HUD

- WASD cardinal movement/facing. Blocked/occupied movement costs no turn but updates facing. **No bump attack.**
- Space attacks one tile ahead without moving. Misses/walls still cost one turn, silently. Normal melee uses traversal compatibility, preventing diagonal/cliff attacks.
- Player HP 20/damage 3; skeleton HP 6/damage 2; skeleton kill heals 3 capped at max. HP persists across floors. Inert `level=5` fields are placeholders, not XP/progression.
- Skeleton four-direction BFS respects topology and occupancy: adjacent attack, otherwise at most one step; remain safely if blocked/no path.
- Player presentation finishes, then living eligible enemies act independently in shuffled **sequential** order. Await each blocking presentation; check generation tokens after awaits and before further actions/unlocks.
- AttackLeap moves visuals one tile out/back over .24 seconds with .15-tile hop; logical roots stay fixed. Lethal skeleton leaps may finish under game-over; no further enemy acts.
- Demo 5F: fixed **11×11 diamond**, 61 tiles, bounds `(8,5,11,11)`, player `(13,13)`, boss anchor `(13,9)`, no exit.
- Minotaur HP 30, charge damage 18, greedy pursuit; 1×2 footprint anchored at upper tile, approximately two-tile decorative sprite width. Charge locks **10-tile surrounding ring**, telegraphs one turn, resolves, then one-turn cooldown. Ring includes diagonals by design. Green .3-second arrow is non-blocking; warning floor markers persist through charging. Eight-frame spin lasts .64 seconds; lethal spin finishes before overlay. No boss lifesteal. Diamond-corner trapping is accepted.
- R uses existing fresh-run path: resets floor/HP/inert level/enemies/fog/minimap/dialogue/camera/music, retaining mode/configuration. Game-over blocks gameplay, shows 70% black overlay/red title; boss defeat shows victory/restart.
- Fog: current room plus nearby corridor peek; corridor neighborhood plus cardinal one-tile room-entry peek. Discovery is separate: in rooms reveal walkable cells in the room rectangle grown by one; in corridors reveal only the current tile and four cardinal neighbors. Bright corridor neighborhoods use the surrounding 3?3, excluding room tiles except the cardinal entrance peek. Nonbright terrain is dim regardless of discovery; enemies/stairs appear only when bright. Other-elevation dim floors/corridors are darker; on ramp retain source elevation until exit. Ramp unit remains ordinary gray and brightens whole if any segment tile is bright. No logical visibility raycasting/elevation occlusion.
- HUD: HP, floor, minimap, F3 metrics below minimap. F3 toggles independently of turns/locks, refreshes .5 seconds; runtime FPS, actual internal 3D resolution, elapsed-time average frame interval. Initial resizable windowed viewport/window is 1920×1080; normal VSync/FPS cap unchanged.
- Dialogue: ~200 structured entries, three rendered lines including wrap, four-second inactivity timeout; history survives floors, clears on restart. Separators do not activate/reset timer; no floor-entry messages.
- FloorIntroduction loads only under full black; authoritative lock through final fade. Ordinary stairs 1.50s, startup/restart 1.25s; final-floor text hold 1s instead of .5s. Exported dungeon name currently `Demo Cave`, Demo5 subtitle `Cavern Depths`.
- Music: one persistent player loops existing MP3s. Dungeon track continues normal floors; Demo4→5 stops immediately, silent entire introduction, boss starts after completion. Restart begins dungeon track; death/victory/scene exit stop. Ownership/token checks prevent stale playback changes.

29 extracted character PNG frames have alpha/anchor/source-hash validation. Not implemented: Pokémon moves/PP/types/partners, inventory/items, XP, save/load, full menus, final bridge art and polished cliff assets.

## Limit Testing and performance

Default benchmark: **30×22**, four flat rooms, seed **54903**, deterministic spawn order, capacity **382 skeletons**. Starts at 20. Use −5/+5, then Reset Test; buttons only alter pending count. Actual count clamps to capacity; larger tests preserve smaller spawn prefixes. No random map regeneration/floor progression. Current resource enables invincibility. Limit caps 60 FPS and restores prior cap on exit.

Use ordinary movement/Space and F3 metrics. **No separate scenarios, CSV export, phase timing framework or wait action**: these were intentionally removed. Disable `benchmark_enabled` for procedural experiments. See [benchmark](skeleton_benchmark.md).

Performance regression is the current concern. Cached local cave comparison on RX 6800 XT, Forward+ 1080p, seed 4, 90 warmup/180 sampled frames:

| Sample | Mean interval | p95 interval | Sample-derived FPS |
| --- | --- | --- | --- |
| Before backing | 15.99ms | 26.51ms | 62.55 |
| After backing | 16.38ms | 23.89ms | 61.06 |

Short/noisy historical evidence, **not sustained 60 FPS certification**; p95 exceeds 16.67 ms. Ignored `.godot/` artifacts may be absent elsewhere. No fresh GPU/OBS capture was performed during this documentation task.

Unproven hotspots: every-frame Main presentation over all skeletons, sprite ramp-clearance sampling, occlusion bounds tests, per-tile/model draw calls, foundation/cap detail and alpha shadows. Enemy BFS round stalls and floor-generation retries differ from idle GPU cost. Profile before changing behavior/removing graphics.

Sprite sampling optimization (2026-10-26): `presentation_camera.gd` now caches only the original 9×9 opaque UV masks per texture instance, with weak resource references and a 64-entry LRU bound. Texture `changed` invalidates its entry; camera exit/explicit clear disconnects all callbacks. World-space points still recompute every call, preserving sprite transforms, frame swaps and alpha > 0.5. No decoded images are retained. `validate_sprite_sampling.gd` covers updates/replacement, transparency, weak ownership and eviction; mutable pixel readback also requires its normal-renderer run.

One short paired Forward+ 1080p seed-17 idle capture (120 warmup/360 sampled frames each) measured total sampling 6.55 → 0.059 ms/frame, mean interval 15.27 → 10.05 ms, p95 16.41 → 11.37 ms. Sample-point/occlusion hashes and captured pixels matched exactly. Two cached masks used 208 bytes of UV payload; measured engine static memory rose about 52 KiB including harness/allocator state, not a precise cache-allocation estimate. Raw paired data and the saved pre-change camera are local ignored `.godot/sprite_cache/` artifacts. V-Sync was enabled on the 100 Hz display; this is a narrow improvement check, not sustained 60 FPS certification. Repeated fog/presentation work and floor-loading stalls remain separate, unchanged bottlenecks.

Fog/turn refresh optimization (2026-10-26): `Main.refresh_turn_visibility()` reuses terrain fog only while dungeon instance, player tile and fog reference elevation are unchanged. `refresh_fog()` remains a forced rebuild for floor setup, tests and explicit changes to the current dungeon. Actor/boss visibility, minimap/HUD and sprite clearance still update immediately after every actor action. Call ordering, animation awaits and cancellation guards are unchanged. Renderer occlusion only reuses an identical camera transform/projection, viewport, terrain transform, player tile, opacity and copied sample points within the same process frame; fog application and terrain rebuild invalidate this reuse. New animation frames always rescan. In-place topology/fog edits outside normal movement must use the existing forced `refresh_fog()` path.

Short paired seed-4 eight-move ramp/enemy-turn check, with the sprite cache enabled in both halves: terrain fog passes per move 4 → 1, occlusion scans inside each round 4 → 1; immediate entity/presentation requests remain 4. Inclusive visibility-refresh work averaged 55.74 → 16.23 ms/turn. Action-frame mean/p95/p99 were 68.31/70.35/70.35 → 23.58/25.58/25.58 ms. With only eight action samples, p95/p99 equal the maximum and are not sustained-tail certification. Gameplay, actor transforms, discovery and fog/occlusion-state traces matched; final 1080p images differed at one pixel by one 8-bit blue-channel level. Local raw results/screenshots/saved pre-change scripts: `.godot/fog_refresh/`. One terrain-fog pass, per-frame occlusion/clearance, and floor loading remain costs; the sampled action frames still miss 16.67 ms. No geometry, pathfinding, graphics or floor-loading optimization was included.

Visual limitations: placeholder terrace/cliff seams, intentionally protected voids, compressed half-wall detail, ramp asset seams and delicate sprite depth alignment. A dark area is not necessarily missing geometry. Real GPU inspection remains necessary.

## Testing and profiling

Fresh handoff checks: editor import passed; **34/34 `tests/validate_*.gd` reported PASS**, no script/assertion/parse failures; Python sprite check passed all 29 frames/source hashes. Logs: local `.godot/handoff_validation/`. Some tests emit shutdown ObjectDB warnings and `ERROR: 1 resources still in use at exit`; these remain cleanup concerns, distinct from assertions. Fallback/recovery tests intentionally emit failure-path warnings. No currently failing assertion found.

PowerShell from repo root (executable path is machine-specific):

```powershell
$godot = 'C:\Users\alexa\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe'
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/validate_environment_geometry.gd --quit-after 600
python tests/validate_sprite_extraction.py
```

Full suite; exit zero alone does not prove assertions succeeded:

```powershell
New-Item -ItemType Directory -Force .godot/handoff_validation | Out-Null
foreach ($test in (Get-ChildItem tests/validate_*.gd | Sort-Object Name)) {
    $log = '.godot/handoff_validation/' + $test.BaseName + '.log'
    & $godot --headless --path . --script ('res://tests/' + $test.Name) --quit-after 600 *> $log
    if ($LASTEXITCODE -ne 0 -or
        (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Assertion failed|Parse Error' -Quiet) -or
        -not (Select-String -LiteralPath $log -Pattern 'PASS:' -Quiet)) {
        throw ('Inspect failed/incomplete test: ' + $log)
    }
}
```

Test groups (`tests/validate_<name>.gd`):

- Generation: elevation, generation_config, generation_policies, layout_quality, floors, modes, benchmark.
- Combat/order: combat, turns, sequential_rounds, space_attack, boss, invincibility, attack_leap, stat_effect.
- Visual contracts: modular_assets, environment_geometry, cave_background, terrain_fill, terraces, upper_platforms, wall_styles, ramp_art, ramp_sprites, stairs_visual, character_sprites, lighting, presentation.
- UI/lifecycle: fog, hud, dialogue, floor_introduction, performance_overlay, music.

`round_test_helper.gd` deterministically completes/cancels animations. Preserve this instead of sleeps. Headless dummy rendering cannot certify shadows, transparency, sprite clipping, or actual MultiMesh GPU transform readback.

Diagnostics: `diagnose_layout_quality.gd` defaults 250 seeds (inspect options for size/legacy/thresholds), `diagnose_generation_profiles.gd`, `diagnose_spacious_rooms.gd` (four profiles×seeds0–99). `capture_wall_styles.gd`, `capture_environment_geometry.gd`, `capture_cave_background.gd` need **normal rendering**, not headless, for meaningful screenshots/readback. Cave capture uses seed 4; environment capture searches fixed seed fixtures. Inspect tool options/output paths before running.

Manual regressions: F6 all three entries; F5 startup; authoritative intro lock; blocked movement/Space; sequential attacks; lethal leap; boss warning/spin/victory; R during transitions; stairs; fog/minimap; ramps both directions/all allowed orientations; wall corners/front fade; foundation/terrace/backing; silent boss intro/music continuity. Feature-tag export startup needs separate verification.

Performance procedure: check actual 1080p in F3 including resize/3D scaling, stable seed/camera/settings, warmup, with/without OBS. Use Godot CPU/visual profiling, record mean/tail intervals during exploration, ramps, multiple attacks, boss spin and transitions. Separate cap from achieved FPS, CPU turn stalls from GPU cost. No maximum supported skeleton count is established.

## Recommended next work and uncertainties

1. Read current diffs and reproduce regression with stable normal-renderer captures; do not start by restricting generation/removing graphics.
2. Attribute CPU/GPU cost, optimize narrowly, compare identical gameplay layouts before/after. Preserve35° camera, art and fog.
3. Inspect terrain seams/voids/ramp layering on GPU; retain reversible configuration and required foundations.
4. Deliberately review export startup/presets: F6 entries exist, but Infinite export/default F5 and browser compatibility need attention.
5. Future milestones: dedicated half-wall/cliff/bridge/exit art and QoL, then generic Pokémon entities/moves/partners and fuller menus/save systems under separate scope.

Uncertainties: root cause/hardware scope of regression; OBS-active sustained 60 FPS; export freshness/browser compatibility; GPU appearance beyond headless contracts; significance of shutdown resource warnings. No need is established to alter randomized connections or implement room-spacing repair merely to shorten corridors.

Ground mist follow-up (2026-10-27, included in Checkpoint 2): automatic `GroundMist` child of SunlightAtmosphere adds three low, softly animated terrain-height layers in one batched surface/draw, independent of the room shaft. Uses authoritative walkable heights/existing cave plateau heights, no new lights or environment changes. A dirty coverage mask extends softly into nearby nonwalkable spaces while suppressing undiscovered paths; no idle CPU scans/uploads. Shared startup/reset lifecycle owns resources. Focused test: `tests/validate_ground_mist.gd`. Short normal 1080p seed-4 idle check measured +0.109 ms GPU and one draw; not sustained 60 FPS certification. See the ground-mist section of [sunlight atmosphere](sunlight_atmosphere.md).

Ground-mist regression: all 42 tests have passing results; music restart playback-position assertion failed once in the full run and passed isolated rerun. Existing cleanup warnings remain.
