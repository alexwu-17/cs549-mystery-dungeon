# World-space sunlight and localized mist prototypes

## Current automatic behavior

The shared Main scene now includes one automatically enabled mesh beam, inherited by Main, Demo and Limit Testing. Stop/restart and use ordinary **F5**, or run a scene with F6: no beam key, button or mode selector is needed. `sunlight_demo.tscn` inherits that same component and only chooses Natural Sunlight lighting preset B. Its former duplicate effect instance was removed.

This supersedes the earlier F7/L toggle experiment. Both shortcuts and the demo control button have been removed. The selected mesh mode is no longer exported to the Inspector. Programmatic comparison modes remain solely for the controlled benchmark/tests; they are not connected to player input. Existing F4 lighting presets remain independent.

One reusable effect now covers the current room, subject to a conservative clear-sun-path check. Entering another room selects its own wider, room-sized placement; corridors hide the effect. Placement remains fixed while moving within a room, and revisits restore its cached anchor and dimensions. Floor resets and lighting changes invalidate those placements. If no safe placement exists, it reports a warning and stays hidden.

The reusable component is `scenes/effects/sunlight_atmosphere.tscn`. It expects the existing Main/LightingPresets/DungeonRenderer context. For a selected dungeon location, disable `auto_place_demo` and set `anchor_tile`, or call `place_at(Vector2i(x,y))`. Coordinates use the authoritative renderer's elevation/world-position helper. Keep the component transform at identity; placement is world/grid based, not a camera attachment. This prototype supports one active atmosphere controller per Main; concurrent volumetric regions would need shared environment ownership before expanding it.

## Construction

**Atmosphere A: Original.** Both effect nodes are hidden. The existing environment and sun's original fog-energy value are restored. No primary-light energy, color, shadow setting or direction is changed by the atmosphere controller.

**Atmosphere B: Mesh.** One ArrayMesh contains two slightly crossed, world-space ribbons: four triangles, one material/surface and one added transparent draw in these views. Their long axis is `-sun.global_basis.z`. The transverse axis derives from the actual camera basis at construction. With the 35-degree camera and Natural Sunlight, rays travel screen-right/down from an upper-left source; the test checks projected endpoints rather than assuming world-left is screen-left. Camera movement does not rebuild/reposition the shaft.

The inexpensive additive shader feathers both edges, fades both ends, and varies the center gently without animated textures. Ordinary depth testing and reverse-Z depth reconstruction fade intersections with opaque geometry, including sprite alpha prepasses. A small bright-region mask samples the opaque surface behind the beam to avoid painting a luminous overlay over undiscovered terrain. This can intentionally trim the high end where its background is fogged or empty sky.

**Atmosphere C: Volumetric.** One FogVolume uses a custom fog shader to shape a tapered column with soft edges, fading ends and static low-frequency density variation. Global density is zero. The existing sun supplies light and its native volumetric shadow interaction; no spotlight or second light is retained. The sun's `light_volumetric_fog_energy` is temporarily increased to 48, without increasing its surface-light energy. The fog density is 0.055, range 24, anisotropy 0.35 and temporal-history amount 0.8. Ambient/GI injection is zero. The density mask is gated by the shaft's projected receiving tiles so valid air is not chopped according to unrelated terrain beneath the high end. It vanishes when the receiver is no longer bright.

Switching restores the original Environment resource before another mode is applied. Volumetric settings live on a private duplicate. F4 replacement environments are handled explicitly so disabling the comparison mode restores the newly selected lighting preset, not an older one. Removal also restores the environment and fog-energy multiplier. No SDFGI, VoxelGI, global haze, bloom, depth of field, particle system or added shadow caster is introduced.

## Controls and limits

Inspector properties on the reusable component:

- `beam_length` 6 and `beam_width` 1.6; `beam_color` (1, .88, .63), mesh intensity 1.6 and opacity .16.
- `mist_color` (1, .98, .93), `mist_density` .055 and sun `scattering_energy` 48.
- `auto_place_demo` (historical name): automatic current-room placement; disable for a manual `anchor_tile`. Automatic widths adapt to available room space, up to 6 tiles, and lengths span 6?10 tiles. Wider room coverage uses 70% of the configured opacity to preserve readability.

Set properties before running; `rebuild()` applies geometry/material edits during a live session. Orientation follows the real sun: edit its lighting preset and reapply that preset to change light, shaft and cast-shadow direction together. This avoids an independently rotated beam implying a different sun.

Static terrain AABBs are indexed spatially once per floor. Five parallel footprint probes query nearby indexed bounds only on first room placement or light changes; cached room revisits skip those tests. An intervening platform/overhang rejects the whole fake shaft rather than letting it appear below solid support. These conservative bounds can reject a visually plausible opening; they are not a general ray-traced light transport system. There is no gameplay collision/navigation.

The bright mask is a floor-owned L8 texture (46x36 on current 42x32 maps), rebuilt only on player-tile/floor changes or an explicit `refresh_visibility()`. Floor/tile context checks are constant work per frame; no per-frame terrain/actor collection scan is added. The shared game scene includes one controller, without beam input handlers or UI. Repeated static frames perform no mask uploads. Direct external fog edits at an unchanged tile must call `refresh_visibility()`, matching the project's explicit refresh contract.

Mesh transparency uses opaque depth. Existing selectively faded walls are intentionally transparent and may show the shaft; the mesh does not produce physically correct shadows cast into the air by moving actors. Intersecting sprites can receive a modest warm veil but retain their original materials/visibility/alpha settings. Volumetric mist is naturally softer and more spatially convincing, but at the current low froxel resolution and bright stone background its shaft is considerably subtler than the mesh. A faint atmospheric veil can overlap dim backgrounds seen through the bright room; it does not brighten their surface lighting or reveal grid/discovery state. The tactical floor, character silhouette and dim-region distinction must remain readable when tuning strength upward.

First activation may compile shader variants or allocate fog buffers; warmup excludes that startup cost. Hidden FogVolumes in selected volumetric mode can still incur the global volumetric integration cost. The programmatic benchmark can disable the effect for an Original comparison. Do not extrapolate its small measured cost to higher fog resolution or numerous volumes.

## Validation and benchmark

`validate_sunlight_atmosphere.gd` checks world/camera sun alignment, original resource/settings restoration across F4/L, no new lights/collision, static anchor while following, bounded mask updates, concealment, solid-overhang rejection, floor reset and unchanged DungeonData, generation/turn RNG and registered fog/occlusion/material state. Existing lighting, lighting-presets, visibility-refresh, presentation, fog, floor-introduction, floors and ramp-sprite validations were also run. These nine focused scripts all report PASS. Current validation confirms that L/F7 no longer switch the beam, that no control UI is created, and that automatic activation survives startup/reset in every ordinary entry. It also checks that visibility-mask bounds cover the receiver in fixtures without explicit map bounds. The lighting test's two pure snapshot helpers are now static for reuse; its assertions are unchanged.

Headless import and real Forward+ rendering were both checked. GPU captures additionally cover camera-follow, ramp and upper-bridge views. The current-room follow-up additionally renders wide shafts in multiple lower and upper rooms; corridors hide both prototypes.

```powershell
& $godot --path . --log-file .godot/sunlight_prototypes/benchmark.log --script res://tests/capture_sunlight_atmosphere.gd --quit-after 10000
```

Seeds 4 (lower room) and 17 (upper room), identical scene/camera/settings across all configurations: actual 1920x1080 Forward+, 100 Hz V-Sync, max_fps=0; Natural Sunlight preset B in every half. Each configuration starts from the same fresh seed and turn RNG, warms 60 frames, samples 180 idle frames, then executes four native movement/enemy turns with camera follow. The receiver remains stationary. Complete actor/health/fog traces are asserted identical across configurations. No validation runner runs during timing. No geometry rebuild occurs to switch atmosphere.

Historical narrow-beam measurements below predate the automatic current-room expansion. See the current-room measurements below for the latest run.

Final matched measurements (RX 6800 XT, Godot 4.4.1, fog volume size/depth 64/64, unchanged project settings):

| Atmosphere | Idle mean ms | Idle p95 ms | Idle p99 ms | GPU mean ms | Render CPU mean ms | Mean draws |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A original | 10.000 | 10.193 | 10.614 | 4.174 | 2.679 | 449.5 |
| B mesh | 10.000 | 10.179 | 10.477 | 4.355 | 2.639 | 450.5 |
| C volumetric | 10.000 | 10.220 | 11.164 | 4.413 | 2.691 | 449.5 |

All 360 idle frames per configuration stayed below 16.67 ms. At 100 Hz V-Sync they remain near 10 ms, so idle frame averages alone cannot quantify headroom. Mean viewport GPU increments are 0.181 ms for the transparent mesh and 0.240 ms for localized volumetrics. Both retain 60 FPS rendering headroom in these fixtures. Native fog compute/integration is not represented by an added transparent draw counter; locality alone does not establish its cost. There are no extra mesh shadow draws.

| Atmosphere | Movement/action mean ms | p95 ms | p99 ms | Over 16.67 ms | Inclusive action-request CPU mean ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| A original | 21.269 | 22.513 | 22.513 | 8 / 8 | 17.666 |
| B mesh | 21.258 | 22.894 | 22.894 | 8 / 8 | 17.591 |
| C volumetric | 20.955 | 23.061 | 23.061 | 8 / 8 | 17.345 |

**Movement is not certified at smooth 60 FPS:** these short native turns have 20-23 ms action frames even without atmosphere. Inclusive synchronous movement/turn requests take about 17-18 ms. That existing CPU-side action work is outside this graphics prototype; no unrelated optimization was started. Only eight action frames per configuration were collected, so p95/p99 are the maximum, not reliable long-run tail estimates. Small differences between modes must not be interpreted as a gameplay speedup. Actor positions/HP and logical bright/discovered traces match exactly.

Engine static-memory monitor differences are about 0.07 MiB for Mesh and 0.23 MiB for Volumetric versus Original. These are allocator/resource readings, not precise GPU-buffer or VRAM accounting. Resources are floor-owned or reused, with zero mask uploads during warmed idle samples.


Local screenshots, raw timing arrays and logs: ignored `.godot/sunlight_prototypes/`. Existing certificate-store/editor-settings access and shader-cache save errors remain environment limitations. GPU captures complete with PASS and valid images/timings despite returning exit 1 on cache-save errors; no shader compile/assertion failure remains. Some headless shutdown resource warnings also remain.

## Review and recommendation

For the current bright, readable dungeon, **the mesh best matches the requested clearly visible diagonal shaft and is the safest Alpha choice**. It starts automatically and costs one transparent draw. Current timing limitations are recorded below. Keep its intensity restrained near character silhouettes. Volumetrics provide more natural scattering/shadow interaction but are visibly softer/subtler here; keep that as an alternate experiment rather than increasing density until the floor washes out. Matching the full reference would also depend on art-directed openings, darker background composition and later dust—not just stronger fog.

The beam now starts automatically in ordinary game scenes. Its current-room anchor respects discovery and solid overhangs; corridors hide it and entering another room selects that room's placement. Changes remain uncommitted.

Files: new `scripts/effects/sunlight_atmosphere.gd`, `shaders/sunlight_mesh.gdshader`, `shaders/sunlight_mist.gdshader`, two effect/demo scenes, the shared Main scene instance, focused validation and GPU capture helper, UID companions, this document/handoff; the lighting test only exposes reusable static snapshot helpers. Gameplay, generation, camera, terrain renderer, material assets and lighting preset resources remain unchanged.

Godot 4.4 references: [volumetric fog and performance controls](https://docs.godotengine.org/en/4.4/tutorials/3d/volumetric_fog.html), [Fog shader built-ins](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/fog_shader.html), [reverse-Z depth reconstruction](https://docs.godotengine.org/en/4.4/tutorials/shaders/advanced_postprocessing.html#depth-texture).

Automatic-startup follow-up: normal Demo was rendered without any input, and the mesh was visible immediately after introduction. Startup/reset checks now cover all three entries. Existing comparison timings above precede this startup/controls change; no broad re-profiling was performed.

## Current-room expansion follow-up

Automatic coverage now follows room membership, without moving with the camera or adding effects per room. Tested room widths are 2.61?5.45 tiles; dimensions and anchors are cached for the floor. One mesh still contains four triangles, with no added lights or shadow draws. The visibility-mask fallback covers the union of rooms when fixtures omit explicit map bounds.

All 41 validation scripts passed, including focused room entry/revisit, corridor hiding, static-mesh reuse, reset/cache invalidation, fog masking and topology/RNG checks. Maximum measured first-entry presentation update in the focused headless fixture was 0.394 ms; this is not a GPU measurement. Normal Forward+ captures confirm wider coverage in lower and upper rooms (`room_0.png`, `room_2.png`, `room_3.png` in the local artifact directory).

One short repeat used the same 1080p two-seed comparison helper, 180 idle frames and four native movement turns per case:

| Seed | Effect | Idle mean ms | Idle p95 ms | Idle p99 ms | GPU mean ms | Draws | Action mean ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | Original | 13.421 | 17.875 | 19.489 | 2.898 | 405 | 25.281 |
| 4 | Room mesh | 14.114 | 18.021 | 20.033 | 2.902 | 406 | 30.645 |
| 17 | Original | 12.686 | 17.892 | 21.407 | 3.459 | 494 | 27.751 |
| 17 | Room mesh | 13.971 | 19.809 | 22.766 | 3.733 | 495 | 27.737 |

This run has substantial frame-time variability even with the effect disabled, unlike the historical narrow-beam run. It therefore does not establish a reliable before/after CPU or frame-time delta, nor certify stable 60 FPS. Measured mesh GPU increments were 0.004/0.274 ms and one draw in these samples; eight action frames are insufficient for tail claims. Gameplay/HP/fog traces matched, anchors stayed stationary within rooms, and idle mask uploads remained zero. No further broad investigation was started. Raw current results are `benchmark.json`; historical narrow results were preserved as `narrow_benchmark.json`.

## Automatic ground mist

`GroundMist` is a separate, always-on child of the atmosphere controller, independent of room beam visibility and comparison modes. Three translucent layers sit 0.18, 0.43 and 0.68 world units above the local floor. Walkable height uses the renderer's authoritative entity-position helper; surrounding cave cells use the existing continuous-ground plateau height. Geometry is built once per floor into one mesh/surface and casts no shadows. No environment resource, volumetric fog setting, light or gameplay state is changed.

The shader uses slow world-space procedural noise, soft opaque-depth intersections, neutral cool-gray color and low alpha (0.085, reduced in higher layers). This is inexpensive layered visual mist, not volumetric light scattering. It provides subtle wisps while leaving terrain detail and characters readable; it cannot reproduce physically accurate fog shadows or fully continuous fog around vertical cliffs.

A floor-owned coverage texture updates with the existing explicit visibility refresh/player-tile contract. Bright paths receive full coverage; nearby nonwalkable cave spaces receive a soft four-tile falloff. Undiscovered walkable tiles receive zero coverage; explored dim paths receive reduced coverage only near the current bright area. Shader sampling checks the opaque surface behind the mist, preserving map concealment. No idle CPU noise simulation, geometry rebuild or texture uploads occur. Cached resources are replaced on floor reset; F4 lighting changes do not own or replace this material.

Focused validation checks outside/corridor coverage, hidden-path protection, static reuse and unchanged topology/RNG. A normal Forward+ 1920x1080 seed-4 comparison (45 warmup/120 sampled idle frames per half, beam unchanged) measured:

| Ground mist | Mean frame ms | p95 ms | GPU mean ms | Draw calls |
| --- | ---: | ---: | ---: | ---: |
| Hidden | 13.222 | 16.511 | 1.627 | 406 |
| Visible | 12.904 | 16.414 | 1.736 | 407 |

The measured GPU difference is +0.109 ms and one draw; frame averages are noisy and do not establish a speedup or sustained 60 FPS. Normal lower/upper-room captures were inspected. The focused headless mask update measured 1.729 ms in the sampled room, only on visibility changes. Raw logs/captures: `.godot/sunlight_prototypes/ground_*`; full-suite logs use `mist_validate_*`. Existing shader-cache save/certificate-store errors remain host limitations, with successful render completion and no shader compile errors.

Full regression result: 41/42 passed on the initial run; `validate_music.gd` failed its restart playback-position <1-second assertion (line 35), then passed in an isolated repeat. Thus all 42 have passing results, with a recorded music timing flake. No music/gameplay code was changed.

Idle-wisp tuning (2026-10-27): ground-mist alpha increased exactly 50%, from 0.085 to 0.1275. Shader TIME drift is three times the Checkpoint 2 speed (0.066/0.039 noise units per second), independent of turns. Coverage, height, depth fading and draw count are unchanged. Earlier timing tables describe the checkpoint settings.

Idle-motion correction (2026-10-27): previous whole-scene screenshot differences were insufficient proof of fog motion. `tests/capture_ground_mist.gd` now freezes gameplay/actors/UI and validates identical images for identical mist time, changed images when ONLY mist time advances, and live engine-time motion with no mask uploads. On the normal Forward+ seed-4 fixture, frozen difference was exactly zero; 3-second fog-only difference averaged 2.478 8-bit channel levels over the full image, and live idle difference was 1.815. Shader `preview_time=-1` uses engine TIME normally; nonnegative values are solely for deterministic visual checks. Both noise scales now advect together at world velocity (0.24,0.09) tiles/second instead of opposing each other, so wisps travel coherently rather than mostly dissolving. Opacity remains 0.1275. This supersedes the earlier three-times-noise-speed description. Run capture helper with normal rendering and an explicit writable log file; output images/logs remain ignored local artifacts.

## Varied white room beams (2026-10-27)

Main receiver position now has a stable coordinate/visual-seed offset within the room; bounded candidate fallbacks preserve the existing sun-path checks. A salted room hash requests 0, 1 or 2 supporting receivers. Supporting shafts use 32% of the main width, 80% of its length and 50% of its alpha; candidates must be spaced apart and pass the same five-probe overhead check. Unsafe candidates are omitted, so some requested satellites may not appear. All shafts stay parallel to the actual sun: randomizing the receiving location does not introduce conflicting light directions.

Primary/supporting geometry shares one ArrayMesh surface/material and the existing discovery/depth shader. This is still one beam draw and no new lights or shadow casters, with 4?12 triangles rather than always four. Transparency fill cost can increase; no fresh sustained-FPS claim is made. Floor/lighting changes invalidate cached layouts; revisits restore them, and idle frames do not rebuild geometry. Randomness consumes neither generator nor turn RNG. The existing archived volumetric comparison mode still models only the primary shaft; multi-shaft layouts apply to the default mesh presentation.

Beam tint is now near-white `(1,0.98,0.95)`. Natural Sunlight B and Atmospheric C use that same near-white surface-light color; exact-baseline A remains untouched. Warm source stone albedo can still make illuminated floors look cream-colored.

Focused checks cover cached/recomputed layouts, counts 0/1/2, narrower secondary dimensions, exact combined vertex counts, unchanged topology/RNG, fog, ramps, presentation and reversible lighting. The tested eight-room fixture produced support counts `[0,0,0,2,1,1,0,2]`. Normal Forward+ lower/upper-room renders completed without script or shader compilation errors. Existing original-PC shader-cache/certificate warnings remain environmental limitations.

Varied-beam final validation: all 42 validation scripts reported PASS on the full run, with no script/assertion/parse failures. Import and normal Forward+ all-room capture passed. Raw logs: `.godot/sunlight_prototypes/beams_validate_*` and `white_rooms.log`; no new performance benchmark was claimed.

Continuous beam over dark backgrounds (2026-10-27): the default mesh shader no longer samples the terrain bright mask. Room/receiver activation and solid-depth intersection/overhang checks remain; airborne additive glow can now cross dark or undiscovered backgrounds without changing their fog materials or revealing hidden entities. This supersedes the original per-pixel mesh-mask description. The archived volumetric comparison remains receiver-mask-gated, and ground mist retains its separate coverage mask. `tests/capture_sunlight_fog.gd` freezes the scene and compares only beam off/on: 103,130 initially dark pixels received glow in the normal seed-4 fixture, while DungeonData/fog/turn RNG and hidden enemy visibility stayed unchanged. Focused sunlight, fog and presentation validations passed. No floor rotation changes were made: lower compatible floors retain deterministic quarter-turn meshes; upper platforms bypass rotation; cave filler detail is world-aligned. Quarter-turn texture variety can be restored with shared local/UV mapping or a coordinate-hashed shader transform, keeping normal/roughness orientation consistent, without adding nodes or draw calls. Actual GPU deltas would need a short check after implementation.
