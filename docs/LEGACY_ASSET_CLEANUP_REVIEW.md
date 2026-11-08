# Legacy demo cleanup — review before deletion

Status: **proposal only; none of these assets has been deleted.**

Chimchar is the existing runtime default. The player scene now also starts with a south-facing Chimchar Idle atlas frame, rather than referencing the swordsman as its initial texture. Starter selection is not implemented yet; keep Chimchar as the valid default until then.

## Proposed asset deletions

68 files, approximately 27.06 MiB. Sprite folders include their `.import` source descriptors. The old sprite files are still needed by explicit fallback paths/tests until those references are retired in the approved cleanup. The two placeholder music tracks have no live code/scene references.

### assets/sprites/swordsman

- [ ] `assets/sprites/swordsman/attack_back.png`
- [ ] `assets/sprites/swordsman/attack_back.png.import`
- [ ] `assets/sprites/swordsman/attack_front.png`
- [ ] `assets/sprites/swordsman/attack_front.png.import`
- [ ] `assets/sprites/swordsman/attack_left.png`
- [ ] `assets/sprites/swordsman/attack_left.png.import`
- [ ] `assets/sprites/swordsman/attack_right.png`
- [ ] `assets/sprites/swordsman/attack_right.png.import`
- [ ] `assets/sprites/swordsman/back.png`
- [ ] `assets/sprites/swordsman/back.png.import`
- [ ] `assets/sprites/swordsman/front.png`
- [ ] `assets/sprites/swordsman/front.png.import`
- [ ] `assets/sprites/swordsman/left.png`
- [ ] `assets/sprites/swordsman/left.png.import`
- [ ] `assets/sprites/swordsman/right.png`
- [ ] `assets/sprites/swordsman/right.png.import`

### assets/sprites/skeleton

- [ ] `assets/sprites/skeleton/attack_back.png`
- [ ] `assets/sprites/skeleton/attack_back.png.import`
- [ ] `assets/sprites/skeleton/attack_front.png`
- [ ] `assets/sprites/skeleton/attack_front.png.import`
- [ ] `assets/sprites/skeleton/attack_left.png`
- [ ] `assets/sprites/skeleton/attack_left.png.import`
- [ ] `assets/sprites/skeleton/attack_right.png`
- [ ] `assets/sprites/skeleton/attack_right.png.import`
- [ ] `assets/sprites/skeleton/back.png`
- [ ] `assets/sprites/skeleton/back.png.import`
- [ ] `assets/sprites/skeleton/front.png`
- [ ] `assets/sprites/skeleton/front.png.import`
- [ ] `assets/sprites/skeleton/left.png`
- [ ] `assets/sprites/skeleton/left.png.import`
- [ ] `assets/sprites/skeleton/right.png`
- [ ] `assets/sprites/skeleton/right.png.import`

### assets/sprites/minotaur

- [ ] `assets/sprites/minotaur/back.png`
- [ ] `assets/sprites/minotaur/back.png.import`
- [ ] `assets/sprites/minotaur/charge.png`
- [ ] `assets/sprites/minotaur/charge.png.import`
- [ ] `assets/sprites/minotaur/front.png`
- [ ] `assets/sprites/minotaur/front.png.import`
- [ ] `assets/sprites/minotaur/left.png`
- [ ] `assets/sprites/minotaur/left.png.import`
- [ ] `assets/sprites/minotaur/right.png`
- [ ] `assets/sprites/minotaur/right.png.import`
- [ ] `assets/sprites/minotaur/spin_01.png`
- [ ] `assets/sprites/minotaur/spin_01.png.import`
- [ ] `assets/sprites/minotaur/spin_02.png`
- [ ] `assets/sprites/minotaur/spin_02.png.import`
- [ ] `assets/sprites/minotaur/spin_03.png`
- [ ] `assets/sprites/minotaur/spin_03.png.import`
- [ ] `assets/sprites/minotaur/spin_04.png`
- [ ] `assets/sprites/minotaur/spin_04.png.import`
- [ ] `assets/sprites/minotaur/spin_05.png`
- [ ] `assets/sprites/minotaur/spin_05.png.import`
- [ ] `assets/sprites/minotaur/spin_06.png`
- [ ] `assets/sprites/minotaur/spin_06.png.import`
- [ ] `assets/sprites/minotaur/spin_07.png`
- [ ] `assets/sprites/minotaur/spin_07.png.import`
- [ ] `assets/sprites/minotaur/spin_08.png`
- [ ] `assets/sprites/minotaur/spin_08.png.import`

### assets/sprites/source

- [ ] `assets/sprites/source/AIMinotaurPlaceholderPixelSheet.png`
- [ ] `assets/sprites/source/AIMinotaurPlaceholderPixelSheet.png.import`
- [ ] `assets/sprites/source/AISkeletonPlaceholderPixelSheet.png`
- [ ] `assets/sprites/source/AISkeletonPlaceholderPixelSheet.png.import`
- [ ] `assets/sprites/source/AISwordsmanPlaceholderPixelSheet.png`
- [ ] `assets/sprites/source/AISwordsmanPlaceholderPixelSheet.png.import`

### assets/audio/music

- [ ] `assets/audio/music/dungeon_placeholder.mp3`
- [ ] `assets/audio/music/dungeon_placeholder.mp3.import`
- [ ] `assets/audio/music/boss_placeholder.mp3`
- [ ] `assets/audio/music/boss_placeholder.mp3.import`

## Related legacy-only files proposed for removal with the sprite assets

- [ ] `assets/sprites/extraction_manifest.json` — hashes/anchors for the three placeholder sheets.
- [ ] `tools/extract_character_sprites.py` — extracts those placeholder sheets.
- [ ] `tests/validate_sprite_extraction.py` — verifies those placeholder extractions.

## References/tests that need updating as part of approved deletion

- `scenes/player/player.tscn`: remove the swordsman fallback directory/anchor after retiring that fallback. Its initial texture already uses Chimchar.
- `scenes/enemies/test_enemy.tscn`: replace the skeleton initial texture and fallback configuration with Stunky.
- `scenes/enemies/minotaur.tscn`: replace the minotaur initial texture and fallback configuration with Drapion.
- `scripts/effects/character_visual.gd` and `scripts/effects/pokemon_character_visual.gd`: retire old-art loading while preserving shared animation signals, visibility, anchoring, ramp correction and completion/cancellation. Keep the reusable classes.
- `tests/round_test_helper.gd`: retire `use_placeholder_visuals`.
- `tests/validate_attack_leap.gd`, `tests/validate_character_sprites.gd`, `tests/validate_ramp_sprites.gd`, `tests/validate_pokemon_sprites.gd`: remove or replace old-art-specific expectations; retain native transform/ramp/lifecycle coverage.
- `tests/profile_pokemon_sprites.gd`: remove its old-art comparison, retaining native profiling.
- `AGENTS.md`, `docs/CODEX_HANDOFF.md`, `assets/sprites/pokemon/README.md`, `tests/README.md`: update current fallback/asset instructions and commands. Historical evidence should remain clearly labeled historical.

## Keep

- All Pokémon assets (Chimchar, Piplup, Turtwig, Stunky, Drapion), including original PNG/XML/offset/shadow files.
- `assets/audio/music/mtcoronet_midterm.mp3` and `.import` — active dungeon music.
- `assets/audio/music/pmd_bosstheme_midterm.mp3` and `.import` — active boss music.
- Existing reusable gameplay classes, scenes, native animation code and terrain assets. Internal Skeleton/Minotaur names do not require removing their gameplay systems.
- Local ignored archives and `.godot/` artifacts are outside this tracked-asset deletion proposal.

Deletion requires the user's review of this list. Approval should cover both the listed legacy files and the dependent fallback/test updates above, so the project does not retain broken references.
