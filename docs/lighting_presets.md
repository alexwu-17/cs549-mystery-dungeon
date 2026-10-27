# Alpha lighting presets

Godot 4.4.1 Forward+. This lighting pass leaves the existing uncommitted terrain work, all environmental geometry, gameplay, camera and material maps unchanged.

## Switching

The shared Main scene contains `LightingPresets`, inherited by Demo and Limit Testing. Its `selected_preset` Inspector setting selects startup A/B/C. **A remains the default.** In development builds, **F4** cycles A -> B -> C and prints the selected name. Hold/repeat does not cycle repeatedly. Disable `debug_switch_enabled` to remove the hotkey. Preset selection persists through R and floor transitions because the controller remains with Main. Programmatic switching: `get_node("LightingPresets").apply_preset(1)`.

Editable resources:

- `config/lighting/baseline.tres`
- `config/lighting/natural_sunlight.tres`
- `config/lighting/atmospheric.tres`

A captures the actual scene light and environment at startup rather than approximating them with new constants. Every selection restores that capture before applying its overrides. Environment resources are duplicated so editing a live preset cannot change the original scene or another game instance. Switching changes no fog materials, sprite configuration, mesh, camera, visibility cache or gameplay state. The controller has no process callback.

## Settings and assessment

| Setting | A: current baseline | B: natural sunlight | C: atmospheric HD-2D |
| --- | --- | --- | --- |
| Primary lights | One directional | Same single directional | Same single directional |
| Sun direction | Exact scene transform | Euler (-48, -32, 0) degrees | Same as B |
| Sun RGB | White | (1.00, 0.94, 0.84) | Same as B |
| Sun energy | 0.90 | 1.00 | 1.00 |
| Angular distance | 0.50 degrees | 0.50 degrees | 0.75 degrees |
| Ambient RGB | (1, 1, 1) | (0.78, 0.85, 1.00) | (0.72, 0.80, 0.94) |
| Ambient energy | 0.25 | 0.30 | 0.27 |
| Shadow bias / normal bias | 0.03 / 0.20 | 0.025 / 0.12 | Same as B |
| Directional shadow range | 40 | 40 | 40 |
| Shadow cascades/atlas/filter quality | Original project settings | Unchanged | Unchanged |
| SSAO | Off | Off | On: radius 0.65, intensity 0.55, power 1.15, detail 0.35 |

Ambient illumination remains color-based. Reflected environment light remains disabled as in A; direct material highlights remain available. No sky/reflection probe, SSAO global-quality override, SSR, SSIL, SDFGI, VoxelGI, volumetric fog, bloom, exposure, tonemapping, color grading or camera change was added. C changes the angular source size modestly; it does not increase the shadow atlas or number of lights.

The original white ambient and relatively broad top lighting make small ledges look flat. B gives cracks and ledges more directional contrast, warmer exposed stone and cooler readable shadow fill. C adds restrained contact depth with a slightly cooler/darker ambient balance and modest softness. In normal-renderer previews, bright paths and sprite silhouettes remain distinguishable in enclosed elevation-0 rooms, open elevation-1 platforms, ramp approaches and upper bridges. Distant nonbright terrain remains deliberately dim under the existing fog rules; lighting does not replace discovery or selectively fading geometry.

## Material limits

- Imported OBJ/MTL floors and conventional walls mostly use flat material colors with **modeled** cracks, chips and masonry. Their small cracks can receive directional shading and geometric shadows; they are not painted high-resolution texture detail. Half-height wall scaling compresses some of that relief.
- Cave/cliff materials already reuse 128x128 albedo/normal/roughness maps baked from the authored floor model. Cliff normal strength is 0.3, with restrained high roughness. Continuous ground uses the same stone signal and derivative relief. This existing shared-map prototype is retained rather than duplicating materials for each preset or adding another texture pipeline.
- Normal maps change surface illumination, not the silhouette or physical shadow volume. Their source resolution/model relief and the shadow map's resolution limit tiny crack detail. Raising shadow intensity cannot fix missing geometry/maps. Better dedicated stone maps remain future art work if the baked relief is insufficient.
- Characters remain unshaded, nearest filtered, billboarded, alpha-prepass sprites with double-sided shadow casting. Their colors stay independent of sun/ambient tint, while their cast shadows change direction/softness with the light. This preserves readability.

## Validation and benchmark

`validate_lighting_presets.gd` exercises all three inherited game modes: exact baseline/environment round trips, isolated scene resources, one light, no expensive unsupported effects, immediate switching without turns, F4 repeat filtering, restart persistence, and unchanged fog/occlusion/material state, camera, DungeonData and both generation/turn RNG. Existing lighting validation continues to check the original .25 ambient baseline and sprite shadow behavior.

Normal comparison helper:

```powershell
& $godot --path . --log-file .godot/lighting_presets/benchmark.log --script res://tests/capture_lighting_presets.gd --quit-after 20000
# Quick images only, not timing evidence:
& $godot --path . --log-file .godot/lighting_presets/preview.log --script res://tests/capture_lighting_presets.gd -- preview
```

Fixed seeds 4 and 17, four identical poses each (enclosed lower room, exposed upper platform, ramp approach and shallow upper bridge). Each preset warms 60 frames and samples 120 at actual 1920x1080, Forward+, 100 Hz V-Sync, max_fps=0. All existing sprite/fog/terrain optimizations remain enabled. No concurrent validation runner runs during the timed capture. Geometry is built once per seed and never rebuilt to switch lights.

For seed 4's lower/upper views, a separate 30-frame warmup/90-frame shadow-off sample estimates the total shadow-associated cost. Its delta is **not an isolated GPU shadow-pass timestamp**: it includes changes in filtering, shading and pass scheduling. Exact pass timings require the Godot Visual Profiler. Raw data, measured settings, screenshots and logs live in ignored `.godot/lighting_presets/`.

All **40/40 validation scripts** reported PASS with no script/assertion/parse/shader failures. Headless import registered the new classes; normal GPU captures completed with valid images and a PASS marker. Existing certificate-store/editor-settings/shader-cache save errors remain in the restricted environment. The GPU process exits 1 after cache-save errors despite completing its capture; these are separate from shader compilation or test assertions. Some validation shutdown resource warnings also remain.

Pooled comparison across eight matched views (960 measured frames per preset):

| Preset | Frame mean ms | Frame p95 ms | Frame p99 ms | GPU mean ms | Render CPU mean ms | Mean draw calls | Frames >16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A baseline | 10.005 | 10.735 | 12.313 | 3.949 | 3.265 | 407.9 | 0 / 960 |
| B natural sunlight | 9.991 | 10.699 | 11.697 | 3.878 | 3.280 | 418.4 | 0 / 960 |
| C atmospheric | 10.083 | 11.601 | 13.721 | 4.413 | 3.428 | 420.8 | 1 / 960 |

A and B had no sampled frames above 16.67 ms. C had one at 17.178 ms (0.104%). All preset p95/p99 values stayed below 16.67 ms, supporting 60 FPS headroom in these short idle views, not sustained exploration/combat/OBS certification. Timing differences below a few tenths of a millisecond include clock/scheduling noise.

Estimated shadow-associated cost (on minus off), seed 4:

| Preset / view | GPU difference ms | Shadow-associated draw calls |
| --- | ---: | ---: |
| A / lower | 1.297 | 213 |
| B / lower | 0.796 | 208 |
| C / lower | 1.087 | 209 |
| A / upper | 0.533 | 67 |
| B / upper | 1.033 | 70 |
| C / upper | 0.617 | 70 |

The light angle changes which objects enter shadow cascades, explaining some draw-call variation even though no geometry or light count changes. A/B/C all retain four directional shadow cascades (mode 2) and the 40-unit range. Current project SSAO quality and shadow-filter settings were both recorded as integer 2 and remain unmodified. Tonemapping stays linear (mode 0). C adds about 0.536 ms viewport GPU time over B on average; this combines SSAO and source-size changes and is not a standalone SSAO timestamp.

**Alpha recommendation: B.** It gives visibly stronger crack/ledge contrast with warm sunlight and readable cooler shadows, at essentially baseline GPU cost. Character colors remain clear and the bright-path/dim-terrain contrast survives. C is a useful optional presentation comparison with modest extra cost, but its added contact-depth effect is subtle in these assets, so B preserves more headroom. A remains the startup default for a dependable comparison; select B in the LightingPresets Inspector for an Alpha run, or press F4 once.


For interactive pass attribution in Godot 4.4.1: run the shared scene from the editor, open **Debugger > Visual Profiler**, enable profiling, stand at an unchanged tile, use F4, and compare the same render-pass categories after warmup. Share the per-pass GPU/CPU timings (especially shadow and SSAO passes), actual F3 resolution, preset, seed, tile and capture length. Keep the ordinary Profiler open separately for script/turn stalls. These editor timings include editor overhead; the standalone measurements above do not.

## Files

`scenes/main/main.tscn` adds only the controller node/script. New helpers: `scripts/core/dungeon_lighting.gd` and `dungeon_lighting_preset.gd`; three `config/lighting/*.tres` resources; `tests/validate_lighting_presets.gd` and `capture_lighting_presets.gd`; generated script UID companions; this report and the handoff. No renderer, material, generation or gameplay code was edited in this lighting pass.

Godot references: [Environment / SSAO](https://docs.godotengine.org/en/4.4/classes/class_environment.html#class-environment-property-ssao-enabled), [DirectionalLight3D shadow range and cascades](https://docs.godotengine.org/en/4.4/classes/class_directionallight3d.html#class-directionallight3d-property-directional-shadow-max-distance).
