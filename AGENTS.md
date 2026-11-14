# AGENTS.md — Visual AI Dungeon Project

## Start here

This project targets Godot **4.4.1** and GDScript: a 2.5D Mystery Dungeon crawler with authoritative 2D grid gameplay and 3D presentation. Assignment 6 starts from the implemented Assignment 5 baseline. Inspect relevant source and scene overrides; historical documents can be stale.

Read only the relevant sections of [docs/CODEX_HANDOFF.md](docs/CODEX_HANDOFF.md) for system details, configuration and evidence. Older checkpoints and the partially implemented Week 10 roadmap are preserved in [docs/AGENTS_CHECKPOINT_ARCHIVE.md](docs/AGENTS_CHECKPOINT_ARCHIVE.md); they are historical context, not active instructions. Follow the efficiency and testing policy below over historical testing guidance.

Prioritize working, maintainable, targeted changes. Do not add unrelated systems or runtime AI services. Assignment 6 features require user direction; do not assume unfinished roadmap proposals are implemented or newly requested.

## Current baseline and unresolved work

- Starter selection, native Pokémon presentation, shared species/battle state, initial physical/status moves, independent PP, five-turn stat stages, waiting/recovery and repeated enemy spawning are implemented. Current Stunky level is 10; enemy-free respawn grace is 100 completed turns. Demo has two exploration floors and a single-tile Drapion boss on Floor 3, with authored stats and X-Scissor. Preserve these unless requested otherwise; details and superseded values live in the handoff.
- Native role defaults are Chimchar/Stunky/Drapion, with selectable Piplup/Turtwig. Retired placeholder art and music were intentionally removed; do not restore paths or extraction commands from historical notes. Preserve original Pokémon artwork, XML timing, offsets, nearest filtering and native presentation ownership.
- **Occlusion remains unfinished.** Reproduce reported corner/southern-wall edge cases and first-activation lag in normal rendering before changing it. Compare first and repeated activation; investigate trigger correctness and frame cost without assuming the cause. Existing fixtures do not certify all corners or sustained 60 FPS.
- Preserve intended occlusion behavior: only combined camera-to-player sprite blockage greater than 25% on the authoritative current tile activates the circle; a blocked neighbor alone never activates it. Protect ramps/stairs/supports/player floor, retain soft 3×3 nearby terrain lighting and full visible actor sprites, and preserve attack visibility priority/frozen occlusion decisions. Fog remains independent.
- Latest recorded Godot 4.4.1 regression evidence is 57/57, with documented warnings and a historical music timing flake. Older Checkpoint 4 evidence used 4.7.2. This is historical evidence, not a requirement to rerun everything or certification of GPU appearance, exports or sustained 60 FPS.

## Elemental projectile branch baseline

- Ember, Bubble and Razor Leaf unlock on Floor 3 (configurable), fill the first empty move slot (normally O), and retain PP across floors; fresh runs forget the unlock. Each uses a four-tile straight lane following authoritative traversal, stopping at the first blocker or enemy/boss. Misses consume PP and a turn.
- Starter types enable existing STAB; type effectiveness remains neutral. Native Shoot clips drive the character presentation; projectile billboards remain placeholders. Appearance, Shoot timing, fog interaction and balance need manual verification.
- Implementation details and previously reported validation are in the newest projectile section of [docs/CODEX_HANDOFF.md](docs/CODEX_HANDOFF.md). Use the efficiency policy below for new work; historical full-suite runs are not a requirement.

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
- Follow the Codex Efficiency and Testing Policy below when choosing verification. Consult `tests/README.md` only for relevant test ownership and commands; suite availability does not require running it.
- Exit code zero is insufficient: check errors/assertions and require completion/PASS messages. Use deterministic presentation completion/cancellation in tests rather than sleeps.
- Headless success proves neither GPU appearance nor 60 FPS. For visual changes, report what needs manual verification in Godot; do not launch extensive automated capture runs by default.
- Separate verified behavior, limitations, and assumptions. Update the handoff when architecture/startup/configuration changes materially.

## Rendering performance contracts

- Keep `CaveGroundSurface`, `CaveRockSlopes` and shared `CaveStoneMaterial` rendering-only. Preserve angular tops, coherent sloping joins, authored stone detail, protected ramps and mandatory foundations.
- `DungeonLighting` owns reversible presets. `SunlightAtmosphere` owns one reused room-sized beam and floor-lifetime caches. `GroundMist` is automatic and independent of beam/corridor visibility; atmospheric mist is separate from logical fog of war.
- Preserve texture-keyed sprite sampling, event-driven terrain fog refresh, static geometry/material reuse and dirty atmosphere-mask uploads. Avoid per-frame image readback, decompression, terrain scans or mesh rebuilds. In-place fog edits at an unchanged player tile require explicit refresh.
- Target 1920×1080 and stable frame times. Sustained 60 FPS remains unverified; do not remove detail or alter gameplay on speculative performance grounds.

## Codex Efficiency and Testing Policy

This project uses Godot 4.4.1 and GDScript.

Our priority is efficient, targeted implementation and verification while preserving existing gameplay behavior.

Repository Exploration

Inspect only files relevant to the requested task and their immediate dependencies.

Avoid repeatedly searching or reading files whose contents are already understood within the current task.

Do not perform full-repository analysis unless required by a cross-system change.

Avoid reading large generated assets, import metadata, or unrelated scene files unnecessarily.

Implementation

Make minimal, targeted changes.

Reuse existing systems rather than introducing duplicate architecture.

Do not perform unrelated refactors or optimizations.

Do not modify unrelated gameplay mechanics or balancing values.

Testing and Verification

Use risk-based testing proportional to the scope of each change.

Level 1 — Small changes:
For stat adjustments, configuration edits, simple UI changes, and asset references, perform a focused syntax/import check when relevant. Do not run the entire test suite.

Level 2 — Gameplay features:
For combat mechanics, projectile behavior, PP handling, or AI changes, run relevant focused tests and one Godot headless validation.

Level 3 — Major changes:
For shared system refactors, dungeon generation changes, or modifications to global turn scheduling, run broader regression tests as necessary.

Testing Restrictions

Do not automatically run every available test after each modification.

Avoid repeated headless launches unless a prior run revealed a relevant error.

Do not create extensive new test suites for small changes.

Do not repeatedly run tests that have already passed unless subsequent code changes affect them.

If a test fails, investigate the relevant failure rather than rerunning everything.

Prefer targeted tests over full-project verification.

For visual changes, explain what requires manual verification in Godot rather than attempting extensive automated visual testing.

Completion

After implementation and focused verification:

Summarize the changes made.

Report the tests performed and their results.

Identify any unverified behavior.

Stop.

Do not continue with additional testing, refactoring, or optimization unless explicitly requested.