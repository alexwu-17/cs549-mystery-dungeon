# AGENTS.md — Visual AI Dungeon Project

## Start here

This targets Godot **4.4.1** (Checkpoint 4 was tested on **4.7.2**, not yet verified on 4.4.1): a 2.5D Mystery Dungeon crawler with authoritative 2D grid gameplay and 3D presentation. Read [docs/CODEX_HANDOFF.md](docs/CODEX_HANDOFF.md) for current systems, configuration, tests, and priorities. Inspect actual source and scene overrides; historical documents and conversation descriptions can be stale.

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

- Checkpoint 2 on `Midterm` includes continuous cave ground, textured rocky slopes, lighting presets, automatic room sunlight and low ground mist. See the handoff's cross-PC checklist before resuming. Desktop Forward+ remains the target; Checkpoint 4 was validated with installed Godot 4.7.2, not a validated 4.4.1 or Web export.
- Keep `CaveGroundSurface`, `CaveRockSlopes` and shared `CaveStoneMaterial` rendering-only. Preserve angular tops, coherent sloping joins, authored stone detail, protected ramps and mandatory foundations; the earlier narrow-bevel experiment was rejected.
- `DungeonLighting` owns reversible A/B/C presets (F4 in debug). `SunlightAtmosphere` owns one reused room-sized beam and floor-lifetime caches; no activation keys/UI remain. `GroundMist` is automatic and independent of beam/corridor visibility. Do not conflate atmospheric mist with logical fog of war.
- Preserve texture-keyed sprite sampling, event-driven terrain fog refresh, static geometry/material reuse and dirty atmosphere-mask uploads. Avoid per-frame image readback, decompression, terrain scans or mesh rebuilds. In-place fog edits at an unchanged player tile require the existing explicit refresh contract.
- Current checks cover 48 validation scripts. Music restart playback timing failed once and passed isolated rerun; report this flake honestly. Headless cleanup warnings and host-specific certificate/shader-cache errors are documented, not blanket permission to ignore errors.
- Target actual 1920x1080 and stable frame times. Short idle GPU checks show headroom, but existing action-frame spikes and variable latest captures mean sustained 60 FPS is not certified. Do not remove detail or alter gameplay on speculative performance grounds.


## Checkpoint 4 — Pokémon presentation and QoL (2026-10-28)

- Branch `Midterm`; checkpoint message: `Checkpoint 4. Most systems complete and replaced sprites with Pokemon. Cleared some bugs remaining from checkpoint 3 such as stairs collision.` Read the newest handoff sections for final behavior; earlier 2×2 boss previews and Swing-sheet descriptions are superseded below.
- Held cardinal movement repeats after 0.24s, then at 0.08s with 3× action presentation speed shared by the acting characters. Release, blocked movement, transitions, death and cancellation restore 1×. Preserve turn consumption, sequential enemy actions and authoritative input locks. Idle and defeat clocks stay independent of this acceleration.
- Pokémon artwork lives only in `assets/sprites/pokemon/{Chimchar,Stunky,Drapion}/`. Preserve original PNG pixels, XML, offsets and shadows; retain `assets/sprites/source/` and placeholder scenes/art as fallback. ZIP downloads stay local/ignored; do not commit duplicate archives or generated `.godot/` artifacts. XML is explicitly included by the export preset; no exports were regenerated.
- Chimchar visually replaces player/swordsman, Stunky replaces skeleton, Drapion replaces minotaur. Internal class names, player HP20/damage3, enemy HP6/damage2, boss HP30/damage18, lifesteal, footprint, pathfinding and dungeon generation remain authoritative. No typing, moves, abilities, evolution, party or selection mechanics were introduced.
- `PokemonSpriteProfile` and `config/pokemon_*.tres` configure directory, display name, scale, anchoring, clip mapping and defeat blink timing. `PokemonSpriteLibrary` caches XML timing, cardinal atlas frames, body markers and opacity metadata once per species/clip set. `pokemon_character_visual.gd` extends CharacterVisual. Add species through profiles/assets rather than species-specific animation code. Missing ordinary clips use existing fallback; optional Faint is discovered automatically.
- Use native rows South0/East2/North4/West6, never mirrored/diagonal frames. Species/clip dimensions and frame durations come from XML. Preserve nearest filtering, aspect ratio, fixed canvas-space ground reference and the larger Drapion scale without changing gameplay occupancy. Body offset markers establish the reference; pinning the body every frame destroys authored hops/lunges. Offset images are metadata, never movement instructions; PMD shadows remain unused in favor of existing shadows.
- Native Idle holds authored timing and bob/jump; consecutive Walk steps retain their animation clock. Attack uses the existing action presentation/completion signal and source duration. Do not add the old procedural leap on flat native attacks or apply damage from animation frames. Surviving Hurt returns to the appropriate rest pose (including boss Charge); damage remains independent of visuals.
- AttackLeap owns native attack world transforms. Ramp-origin attacks follow authoritative source/target heights, rising/descending up to 45 degrees and flattening at exit buffers; retain flat-source behavior exactly. Surface clearance uses cached opaque bounds and cached authored tread envelope, with camera-ray movement and perspective size compensation. Ordinary poses receive this exact correction only on camera-facing stair treads; side/back-facing paths retain their prior behavior. This fixes visual stair intersection, not gameplay collision/topology. Standard generation still excludes uphill DOWN ramps.
- Drapion keeps charge → attack → one-turn Idle recharge. The attack warns **two tiles in a straight line beyond its front edge**, with a frozen direction/lane through charge; horizontal aim chooses the nearer row of the fixed 1×2 footprint. The logical `Swing` animation action maps to **Strike**, not Swing: 72×88, ten frames, 27/60s. Charge is 48×40, ten frames, 20/60s loop. Preserve one 18-damage event, targeting, footprint and native artwork motion; no extra leap or new move mechanics.
- Enemy defeat uses optional Faint (Stunky: 4 frames, 34/60s), or last Hurt frame (Drapion has no Faint), rapidly blinking at 0.075s intervals for at least 0.8s before disappearing. Main removes regular enemies from live occupancy immediately, retains them only in `retiring_enemies` for visuals, and preserves normal healing/remaining turns. Defeat completion/cancellation is separate from action completion; reset must release awaiters without reviving stale work. Blink toggles the sprite child while parent visibility stays fog-owned.
- Boss victory locks gameplay immediately, then waits for blink disappearance and the finishing player presentation before **Demo Complete**. Recheck generation/owner/disposed/completed state after awaits; restart during defeat must never show a stale overlay. Player defeat behavior remains unchanged.
- Dialogue resolves `{character}`, `{enemy}`, `{actor}`, `{target}` and `{amount}` from live actor profiles (Chimchar/Stunky/Drapion now). Each enemy resolves its own name; history stores resolved names at event time. Do not restore hardcoded placeholder names or add selectable/mixed-species spawning mechanics without a separate request. Rename the dungeon in the Demo root Inspector's **Dungeon Name**, or the shared exported default at `scripts/core/main.gd:6`; current name remains Demo Cave by user choice.
- Validation: 48/48 scripts have final PASS results after stair/name fixes; the final Strike-only profile change passed four focused tests (Drapion swing, species frames/anchoring, boss, defeat lifecycle). Normal 1920×1080 captures cover native motion, visibility/shadows, ramp attacks/ordinary front stair poses, four-direction Strike and defeat. Flat player/Stunky attack traces matched 168 samples. Deterministic completion helpers control action/defeat/cancellation; capture helpers may force diagnostic draws to avoid inactive-window waits. Consult handoff for exact runs and initial failures corrected before passing reruns.
- No sustained 60 FPS certification: latest native movement p95 was about 22.87ms on Apple M1 Pro; captures/readback are not benchmarks. Preserve current detail rather than changing gameplay or terrain speculatively. Existing certificate/shutdown resource warnings and historical music flake remain documented.
- Compatibility caveat: local editor/imports used Godot **4.7.2** and `project.godot` currently declares feature version `4.7`; source APIs appear available in 4.4, but 4.4.1 requires a fresh import, full regressions and GPU checks before certification. Do not silently call 4.7-only validation proof of 4.4.1 compatibility. Import descriptors are source settings; `.godot/` caches are machine-local. Preserve `.uid` files for scripts/resources across PCs.

## Boss footprint correction (2026-10-28)

- Current user-authorized Drapion gameplay footprint is **one tile at grid_position**, superseding Checkpoint 4's historical fixed 1x2 and nearer-row rules. Preserve the same large sprite scale, offsets, profile, authored motion and assets.
- Charge/Strike still threatens two cells straight forward from that single tile; no lower-body offset or alternate horizontal row remains. Preserve HP30, damage18, frozen warning/direction, charge/attack/one-turn recharge, greedy movement and defeat lifecycle. Occupancy, melee targeting and traversal use the existing footprint API, not sprite dimensions.

## Condensed presentation Demo (2026-10-28)

- Current Demo is two exploration floors followed by the boss on Floor 3 (`GameModeConfig.DEMO_FINAL_FLOOR=3`). This supersedes historical Floor-5 descriptions for this iteration. Infinite/Limit modes remain unchanged. Tests and capture helpers should use the shared final-floor constant; keep Demo subtitle keys consistent.
