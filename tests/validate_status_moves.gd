extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
const NAMES := ["chimchar", "piplup", "turtwig"]
const STATUS := [&"leer", &"growl", &"withdraw"]
const PPS := [27, 20, 16]

func _initialize() -> void:
	call_deferred("validate")

func unit_stages() -> void:
	var state := PokemonBattleState.new()
	state.reset(load("res://config/species/stunky.tres"))
	var changes := [0]
	state.stage_changed.connect(func(_stat, _amount): changes[0] += 1)
	for stat in PokemonBattleState.STATS:
		var base: int = state.get(stat)
		var table := PokemonBattleState.OFFENSIVE_STAGES if stat in [&"attack", &"special_attack"] else PokemonBattleState.DEFENSIVE_STAGES
		for stage in range(-10, 11):
			state.change_stage(stat, stage - state.get_stage(stat))
			assert(state.get_stage(stat) == stage)
			assert(state.get_effective_stat(stat) == floorf(base * float(table[stage + 10]) / 256.0))
			assert(state.get(stat) == base)
		state.change_stage(stat, 999)
		var before: int = changes[0]
		assert(state.change_stage(stat, 1) == 0 and changes[0] == before)
		state.change_stage(stat, -999)
		assert(state.get_stage(stat) == -10 and state.change_stage(stat, -1) == 0)
	state.reset_stages()
	assert(state.change_stage(&"defense", -1) == -1 and state.get_effective_stat(&"defense") == 12)
	assert(state.change_stage(&"attack", -1) == -1 and state.get_effective_stat(&"attack") == 16)
	var player := PokemonBattleState.new()
	player.reset(load("res://config/species/turtwig.tres"))
	player.change_stage(&"defense", 1)
	assert(player.get_effective_stat(&"defense") == 53 and player.defense == 41)
	player.reset_stages()
	var neutral := PokemonBattleState.new()
	neutral.reset(state.species)
	assert(PokemonDamage.basic_damage(state, player) < PokemonDamage.basic_damage(neutral, player))
	assert(PokemonDamage.move_damage(state, player, state.moves[0]) < PokemonDamage.move_damage(neutral, player, neutral.moves[0]))
	var physical := player.moves[0]
	assert(PokemonDamage.move_damage(player, state, physical) > PokemonDamage.move_damage(player, neutral, physical))
	assert(PokemonDamage.basic_damage(player, state) > PokemonDamage.basic_damage(player, neutral))
	var special := physical.duplicate() as PokemonMoveData
	special.category = PokemonMoveData.Category.SPECIAL
	var baseline := PokemonDamage.move_damage(player, neutral, special)
	player.change_stage(&"special_attack", 2)
	assert(PokemonDamage.move_damage(player, neutral, special) > baseline)
	neutral.change_stage(&"special_defense", 3)
	assert(PokemonDamage.move_damage(player, neutral, special) < baseline)
	assert(state.species.attack == 21 and state.species.defense == 18 and neutral.get_stage(&"attack") == 0)

func make_main(index: int) -> Node3D:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	main.get_node("Player").species_data = load("res://config/species/%s.tres" % NAMES[index])
	main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % NAMES[index])
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	data.rooms = [Rect2i(0, 0, 5, 5), Rect2i(10, 0, 3, 3)]
	for room in data.rooms:
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y): data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	for x in range(5, 10): data.set_tile(Vector2i(x, 2), DungeonData.TileType.CORRIDOR)
	data.player_spawn = Vector2i(2, 2)
	data.enemy_spawns = [Vector2i(3, 2), Vector2i(3, 3), Vector2i(11, 1)]
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data, true))
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.player.facing = Vector2i.RIGHT
	main.player.invincible = true
	main.refresh_fog()
	return main

func indicators(actor: Node3D) -> Array[StatChangeEffect]:
	var result: Array[StatChangeEffect] = []
	for child in actor.get_children():
		if child is StatChangeEffect: result.append(child)
	return result

func press_i(player: Player) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_I
	key.pressed = true
	player._unhandled_input(key)

func validate() -> void:
	unit_stages()
	for index in range(3):
		var main := make_main(index)
		var player: Player = main.player
		var enemy: Skeleton = main.enemies[0]
		var other: Skeleton = main.enemies[1]
		var outside: Skeleton = main.enemies[2]
		var rounds := [0]
		main.round_finished.connect(func(): rounds[0] += 1)
		assert(player.battle_state.moves[1].move_id == STATUS[index])
		assert(main.hud.move_panel.moves[1].category == "Status" and main.hud.move_panel.moves[1].damage_text == "No direct damage")
		var initial_pp: int = player.battle_state.remaining_pp[0]
		press_i(player)
		var expected_clip := "Withdraw" if index == 2 else "Shoot"
		assert(player.character_visual.clip == expected_clip)
		assert(player.character_visual.attack_action == player.battle_state.moves[1].animation_action)
		assert(is_equal_approx(player.attack_leap.duration, player.character_visual.clips[expected_clip].total))
		assert(player.battle_state.remaining_pp == [initial_pp, PPS[index] - 1])
		var affected: Array[Node3D] = []
		affected.assign([player] if index == 2 else ([enemy, other] if index == 1 else [enemy]))
		for actor in affected:
			var effects := indicators(actor)
			assert(effects.size() == 1)
			var effect := effects[0]
			effect.animation.pause()
			assert(effect.global_position.y > actor.global_position.y)
			var color := effect.arrow.texture.get_image().get_pixel(12, 16)
			assert(color.g > color.r if index == 2 else color.r > color.g)
		assert(indicators(outside).is_empty())
		if index == 0:
			assert(enemy.battle_state.get_effective_stat(&"defense") == 12 and other.battle_state.get_stage(&"defense") == 0)
		elif index == 1:
			assert(enemy.battle_state.get_effective_stat(&"attack") == 16 and other.battle_state.get_effective_stat(&"attack") == 16)
			assert(outside.battle_state.get_stage(&"attack") == 0)
		else:
			assert(player.battle_state.get_effective_stat(&"defense") == 53)
		Helper.complete(main)
		assert(rounds[0] == 1 and not main.resolving_turn)
		for actor in main.enemies: assert(actor.health.current == 42)
		# No expiry, and capped moves still spend PP/a turn without another arrow.
		var move := player.battle_state.moves[1]
		for actor in affected: actor.battle_state.change_stage(move.affected_stat, 999 if index == 2 else -999)
		var counts: Array[int] = []
		for actor in affected: counts.append(indicators(actor).size())
		press_i(player)
		Helper.complete(main)
		assert(rounds[0] == 2 and player.battle_state.remaining_pp[1] == PPS[index] - 2)
		for i in range(affected.size()): assert(indicators(affected[i]).size() == counts[i])
		player.battle_state.remaining_pp[1] = 0
		press_i(player)
		assert(rounds[0] == 2 and not player.attack_leap.active)
		player.battle_state.remaining_pp[1] = 1
		player.transition_locked = true
		assert(not player.use_move(1) and player.battle_state.remaining_pp[1] == 1)
		player.transition_locked = false
		# Missing targets are valid executions; Growl never treats all corridors as a room.
		player.setup(Vector2i(7, 2), main.dungeon, main.dungeon_renderer)
		player.facing = Vector2i.UP
		var stages := enemy.battle_state.stat_stages.duplicate()
		assert(player.use_move(1))
		Helper.complete(main)
		assert(player.battle_state.remaining_pp[1] == 0 and enemy.battle_state.stat_stages == stages)
		# Actual floor replacement resets stages while preserving HP and both PP pools.
		player.battle_state.change_stage(&"special_attack", 2)
		var pp := player.battle_state.remaining_pp.duplicate()
		var hp := player.health.current
		main.game_mode = GameModeConfig.Mode.DEMO
		main.use_elevation_test = false
		main._on_stairs_reached()
		Helper.complete_introduction(main)
		assert(player.battle_state.stat_stages.is_empty() and player.battle_state.remaining_pp == pp and player.health.current == hp)
		assert(main.enemies[0].battle_state.stat_stages.is_empty())
		main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
		main.load_test_floor()
		var boss: Minotaur = main.boss
		boss.battle_state.change_stage(&"attack", -1)
		assert(indicators(boss).size() == 1)
		boss.show_charge()
		assert(indicators(boss).size() == 2 and boss.battle_state.get_stage(&"attack") == -1)
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(player.battle_state.stat_stages.is_empty() and player.battle_state.remaining_pp == [initial_pp, PPS[index]])
		main.free()
		await process_frame
	print("PASS: exact EoS stage tables/floor/clamps/isolation/damage, I status PP/one-turn targets, room/corridor/self/misses, caps, arrows/boss and floor/fresh reset")
	quit()
