# Character sprite presentation

All live actors and fallback visuals use native Pokemon artwork:
player -> Chimchar, regular enemy -> Stunky, boss -> Drapion. Starter selection
can override the player profile with Piplup or Turtwig. Each shared scene has
its native Idle atlas as the initial texture and an explicit role-default
`fallback_profile`. Missing/invalid custom profiles recover to that default.

`PokemonSpriteLibrary` reads the preserved original XML/PNG/offset metadata;
`pokemon_character_visual.gd` selects native cardinal frames and timing.
`CharacterVisual` keeps shared anchoring, visibility and action/cancellation
contracts, but no longer loads old sprite directories. `AttackLeap` owns
presentation transforms independently of damage and grid occupancy.

The reviewed skeleton/swordsman/minotaur art, original placeholder sheets,
extraction manifest/tool/test and unused placeholder songs were retired.
All Pokemon source artwork and active dungeon/boss/selection music remain.
Do not run the retired extraction commands from historical checkpoint notes.

`validate_pokemon_sprites` checks configured and missing/invalid role-default
profiles for all three roles, native rows/timing/anchoring and clip fallback.
`validate_ramp_sprites` checks both configured/default native ramp poses.
Generic procedural leap and frame-sequence tests use static Pokemon atlas
fixtures via `use_static_test_visuals`; these do not change production defaults.
Native boss Charge/Strike and gameplay lifecycle have their own focused checks.
See `tests/README.md` and `docs/CODEX_HANDOFF.md` for commands/results.
