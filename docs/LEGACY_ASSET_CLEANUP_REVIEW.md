# Legacy asset cleanup - completed

Status: **completed (2026-11-09)** after the user requested native role defaults and cleanup.
The71 reviewed legacy files are now absent (four music files were already absent
when deletion began;67 remaining files were removed). Source Pokemon artwork
and all active music remain unchanged.

All live actors and role-default fallbacks now use native Pokemon profiles. Clearing or invalidating a custom player/enemy/boss profile resolves to Chimchar/Stunky/Drapion respectively; Piplup/Turtwig selection remains supported.

## Pre-cleanup reference audit (2026-11-09, historical)

The earlier audit made no deletions; its findings below describe the state before cleanup. Searches covered scripts, scenes, configuration, tools, tests and the placeholder music resource UIDs, excluding generated import caches.

| Candidate | Current use | Approximate size |
| --- | --- | ---: |
| `boss_placeholder.mp3` | No code/scene/config/test/tool or UID references; unused | 10.182 MiB |
| `dungeon_placeholder.mp3` | No code/scene/config/test/tool or UID references; unused | 9.727 MiB |
| `assets/sprites/skeleton/` | Enemy scene initial texture, fallback directory, fallback tests | 1.184 MiB |
| `assets/sprites/swordsman/` | Player fallback directory and explicit fallback tests | 0.952 MiB |
| `assets/sprites/minotaur/` | Boss scene initial texture, fallback directory, fallback tests | 1.528 MiB |
| `assets/sprites/source/` | Original sheets used by extraction tool/manifest/Python validation; no live presentation dependency | 3.476 MiB |

`CharacterVisual._ready()` loads the configured old-art directory unconditionally, and `pokemon_character_visual.gd` calls it before loading native clips. These are current runtime loads, even though normal rendering subsequently uses Pokemon artwork. Do not delete the sprite directories alone: first replace scene initial textures/directories and retire the old-art loader/fallback expectations while preserving reusable visual classes and native anchoring/turn/lifecycle tests.

At audit time, dungeon music was Mt. Coronet; it has since been replaced by `temporal_tower_dungeon.ogg` (loop17.450). Current active tracks are Temporal Tower, `Boss_Battle_Orchestral.ogg` (loop22.540) and selection `character_select_menu.ogg`; preserve these sources. Current export presets use `all_resources` with no exclusion filter, so unused imported resources can still enter future exports. Existing generated exports were not regenerated or inspected for embedded historical assets; source deletion would not rewrite old exports or Git history.

## Completed asset deletions

68 files, approximately 27.05 MiB. Sprite folders include their `.import` source descriptors. Their fallback paths/tests and scene dependencies were retired as part of this cleanup. The two placeholder tracks had no live references.

### assets/sprites/swordsman

- [x] `assets/sprites/swordsman/attack_back.png`
- [x] `assets/sprites/swordsman/attack_back.png.import`
- [x] `assets/sprites/swordsman/attack_front.png`
- [x] `assets/sprites/swordsman/attack_front.png.import`
- [x] `assets/sprites/swordsman/attack_left.png`
- [x] `assets/sprites/swordsman/attack_left.png.import`
- [x] `assets/sprites/swordsman/attack_right.png`
- [x] `assets/sprites/swordsman/attack_right.png.import`
- [x] `assets/sprites/swordsman/back.png`
- [x] `assets/sprites/swordsman/back.png.import`
- [x] `assets/sprites/swordsman/front.png`
- [x] `assets/sprites/swordsman/front.png.import`
- [x] `assets/sprites/swordsman/left.png`
- [x] `assets/sprites/swordsman/left.png.import`
- [x] `assets/sprites/swordsman/right.png`
- [x] `assets/sprites/swordsman/right.png.import`

### assets/sprites/skeleton

- [x] `assets/sprites/skeleton/attack_back.png`
- [x] `assets/sprites/skeleton/attack_back.png.import`
- [x] `assets/sprites/skeleton/attack_front.png`
- [x] `assets/sprites/skeleton/attack_front.png.import`
- [x] `assets/sprites/skeleton/attack_left.png`
- [x] `assets/sprites/skeleton/attack_left.png.import`
- [x] `assets/sprites/skeleton/attack_right.png`
- [x] `assets/sprites/skeleton/attack_right.png.import`
- [x] `assets/sprites/skeleton/back.png`
- [x] `assets/sprites/skeleton/back.png.import`
- [x] `assets/sprites/skeleton/front.png`
- [x] `assets/sprites/skeleton/front.png.import`
- [x] `assets/sprites/skeleton/left.png`
- [x] `assets/sprites/skeleton/left.png.import`
- [x] `assets/sprites/skeleton/right.png`
- [x] `assets/sprites/skeleton/right.png.import`

### assets/sprites/minotaur

- [x] `assets/sprites/minotaur/back.png`
- [x] `assets/sprites/minotaur/back.png.import`
- [x] `assets/sprites/minotaur/charge.png`
- [x] `assets/sprites/minotaur/charge.png.import`
- [x] `assets/sprites/minotaur/front.png`
- [x] `assets/sprites/minotaur/front.png.import`
- [x] `assets/sprites/minotaur/left.png`
- [x] `assets/sprites/minotaur/left.png.import`
- [x] `assets/sprites/minotaur/right.png`
- [x] `assets/sprites/minotaur/right.png.import`
- [x] `assets/sprites/minotaur/spin_01.png`
- [x] `assets/sprites/minotaur/spin_01.png.import`
- [x] `assets/sprites/minotaur/spin_02.png`
- [x] `assets/sprites/minotaur/spin_02.png.import`
- [x] `assets/sprites/minotaur/spin_03.png`
- [x] `assets/sprites/minotaur/spin_03.png.import`
- [x] `assets/sprites/minotaur/spin_04.png`
- [x] `assets/sprites/minotaur/spin_04.png.import`
- [x] `assets/sprites/minotaur/spin_05.png`
- [x] `assets/sprites/minotaur/spin_05.png.import`
- [x] `assets/sprites/minotaur/spin_06.png`
- [x] `assets/sprites/minotaur/spin_06.png.import`
- [x] `assets/sprites/minotaur/spin_07.png`
- [x] `assets/sprites/minotaur/spin_07.png.import`
- [x] `assets/sprites/minotaur/spin_08.png`
- [x] `assets/sprites/minotaur/spin_08.png.import`

### assets/sprites/source

- [x] `assets/sprites/source/AIMinotaurPlaceholderPixelSheet.png`
- [x] `assets/sprites/source/AIMinotaurPlaceholderPixelSheet.png.import`
- [x] `assets/sprites/source/AISkeletonPlaceholderPixelSheet.png`
- [x] `assets/sprites/source/AISkeletonPlaceholderPixelSheet.png.import`
- [x] `assets/sprites/source/AISwordsmanPlaceholderPixelSheet.png`
- [x] `assets/sprites/source/AISwordsmanPlaceholderPixelSheet.png.import`

### assets/audio/music

- [x] `assets/audio/music/dungeon_placeholder.mp3`
- [x] `assets/audio/music/dungeon_placeholder.mp3.import`
- [x] `assets/audio/music/boss_placeholder.mp3`
- [x] `assets/audio/music/boss_placeholder.mp3.import`

## Related legacy-only files proposed for removal with the sprite assets

- [x] `assets/sprites/extraction_manifest.json` — hashes/anchors for the three placeholder sheets.
- [x] `tools/extract_character_sprites.py` — extracts those placeholder sheets.
- [x] `tests/validate_sprite_extraction.py` — verifies those placeholder extractions.

## Dependency updates completed with deletion

- `scenes/player/player.tscn`: remove the swordsman fallback directory/anchor after retiring that fallback. Its initial texture already uses Chimchar.
- `scenes/enemies/test_enemy.tscn`: replace the skeleton initial texture and fallback configuration with Stunky.
- `scenes/enemies/minotaur.tscn`: replace the minotaur initial texture and fallback configuration with Drapion.
- `scripts/effects/character_visual.gd` and `scripts/effects/pokemon_character_visual.gd`: retire old-art loading while preserving shared animation signals, visibility, anchoring, ramp correction and completion/cancellation. Keep the reusable classes.
- `tests/round_test_helper.gd`: retire `use_placeholder_visuals`.
- `tests/validate_attack_leap.gd`, `tests/validate_character_sprites.gd`, `tests/validate_ramp_sprites.gd`, `tests/validate_pokemon_sprites.gd`: remove or replace old-art-specific expectations; retain native transform/ramp/lifecycle coverage.
- `tests/profile_pokemon_sprites.gd`: remove its old-art comparison, retaining native profiling.
- `AGENTS.md`, `docs/CODEX_HANDOFF.md`, `assets/sprites/pokemon/README.md`, `tests/README.md`: update current fallback/asset instructions and commands. Historical evidence should remain clearly labeled historical.

## Keep

- `assets/audio/music/character_select_menu.ogg` and `.import` - active starter-selection music.
- All Pokémon assets (Chimchar, Piplup, Turtwig, Stunky, Drapion), including original PNG/XML/offset/shadow files.
- `assets/audio/music/temporal_tower_dungeon.ogg` and `.import` - current dungeon music, looping from17.450 seconds.
- Retired Mt. Coronet and PMD boss MP3 sources/import descriptors are now deleted; historical mentions below are not dependencies.
- `assets/audio/music/Boss_Battle_Orchestral.ogg` and `.import` ? current boss music, looping from22.540 seconds.
- Existing reusable gameplay classes, scenes, native animation code and terrain assets. Internal Skeleton/Minotaur names do not require removing their gameplay systems.
- Local ignored archives and `.godot/` artifacts are outside this tracked-asset deletion proposal.

The user reviewed the audit and requested native default fallbacks/cleanup. Scenes, loaders, tests and current documentation were updated with the removals. See the newest handoff for validation results.
