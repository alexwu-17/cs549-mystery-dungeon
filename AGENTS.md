# AGENTS.md — Visual AI Dungeon Project

## Start here

This is a Godot **4.4.1** GDScript project: a 2.5D Mystery Dungeon crawler with authoritative 2D grid gameplay and 3D presentation. Read [docs/CODEX_HANDOFF.md](docs/CODEX_HANDOFF.md) for current systems, configuration, tests, and priorities. Inspect actual source and scene overrides; historical documents and conversation descriptions can be stale.

Prioritize working, testable, maintainable changes. Pokémon gameplay is future work. Do not add unrelated systems or runtime AI services.

## Architectural ownership

- `DungeonData` owns topology, elevations, ramps, and fog state. Use `Vector2i` positions and shared `can_traverse()` rules, not physics collision, navigation meshes, or a second dungeon representation.
- `Main` coordinates rounds, occupancy, and floor lifecycle. Keep reusable generation, enemy behavior, health, camera, audio, and UI logic in their existing helpers.
- Three entry scenes share inherited gameplay. Do not duplicate gameplay scenes/scripts for mode differences. Preserve mode/configuration across restart.
- Rendering must not mutate gameplay tiles, elevations, spawns, connectivity, or generation RNG. Decorative geometry has no gameplay collision/navigation effects.
- Keep damage independent of visuals. `CharacterVisual` selects frames; `AttackLeap` owns attack visual transforms. Avoid competing transform animations.

## Preserve gameplay and procedural contracts

- Successful movement and Space attacks consume turns; blocked movement does not. There is no bump attack. Preserve independently shuffled, sequential enemy actions and existing mechanics unless requested otherwise.
- Check lifecycle/generation tokens after every awaited presentation and before scheduling another action or unlocking input. Cancellation must never revive stale rounds. Floor-introduction locks remain authoritative through the final fade.
- Stairs must not run an outgoing floor's enemy phase. Preserve HP across floors; reset through the existing fresh-run path.
- Preserve randomized room placement, ordering, chain connectivity, and same-height L corridors. Do not silently replace them with nearest-neighbor/MST routing, flatten elevations, or enforce diagnostic spacing thresholds.
- Standard transitions reserve three straight ramp tiles plus a flat buffer at each end. Preserve cardinal bidirectional traversal, side-entry restrictions, compatible combat adjacency, and atomic validation before carving.
- Use bounded retries and explicitly reported fallbacks. Preserve benchmark, boss arena, and legacy fixture exemptions.
- Visual randomness must be coordinate-based and independent of generator RNG. Explain intentional same-seed behavior changes and test them.

## Rendering invariants

- Preserve perspective camera angle/framing unless requested. Do not solve occlusion by switching to overhead/orthographic presentation.
- Distinguish conventional walls, mandatory upper-room foundations, shallow corridor supports, decorative terraces, and cave backing. Removing walls must not remove necessary support.
- Shorten wall components only, not combined walkable floors. Do not randomly rotate directional assets or ramps.
- Use authoritative elevation/world-position helpers; preserve sprite feet, ramp clearance, aspect ratios, nearest filtering, and source artwork.
- Keep fog/discovery separate from selective occlusion. Restore occlusion without overwriting fog materials/state; hidden geometry must not leave unintended shadows.
- Preserve ramp asset contracts and distinguish ramp stair models from exit staircase visuals.

## Working and validating safely

- Inspect `git status` and relevant diffs first. Substantial uncommitted work may exist. Never reset, clean, overwrite user configurations, or delete assets assuming they are disposable.
- Scope changes carefully. Do not destructively modify original art or imported source assets. Do not commit, push, publish, or regenerate exports unless requested.
- Run headless import and focused tests; run full regressions for shared-system changes. Commands are in the handoff.
- Exit code zero is insufficient: check errors/assertions and require completion/PASS messages. Use deterministic presentation completion/cancellation in tests rather than sleeps.
- Headless success proves neither GPU appearance nor 60 FPS. Use normal rendering for shadows, transparency, occlusion, colors, and actual MultiMesh readback.
- Separate verified behavior, limitations, and assumptions. Update the handoff when architecture/startup/configuration changes materially.

## Graphics checkpoint and performance contracts

- Checkpoint 2 on `Midterm` includes continuous cave ground, textured rocky slopes, lighting presets, automatic room sunlight and low ground mist. See the handoff's cross-PC checklist before resuming. This is a desktop Forward+ Godot 4.4.1 checkpoint, not a validated Web export.
- Keep `CaveGroundSurface`, `CaveRockSlopes` and shared `CaveStoneMaterial` rendering-only. Preserve angular tops, coherent sloping joins, authored stone detail, protected ramps and mandatory foundations; the earlier narrow-bevel experiment was rejected.
- `DungeonLighting` owns reversible A/B/C presets (F4 in debug). `SunlightAtmosphere` owns one reused room-sized beam and floor-lifetime caches; no activation keys/UI remain. `GroundMist` is automatic and independent of beam/corridor visibility. Do not conflate atmospheric mist with logical fog of war.
- Preserve texture-keyed sprite sampling, event-driven terrain fog refresh, static geometry/material reuse and dirty atmosphere-mask uploads. Avoid per-frame image readback, decompression, terrain scans or mesh rebuilds. In-place fog edits at an unchanged player tile require the existing explicit refresh contract.
- Current checks cover 42 validation scripts. Music restart playback timing failed once and passed isolated rerun; report this flake honestly. Headless cleanup warnings and host-specific certificate/shader-cache errors are documented, not blanket permission to ignore errors.
- Target actual 1920x1080 and stable frame times. Short idle GPU checks show headroom, but existing action-frame spikes and variable latest captures mean sustained 60 FPS is not certified. Do not remove detail or alter gameplay on speculative performance grounds.
