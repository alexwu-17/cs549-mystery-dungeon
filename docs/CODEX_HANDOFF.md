# Codex project handoff

Checkpoint 4 handoff updated **2026-10-28** for branch **Midterm**, commit message **Checkpoint 4. Most systems complete and replaced sprites with Pokemon. Cleared some bugs remaining from checkpoint 3 such as stairs collision.** This documents current source, not release certification. Actual scripts, resources, and scene overrides take precedence over historical discussion. Inspect the working tree before continuing; never reset/clean indiscriminately. Historical measurements below retain their original dates and scope.


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

Post-checkpoint visual tuning (2026-10-27, uncommitted): ground mist retains 50% higher alpha (0.1275) and now uses coherent world-space drift (0.24,0.09 tiles/s), verified with an isolated frozen-scene normal-renderer check in `tests/capture_ground_mist.gd`. Room beam receiver gains a deterministic center offset and 0?2 safety-checked narrower supporting shafts, batched into one surface/draw (4?12 triangles), without gameplay RNG use. Mesh beam tint and B/C sunlight are near-white; exact-baseline A unchanged. Cached layouts are stable across revisits/recomputation and reset with floor/preset. Ground fog/FoW/camera/gameplay contracts remain unchanged. See the latest sections of [sunlight atmosphere](sunlight_atmosphere.md); historical timings predate these changes.

Continuous-beam follow-up (uncommitted): default mesh beam glow is no longer cut by the fog status of its background pixels. Room activation, depth/overhang checks, logical fog/materials and hidden entities remain unchanged. Ground mist and archived volumetric masks are unchanged. Normal-renderer helper: `tests/capture_sunlight_fog.gd`; sunlight/fog/presentation focused tests pass. Floor texture rotation was investigated only: lower eligible meshes still quarter-turn, upper platforms explicitly do not, cave stone detail uses world mapping. User asked for feasibility only, so do not implement floor mapping changes without a new request.

Upper-floor variation follow-up (2026-10-27, uncommitted): user subsequently authorized quarter-turn floor variety with rollback. `DungeonRenderer.upper_floor_quarter_turns_enabled` defaults true and extends the existing coordinate-hashed mesh rotation to eligible upper FLOOR/CORRIDOR tiles, excluding reserved ramp/approach cells and stairs. All surfaces of the same floor tile rotate together. It reuses existing square authored meshes/materials; no per-frame work, new texture sampling, nodes or draw calls are introduced. Lower-floor rules, cave filler world mapping, directional assets, supports and gameplay remain unchanged. Uncheck **Upper Floor Quarter Turns Enabled** on the DungeonRenderer node and restart to restore the previous upper appearance. Existing master floor variation/quarter-turn flags also disable it. Tests: `validate_upper_floor_variation.gd` (determinism, all four rotations, exact rollback, shared resources, protected geometry/topology/RNG), normal 1080p A/B helper `capture_upper_floor_variation.gd`. This supersedes the previous instruction that floor changes were discussion-only.

Upper-floor final validation: **43/43 validation scripts passed**, no script/assertion/parse failures. Normal fixed seed-4 upper-room 1920x1080 A/B (45 warmup/120 idle frames each, no concurrent validation) measured fixed vs rotated mean 10.069/10.041 ms, p95 11.170/11.292 ms, GPU mean 5.315/4.896 ms. Both used exactly 382 draws, 1,563,300 rendered primitives and 1,313 renderer child nodes. These short samples show no material frame-time regression; the GPU difference is not evidence of a speedup or sustained-60 certification. Normal captures confirm varied upper tile detail. Artifacts: `.godot/sunlight_prototypes/upper_rotation_gpu.log`, `upper_rotated_false.png`, `upper_rotated_true.png`; earlier full-suite logs use `rotation_validate_*`. Existing certificate/cache-save/cleanup limitations remain; no shader compilation errors.

Checkpoint 3 includes the post-checkpoint visual tuning, continuous-beam and reversible upper-floor variation follow-ups above. Their descriptions marked uncommitted record development history; they are included in this checkpoint. Latest complete validation remains 43/43 PASS, with normal-renderer continuity/idle-motion/rotation checks documented above.

Held-direction QoL (2026-10-28): Player now takes an immediate single step on directional press, waits 0.24 seconds to distinguish a hold, then repeats at 0.08-second intervals when the sequential round is unlocked. Holding scales actor attack leaps and boss spin presentation by 3, including active tweens; release, blocked/occupied movement, stairs, focus loss, death and round cancellation restore 1x. A wall/actor stops repetition until a new press, with no bump attack or blocked turn. Timing is local to actor presentation (no Engine.time_scale changes to introductions, music or atmosphere). `tests/validate_held_movement.gd` deterministically covers cadence, locks, release, wall/occupancy, active animation timing and cancellation. This machine has Godot 4.7.2 installed; 4.4.1 and manual rendered input feel remain unverified.

Held-movement validation: headless editor import completed without script compilation errors on installed Godot 4.7.2. All 44 validation scripts have PASS results: 42 passed the initial suite, while cave-background and environment-geometry assertions at diagnostic FileAccess.open failed because `.godot/quality_diagnostics` was absent; both passed after creating that ignored output directory. Final focused held-movement test also passed with deterministic active-Tween stepping. Existing ObjectDB/resource cleanup and macOS certificate/logging warnings remain. No rendered play-feel or 4.4.1 verification was performed.


## Pokémon Alpha visuals (2026-10-28)

Chimchar now presents Player, Stunky presents Skeleton, and Drapion presents Minotaur through the existing shared/inherited actor scenes. `assets/sprites/pokemon/{Chimchar,Stunky,Drapion}/` contains the original flat archive contents (106/106/40 files), byte-verified against the local lowercase ZIPs. ZIPs are ignored rather than committed twice. Older `assets/sprites/source/` artwork and placeholder frame directories remain untouched.

`PokemonCharacterVisual` extends `CharacterVisual`; three `config/pokemon_*.tres` resources configure directories, world pixel sizes, body-to-ground anchors and optional action mappings. `PokemonSpriteLibrary` reads `AnimData.xml` once per species/configuration, shares immutable AtlasTextures, cardinal frame/body-anchor metadata and 9×9 opacity masks. Only rows 0/2/4/6 render, without mirroring. All three species provide all four requested Idle/Walk/Attack/Hurt clips. See [asset notes, exact dimensions/durations and extension/rollback instructions](../assets/sprites/pokemon/README.md).

Walk notifications and surviving-damage Hurt are visual-only and nonblocking; no added turn awaits or damage events. Consecutive moves extend Walk without resetting its animation phase. Source Attack timing proportions fit the existing player/enemy .24-second leap or boss .64-second spin window. Damage remains at the original action event, so exact source HitFrame synchronization is limited by existing gameplay timing. Drapion retains the warning/attack-ring/cooldown/defeat behavior and initial two-tile artwork width, 1×2 occupancy and sprite Z offset. Idle is the charge-warning visual. Body markers affect Sprite3D artwork offsets only and remove baked attack travel that would compete with AttackLeap; they stabilize body bob as well. PMD shadow sheets remain preserved but unused. Existing shadow/filter/camera settings remain.

The camera samples precomputed immutable atlas opacity masks; ramp clearance uses precomputed opaque-top metadata, avoiding animated-frame readback/decompression. Generic mutable-texture sampling cache/invalidation remains unchanged. Library image reads/decompression occur only on first species load, using imported Texture2D resources. Species PNG imports are lossless without mipmaps. The existing export preset includes Pokémon XML metadata; no exports were generated, and desktop Forward+ remains the presentation target.

Validation: **45/45 headless scripts PASS**, including new `validate_pokemon_sprites.gd`, existing sprite/ramp/sampling, boss/lethal lifecycle, health/combat and held-movement regressions. Final focused Pokémon test passed after fallback hardening. Headless import completed without script compilation errors. Normal Forward+ `capture_pokemon_sprites.gd` captured all 16 cardinal/action combinations at 1920×1080; inspected Idle/Attack/Hurt images confirm source pixels, directional poses, anchoring and existing shadows. Artifacts/logs: `.godot/pokemon_validation/`. Captures were taken during validation/startup and are not FPS measurements; no sustained 60 FPS claim. Installed engine is **4.7.2**, so **4.4.1 compatibility remains unverified**. Existing macOS certificate and shutdown ObjectDB/resource cleanup warnings remain; music passed this run (historical timing flake above still applies).

Pokémon validation continuation (2026-10-28): remaining user requirements confirmed proportions, anchoring, scaling, fog/occlusion/shadows and 1080p timing. No production gameplay changes were added in this continuation. Expanded `validate_pokemon_sprites.gd` passes 40 uninterrupted Walk updates with shared frame resources plus Attack/Hurt completion and facing in all cardinal directions. Native `capture_pokemon_visibility.gd` passes two-room actor fog hide/reveal, all 276 selected cardinal frame texture dimensions/readback masks, original character shadow flags and real-player-sample upper-geometry occlusion with fog restoration. Screenshots inspected under `.godot/pokemon_validation/`; existing cleanup warnings remain.

Native `profile_pokemon_sprites.gd` measured separate Pokémon and placeholder runs on Apple M1 Pro / 4.7.2 Metal Forward+, seed 4, actual 1920×1080, 120 warmup + 600 measured frames per workload, no concurrent test workloads. Pokémon idle/movement/boss mean ms: 8.57/10.55/7.06; p95: 9.01/21.54/10.04. Placeholder p95: 8.88/20.48/10.58. Movement budget misses: 51/600 and 56/600 respectively. Large unexplained outliers (Pokémon movement max 975.57 ms; placeholder idle max 1002.10 ms) are retained. GPU timing is unavailable on this backend (API zero recorded as null). Scheduling yielded different move counts, so this is not an exact paired trace and does not prove absence of regression. Both variants miss the 16.67 ms action-frame budget: **sustained 60 FPS remains uncertified**. Preserve detail/gameplay rather than hiding stalls. Full table, caveats and reproduction instructions: [Pokémon asset notes](../assets/sprites/pokemon/README.md). Latest complete shared-system suite remains 45/45 PASS; expanded focused test and native visibility/performance helpers passed afterward.


### Native Pokémon motion correction (2026-10-28)

User authorized restoring original sprite action motion/timing while retaining gameplay. This supersedes the initial integration's per-frame body-marker anchoring and fixed attack-duration normalization. PokemonCharacterVisual now uses one fixed canvas-space ground reference calibrated from Idle's first South frame; frame padding changes do not reset that reference. Authored Idle jumping/hovering, Walk bob and Attack travel remain visible. Idle is unscaled at 1× even during held movement. Source attack durations are Chimchar 19/60s, Stunky 28/60s, Drapion 26/60s; active actions still use the existing held-speed multiplier. Presentation waits follow these native lengths rather than the old .24s/.64s windows. Damage is still emitted at the original event exactly once; mechanics, target tiles, sequential actor ordering, input/lifecycle guards, boss warning ring/cooldown and HP remain unchanged.

AttackLeap retains blocking presentation/completion/cancellation ownership. Its optional procedural motion remains enabled by default for placeholders; Pokémon disable it and use its new elapsed-sample signal for source frames, eliminating the old extra lunge and a second playback clock. The boss uses its existing CharacterVisual completion signal with a native-duration Attack Tween. No Hop/LeapForth composition or generated frames are needed.

Native forward frames exposed a billboard/floor clipping issue in normal rendering. Shared CharacterVisual now offers a zero-default ground-clearance hook. The Pokémon override uses cached opaque bounds and the authoritative ramp plane, applying camera-ray surface correction through AttackLeap with the existing perspective-size compensation. This preserves source screen-space motion/size and avoids floor clipping without modifying logical roots or topology. A rendering-only SpriteClearance child on the boss reuses that surface-offset helper; Main only adds the boss to its presentation-clearance update. Changed frames also refresh their own clearance before rendering so late Tween samples cannot clip for one frame. No per-frame image reads, XML, texture creation or mesh rebuilds were added.

Tests retain legacy placeholder full-tile/.15-hop/.24s and eight-frame/.64s boss coverage via an explicit pre-ready fallback fixture, while native Pokémon tests verify fixed-origin motion, Idle's full first-frame hold at speed 3, source attack durations/last-frame holds, no procedural displacement, unchanged roots, and all 276 cardinal frame ground bounds/projected placement. Normal `capture_pokemon_native_motion.gd` captures jump apex and attack anticipation/reach/recovery, including an inspected maximum-forward pose after clearance fixed visible floor clipping. Native fog/occlusion/shadow/readback checks passed. Artifacts: `.godot/pokemon_validation/native_*.png`; regression logs: `.godot/pokemon_native_validation/`. Original PNGs/metadata remain unchanged. Prior performance comparisons predate this correction; no new sustained-60 claim is made. Installed engine remains 4.7.2 rather than target 4.4.1.


Native-motion final validation: **45/45 scripts have PASS results** after updating the ramp fixture's former zero-clearance assumption for source poses. Native opaque bounds, no accumulation and neutral-pose flat restoration now run alongside the original placeholder expectations, at both 35° and 50° camera pitches and all four ramp orientations. Camera-ray clearance may move either direction along the ray when the ramp normal requires it; projected art/size and roots remain unchanged. Complete suite logs: `.godot/pokemon_native_validation/final/` (44 first-pass plus revised `validate_ramp_sprites.gd` isolated PASS at `/tmp/native-ramp.log`); native focused, normal-rendered visibility/readback and editor import also pass. Existing certificate/cleanup warnings remain.

Final isolated native Forward+ 1080p profile: idle mean/p95 8.35/8.87 ms; procedural 3× movement 10.44/22.87 ms (59/600 >16.667 ms, max 27.89 ms); boss movement 8.34/11.18 ms. 120 warmup / 600 measured frames per case, Apple M1 Pro, installed 4.7.2. GPU timing unavailable. This is a short check, not sustained-60 certification; action-frame stalls remain and no gameplay/terrain/detail changes were made to hide them. Latest profiler JSON: `.godot/pokemon_validation/performance_pokemon.json`; log `/tmp/native-performance.log`.


### Ramp-only native attack trajectory (2026-10-28)

User authorized uphill/downhill melee presentation for the player and enemies with strictly unchanged flat-surface behavior. The new mode activates only for native attacks whose source tile is RAMP and whose facing edge passes DungeonData.can_traverse(). Flat sources, including buffers facing a ramp, keep the exact old native presentation; incompatible side/cliff misses, boss area attacks and placeholder behavior are unchanged.

AttackLeap owns a presentation-only world offset derived from the renderer's authoritative endpoint world positions. XML RushFrame/HitFrame/ReturnFrame metadata (now cached by PokemonSpriteLibrary) determines smooth extension, contact hold and recovery within the unchanged source total duration. Middle ramp travel is ±45°; ramp-to-buffer travel follows the slope to the shared edge, then becomes flat. The existing tread offset blends toward the target buffer offset. Only in this mode, Pokémon frame-body markers anchor poses to Attack frame zero so baked screen travel does not double the new world path. Idle/Walk/Hurt and flat attacks retain authored motion. No body rotation, PNG edits, damage scheduling, logical movement or extra turn awaits are introduced. Finish/cancel clears the offset through existing completion signals and token guards.

Shared CharacterVisual exposes zero-default attack-surface/final-clearance hooks. Native ramp clearance uses cached opaque frame bounds and an exact four-corner camera-ray solve after perspective-size compensation. ModularDungeonVisuals.ramp_clearance_height() caches the source stair mesh's maximum tread protrusion once. The ramp clearance plane remains conservative across neighboring treads at buffer boundaries; rendered checks caught/fixed stair faces banding through descending artwork. No per-frame mesh/image readback/rebuild, physics, RNG or dungeon changes. Flat code paths return zero additional correction.

Verification: **46/46 headless scripts PASS**, including new validate_ramp_attacks.gd (48 active ramp paths and 16 unchanged flat approaches across both species, all cardinal orientations, both travel signs, exit buffers, no duplicate lunge, source duration, actual tread clearance, cancellation and real combat damage/healing/occupancy/sequential rounds). A 168-sample native flat attack trace captured before and after this feature is byte-identical for frames/times, atlas regions, offsets, transforms, pixel sizes, active state and logical positions. Trace/harness: `.godot/ramp_attacks/flat-*`, `flat_attack_trace.gd`. Full logs: `.godot/ramp_attacks/final/`.

Normal Forward+ 1920×1080 capture_ramp_attacks.gd passed middle-ramp contact/pose captures and `-- --exits --edge` boundary captures. Inspected source poses clear actual steps at peak and descent/exit; ordinary geometry occlusion remains active. Captures include target-hidden `_pose` diagnostic variants. These captures ran alongside validation and are not timing measurements. Import passed with no script compilation errors; known certificate/cleanup warnings remain. No new sustained-60 claim, no export regeneration, no commit/push. Installed 4.7.2 / target 4.4.1 compatibility limitation remains.


### Drapion boss Charge → Swing → Idle recharge (2026-10-28)

User explicitly replaced the old surrounding swing/ring attack with a **2×2 area directly in front**, preserving charge/swing/recharge turns. Minotaur remains the internal boss class; its fixed 1×2 footprint, 30 HP, 18 damage, pursuit, defeat/no-lifesteal and arena are unchanged. Direction now measures the player relative to the footprint center. Four warned cells comprise two ranks past the front edge; East/West span the body's two rows, while North/South use the actor's column plus its facing-relative right column (a whole-cell alignment choice for a one-cell-wide footprint). Arena-void cells are omitted. Warning cells and facing freeze for the charge; the next turn's Swing checks the stored cells once, followed by one Idle cooldown turn.

Drapion's profile additionally configures Charge and Swing. Charge loads actual `Charge-Anim.png` metadata (48×40, 10 frames ×2/60s = 1/3s loop). Swing loads actual `Swing-Anim.png` (72×72, 9 frames, 16/60s total); native artwork includes sweeping/forward travel, so no additional leap is added. Sprite root occupancy stays fixed. Recharge uses Idle; surviving Hurt returns to Charge when still charging, or Idle during recharge. Optional CharacterVisual charge/swing/recharge hooks preserve the original placeholder charge/spin fallback. Pokémon Swing uses existing active/completion/cancellation signaling with its XML clock, including lethal presentation before game-over and restart token checks. Damage still occurs at the original combat action event exactly once; no HitFrame damage scheduling is added. Other species' animation profiles and flat/ramp attacks are unchanged.

Verification: **47/47 scripts PASS**. New validate_drapion_swing.gd tests four cardinal 2×2 patterns, frozen aim/dodge misses, actual sheet paths/timing and last-frame hold, Hurt→Charge, Swing→Idle, one Idle recharge turn, one 18-damage event, unchanged roots/footprints, boundary clipping and native lethal-Swing restart cancellation. Updated validate_boss.gd covers the new region while retaining HP/pursuit/occupancy/healing/victory/reset checks. Generic Pokémon sprite validation includes both extra clips and 352 total cardinal frames. A native 168-state player/Stunky flat attack trace still matches the pre-boss-change trace exactly.

Normal Forward+ capture_drapion_swing.gd passed 1920×1080 Charge/Swing/Idle and four-direction warning captures; inspected poses and shadows use source pixels with no clipping in sampled views. Logs/captures: `.godot/drapion_swing/validation/`, `.godot/drapion_swing/*.png`. These are not frame-time samples and do not certify sustained 60 FPS. Known certificate/cleanup warnings remain. Installed Godot remains 4.7.2; target 4.4.1 is not verified. No source art was edited or archives moved/deleted, no exports regenerated and no commits/pushes performed.


### Enemy faint/blink and two-tile boss line (2026-10-28)

User replaced the unnatural 2×2 warning with a **straight two-tile line forward**. Minotaur.attack_tiles now starts beyond its fixed footprint's front edge; East/West pick the nearer occupied row when face_player aims, while North/South use the body's column. Facing/lane/warning cells stay locked until Swing. Charge/Swing/Idle, 30 HP/18 damage, occupancy and arena remain unchanged.

The sprite library now automatically loads optional Faint metadata for any species. Stunky has 32×32 / four frames / 8,12,4,10 ticks (34/60s). Drapion has none and uses the last configured Hurt frame. Native defeat toggles Sprite3D child visibility every .075s, lasts at least .8s (or full source duration if longer), then hides. The native last Faint frame holds if the minimum exceeds source duration. Profile defaults are reusable/adjustable; no species-name branching or per-frame XML/image/mesh/texture work. Faint is also discovered in Chimchar's archive but player death behavior is unchanged. Generic sprite validation now covers 384 cardinal frames. Blink respects fog-owned parent visibility; hidden phases cast no sprite shadows in inspected normal captures.

CharacterVisual exposes separate defeat-finished/completed/cancel state, independent of ordinary action completion. Pokémon visuals reject ordinary pose changes while defeating. Skeleton removes attack presentation and damage tint on lethal damage, starts defeat, and ignores subsequent damage at zero HP. Main immediately removes dead regular enemies from live occupancy and grants the same healing, then retains their nodes only in a visual retiring_enemies list. The normal enemy phase remains nonblocking on these corpses. Finish removes/queues the node; floor/reset clears the list before freeing nodes and signaling cancelled effects. Visibility/clearance still refresh retiring visuals. This list has no gameplay occupancy/topology.

Boss defeat sets victory/input lock and cancels outgoing round tokens immediately, starts the visual after cancelling old boss actions, then awaits defeat completion and the finishing player's presentation before showing **Demo Complete**. A victory-only cancel_round option preserves that last player animation. Owner/generation/disposed/completion checks after awaits prevent stale screens on restart/exit. Boss root hides after disappearance; music still stops at victory. Native clearance now returns early for disposed/out-of-tree nodes, fixing a teardown viewport access caught in normal capture.

Verification: **48/48 scripts PASS**, including new validate_enemy_defeat.gd for native Faint timing, fixed-speed blink, last-Hurt fallback, completed-versus-cancelled state, no dead AI/occupancy, unchanged healing, fog ownership, visual cleanup, delayed completion, long finishing attack and restart during death. Updated boss tests cover the line and both horizontal aiming rows; deterministic round helper finishes defeat effects explicitly. A 168-state flat player/Stunky attack trace still matches exactly. Full final logs: `.godot/enemy_defeat/final/`.

Normal 1920×1080 capture_enemy_defeat.gd passed and inspected Stunky lying/blink-hidden/gone captures plus Drapion Hurt-last/blink and the delayed Demo Complete overlay. No script errors after lifecycle fix; existing cleanup/certificate warnings remain. capture_drapion_swing.gd refreshes the line previews. These concurrent-validation captures are not frame-time benchmarks: sustained-60 and target-4.4.1 limitations remain; installed engine is 4.7.2. No source art edits, exports, commits or pushes.


### Front-facing stair clearance and dynamic dialogue names (2026-10-28)

Native ordinary poses now use the existing exact, perspective-compensated surface-clearance solver on camera-facing ramps. Previously only attacks included the authored raised-tread envelope; Idle/Walk/Hurt/Faint could intersect individual stair treads despite clearing the logical slope. The new branch uses cached ramp mesh clearance and per-frame cached opaque bounds, moving only the sprite along the camera ray and compensating pixel size. Flat surfaces, side-facing ramps, active attack paths, terrain, grid roots, turn timing and source artwork retain their existing behavior. The camera-direction gate intentionally leaves side and back-facing ramps unchanged. Standard generation still excludes uphill DOWN ramps; the diagnostic includes this legacy orientation, whose staircase backside can occlude sprites from the fixed camera.

`PokemonSpriteProfile.display_name` supplies player/enemy/boss names (Chimchar, Stunky, Drapion). Empty names fall back to the species directory, then the placeholder visual's configured generic name. Combat templates use `{character}`, `{enemy}`, `{actor}`, `{target}` and `{amount}`. Main resolves attack/defeat names from the actual actor instance at event time; CombatDialogue resolves player/boss providers and stores the resolved values with each history entry. Changing a selected profile affects subsequent messages without rewriting history. Demo completion and benchmark captions also avoid old placeholder species names. Internal Skeleton/Minotaur classes and original assets remain intact; no selection or enemy-spawning mechanics were added.

Focused validation covers future player-name changes and individually named enemy instances, full native Idle/Walk/Hurt/Faint frame bounds on all four facings and three front-ramp tiles at camera pitches 35/50, existing fallback/no-drift/flat restoration, and an identical 168-sample flat attack trace. Normal Forward+ captures: `.godot/front_ramps/before_*.png` and `after_*.png`; inspected uphill-UP Chimchar/Stunky poses now clear raised treads. Screenshot capture/readback workloads are not FPS benchmarks. Installed engine is 4.7.2; target 4.4.1 and sustained 60 FPS remain unverified.

Final validation: **48/48 scripts have passing final results**. The initial suite found an obsolete string-based invincibility fixture and a back-facing legacy-ramp clearance regression; the fixture now emits the actual enemy signal, and the clearance branch is limited to camera-facing treads. Both corrected scripts passed focused reruns, as did expanded dialogue and ramp-frame tests. Music passed this run; its historical timing flake remains documented. Regression logs are in `/tmp/stair-name-regression/`, with corrected focused results in `/tmp/invincibility-names.log`, `/tmp/ramp-art-fixed.log`, `/tmp/ramp-allframes.log` and `/tmp/dialogue-final.log`. Headless import passed without script compilation errors. Existing ObjectDB/resource shutdown warnings and host certificate errors remain. Broad screenshot pixel equality is unsuitable with temporal rendering; side-facing source paths and inspected poses are preserved, without a pixel-identical GPU claim.

The front-ramp capture helper forces each diagnostic draw before readback, avoiding a stalled `frame_post_draw` wait when the macOS window stops drawing. Final 32-pose capture completed after the camera-facing-only gate and final editor import.


### Drapion Strike presentation (2026-10-28)

Drapion now maps its existing logical Swing action to the authored Strike clip through `config/pokemon_drapion.tres` (`"Swing": "Strike"`). Strike is 72×88, ten frames, durations 2,2,6,2,1,2,6,2,2,2 ticks (27/60 seconds). All cardinal rows, original offsets and native motion are retained. Only animation configuration changed in production: charge/recharge states, two-tile warning line, damage event timing/amount, footprint, targeting and turn consumption remain unchanged. The presentation now waits for the longer authored clip through the existing completion contract.

Headless import and four focused scripts PASS: Drapion action/telegraph/timing, generic species frame/anchoring, boss gameplay and defeat/restart lifecycle. Normal 1920×1080 capture passed four directions and inspected Strike pose; capture now forces diagnostic draws to avoid inactive-window waits. No fresh FPS certification or target-4.4.1 validation (installed engine 4.7.2).

Dungeon title remains user-editable: open `scenes/main/demo_main.tscn`, select the root, and set exported **Dungeon Name**. This overrides the shared `@export var dungeon_name` default in `scripts/core/main.gd:6` for Demo only. No dungeon rename was made.
