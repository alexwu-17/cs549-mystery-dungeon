extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")
const NAMES := ["chimchar", "piplup", "turtwig"]
const MOVES := [&"scratch", &"pound", &"tackle"]
const PP := [28, 27, 30]
const STATUS_PP := [27, 20, 16]
const BASIC_DAMAGE := [17, 17, 18]
const MOVE_DAMAGE := [36, 37, 39]

class EffectiveState extends PokemonBattleState:
	var offense_scale := 1.0
	var defense_scale := 1.0
	func get_effective_stat(stat: StringName) -> float:
		var value := super.get_effective_stat(stat)
		return value * (offense_scale if stat in [&"attack", &"special_attack"] else defense_scale)


func _initialize() -> void:
	call_deferred("validate")


func state(name: String) -> PokemonBattleState:
	var result := PokemonBattleState.new()
	result.reset(load("res://config/species/%s.tres" % name))
	return result


func validate_damage() -> void:
	var defender := state("stunky")
	assert(defender.health.maximum == 42 and defender.attack == 21 and defender.defense == 18)
	for index in range(3):
		var attacker := state(NAMES[index])
		var move := attacker.moves[0]
		assert(move.move_id == MOVES[index] and move.maximum_pp == PP[index])
		assert(move.power == 6 and move.move_type == "Normal" and move.category == PokemonMoveData.Category.PHYSICAL)
		assert(move.targeting == PokemonMoveData.Targeting.ADJACENT and move.range_tiles == 1)
		assert(PokemonDamage.basic_damage(attacker, defender) == BASIC_DAMAGE[index])
		assert(PokemonDamage.move_damage(attacker, defender, move) == MOVE_DAMAGE[index])
		assert(ceili(42.0 / BASIC_DAMAGE[index]) == 3 and ceili(42.0 / MOVE_DAMAGE[index]) == 2)
		assert(PokemonDamage.basic_damage(defender, attacker) == [2, 1, 1][index])
		var other := state(NAMES[index])
		assert(attacker.spend_pp(0))
		assert(attacker.remaining_pp == [PP[index] - 1, STATUS_PP[index]] and other.remaining_pp == [PP[index], STATUS_PP[index]])
		assert(move.maximum_pp == PP[index])
	var attacker := state("chimchar")
	var move := attacker.moves[0].duplicate() as PokemonMoveData
	assert(PokemonDamage.move_damage(attacker, defender, move, 2.0) == 73) # Round once, not 36*2.
	assert(PokemonDamage.move_damage(attacker, defender, move, 0.0) == 0)
	# Test STAB explicitly without changing or assuming editable species type data.
	attacker.species = attacker.species.duplicate()
	attacker.species.types = PackedStringArray(["Fire"])
	move.move_type = "Fire"
	assert(PokemonDamage.move_damage(attacker, defender, move) == 54) # STAB 1.5.
	assert(PokemonDamage.basic_damage(attacker, defender) == 17) # Basic has no STAB.
	move.move_type = "Normal"
	attacker.attack += 8
	assert(PokemonDamage.move_damage(attacker, defender, move) > 36)
	attacker.reset(attacker.species)
	attacker.level += 10
	assert(PokemonDamage.move_damage(attacker, defender, move) > 36)
	attacker.reset(attacker.species)
	move.power += 5
	assert(PokemonDamage.move_damage(attacker, defender, move) > 36)
	move.power = 6
	defender.defense += 8
	assert(PokemonDamage.move_damage(attacker, defender, move) < 36)
	defender.reset(defender.species)
	move.category = PokemonMoveData.Category.SPECIAL
	var special := PokemonDamage.move_damage(attacker, defender, move)
	attacker.attack = 999
	defender.defense = 999
	assert(PokemonDamage.move_damage(attacker, defender, move) == special)
	move.targeting = PokemonMoveData.Targeting.STRAIGHT_PROJECTILE
	move.range_tiles = 4
	assert(PokemonDamage.move_damage(attacker, defender, move) == special)
	attacker.special_attack += 8
	assert(PokemonDamage.move_damage(attacker, defender, move) > special)
	attacker.reset(attacker.species)
	defender.special_defense += 8
	assert(PokemonDamage.move_damage(attacker, defender, move) < special)
	# Prove both action kinds consult the effective-stat hook, without stage code.
	var effective := EffectiveState.new()
	effective.reset(attacker.species)
	defender.reset(defender.species)
	move.category = PokemonMoveData.Category.PHYSICAL
	effective.offense_scale = 0.5
	assert(PokemonDamage.move_damage(effective, defender, move) < 36)
	assert(PokemonDamage.basic_damage(effective, defender) < 17)
	defender.defense = 1000000
	assert(PokemonDamage.move_damage(attacker, defender, move) == 1)
	assert(PokemonDamage.basic_damage(attacker, defender) == 1)
	var legacy := PokemonBattleState.new()
	legacy.reset(null, 30, 5)
	assert(PokemonDamage.basic_damage(legacy, attacker, 18) == 18)
	# Capacity is four; resource objects are shared but PP storage is actor-owned.
	var species := attacker.species.duplicate() as PokemonSpeciesData
	species.starting_moves = [move, move, move, move, move]
	legacy.reset(species)
	assert(legacy.moves.size() == 4 and legacy.remaining_pp.size() == 4)


func duel(main: Node3D, direction: Vector2i = Vector2i.RIGHT, ramp: bool = false) -> Skeleton:
	main.cancel_round()
	var data := DungeonData.new()
	if ramp:
		data.add_ramp(Vector2i.ZERO, Vector2i.RIGHT, 0)
		data.player_spawn = Vector2i(2, 0)
	else:
		data.set_tile(Vector2i.ZERO, DungeonData.TileType.FLOOR)
		data.set_tile(direction, DungeonData.TileType.FLOOR)
		data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [data.player_spawn + direction]
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	# This fixture owns player moves; enemy selection is covered separately.
	main.enemies[0].attack_policy = main.enemies[0].attack_policy.duplicate()
	main.enemies[0].attack_policy.move_probability = 0.0
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.player.facing = direction
	main.refresh_fog()
	return main.enemies[0]


func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func validate() -> void:
	validate_damage()
	for index in range(3):
		var main = load("res://scenes/main/main.tscn").instantiate()
		main.use_elevation_test = true
		main.get_node("Player").species_data = load("res://config/species/%s.tres" % NAMES[index])
		main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % NAMES[index])
		root.add_child(main)
		Helper.complete_introduction(main)
		var player: Player = main.player
		var rounds: Array[int] = [0]
		main.round_finished.connect(func(): rounds[0] += 1)
		var enemy := duel(main)
		var hp := player.health.current
		player._unhandled_input(key(KEY_U))
		assert(player.character_visual.clip == ("Strike" if index == 0 else "Attack"))
		assert(is_equal_approx(player.attack_leap.duration, player.character_visual.clips[player.character_visual.clip].total))
		assert(player.battle_state.remaining_pp == [PP[index] - 1, STATUS_PP[index]])
		assert(enemy.health.current == 42 - MOVE_DAMAGE[index])
		assert(main.hud.move_panel.moves[0].current_pp == PP[index] - 1)
		assert(main.hud.move_panel.moves.size() == 2 and main.hud.move_panel.rows.size() == 4)
		assert(player.attack_leap.active and main.resolving_turn and player.round_locked)
		player._unhandled_input(key(KEY_U)) # Locked presentation cannot double-spend.
		assert(player.battle_state.remaining_pp == [PP[index] - 1, STATUS_PP[index]])
		Helper.complete(main)
		assert(rounds[0] == 1 and player.health.current == hp - [2, 1, 1][index])
		var echo := key(KEY_U)
		echo.echo = true
		player._unhandled_input(echo)
		echo.echo = false
		echo.pressed = false
		player._unhandled_input(echo)
		for code in [KEY_O, KEY_P]: player._unhandled_input(key(code))
		assert(rounds[0] == 1 and not main.resolving_turn and not player.attack_leap.active)
		assert(player.battle_state.remaining_pp == [PP[index] - 1, STATUS_PP[index]])
		# The second move kills once, removes occupancy, heals normally and spends PP.
		player._unhandled_input(key(KEY_U))
		Helper.complete(main)
		assert(main.enemies.is_empty() and main.enemy_occupancy.is_empty() and rounds[0] == 2)
		assert(player.battle_state.remaining_pp == [PP[index] - 2, STATUS_PP[index]])
		for direction in DungeonData.CARDINALS:
			enemy = duel(main, direction)
			var before := player.battle_state.remaining_pp[0]
			assert(player.use_move(0))
			assert(enemy.health.current == 42 - MOVE_DAMAGE[index])
			var visual = player.character_visual
			var expected_clip := "Strike" if index == 0 else "Attack"
			assert(visual.clip == expected_clip and visual.action == "Attack")
			var info: Dictionary = visual.clips[expected_clip]
			player.attack_leap.animation.pause()
			var time := 0.0
			for frame in range(info.durations.size()):
				player.attack_leap._sample((time + 0.000001) / player.attack_leap.duration)
				assert(visual.sprite.texture == info.rows[visual.row()][frame].texture)
				time += float(info.durations[frame])
			Helper.complete(main)
			assert(player.battle_state.remaining_pp[0] == before - 1)
			# The very next Space must use the original Attack, not the move override.
			player.basic_attack()
			assert(visual.clip == "Attack" and is_equal_approx(player.attack_leap.duration, visual.clips.Attack.total))
			Helper.complete(main)
			assert(player.battle_state.remaining_pp[0] == before - 1)
		# A wall/missing tile still spends one PP and one turn, without damage.
		enemy = duel(main)
		player.facing = Vector2i.UP
		var before := player.battle_state.remaining_pp[0]
		var before_rounds := rounds[0]
		assert(player.use_move(0))
		Helper.complete(main)
		assert(enemy.health.current == 42 and rounds[0] == before_rounds + 1)
		assert(player.battle_state.remaining_pp[0] == before - 1)
		# Last PP can be spent, but zero PP and locks reject without a turn/animation.
		enemy = duel(main)
		player.battle_state.remaining_pp[0] = 1
		assert(player.use_move(0))
		Helper.complete(main)
		before_rounds = rounds[0]
		assert(player.battle_state.remaining_pp == [0, STATUS_PP[index]])
		assert(not player.use_move(0) and not player.battle_state.spend_pp(0))
		var untouched := enemy.health.current
		player._unhandled_input(key(KEY_U))
		assert(enemy.health.current == untouched and main.hud.move_panel.moves[0].current_pp == 0)
		assert(not player.attack_leap.active and rounds[0] == before_rounds)
		enemy = duel(main)
		player._unhandled_input(key(KEY_SPACE))
		Helper.complete(main)
		assert(player.battle_state.remaining_pp == [0, STATUS_PP[index]] and enemy.health.current == 42 - BASIC_DAMAGE[index])
		player.reset_battle_state()
		for guard in ["loading_floor", "game_over", "victory"]:
			main.set(guard, true)
			assert(not player.use_move(0))
			main.set(guard, false)
		for guard in ["transition_locked", "round_locked"]:
			player.set(guard, true)
			assert(not player.use_move(0))
			player.set(guard, false)
		assert(player.battle_state.remaining_pp == [PP[index], STATUS_PP[index]])
		if index == 0:
			var visual = player.character_visual
			var cached: Dictionary = visual.clips
			visual.clips = cached.duplicate()
			visual.clips.erase("Strike")
			assert(player.use_move(0) and visual.clip == "Attack")
			Helper.complete(main)
			visual.clips = cached
		# The same U path follows ramp traversal and source attack completion.
		enemy = duel(main, Vector2i.RIGHT, true)
		assert(player.use_move(0) and player.attack_leap.ramp_path)
		assert(player.character_visual.clip == ("Strike" if index == 0 else "Attack"))
		assert(is_equal_approx(player.attack_leap.duration, player.character_visual.clips[player.character_visual.clip].total))
		assert(enemy.health.current == 42 - MOVE_DAMAGE[index])
		Helper.complete(main)
		# Floor changes cancel outgoing rounds but keep PP; fresh runs restore it.
		enemy = duel(main)
		assert(player.use_move(0))
		var carried: Array[int] = player.battle_state.remaining_pp.duplicate()
		main._on_stairs_reached()
		Helper.complete_introduction(main)
		assert(main.floor_number == 2 and player.battle_state.remaining_pp == carried)
		assert(not main.resolving_turn and not player.transition_locked)
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(player.battle_state.remaining_pp == [PP[index], STATUS_PP[index]])
		enemy = duel(main)
		assert(player.use_move(0))
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(player.battle_state.remaining_pp == [PP[index], STATUS_PP[index]] and not main.resolving_turn)
		enemy = duel(main)
		assert(player.use_move(0))
		player.receive_damage(player.health.current)
		assert(main.game_over and not player.use_move(0))
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(not main.game_over and player.battle_state.remaining_pp == [PP[index], STATUS_PP[index]])
		if index == 0:
			# A lethal U move must use the existing delayed boss victory/cancel path.
			main.game_mode = GameModeConfig.Mode.DEMO
			main.use_elevation_test = false
			for restart_during_defeat in [true, false]:
				main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
				main.load_test_floor()
				player.setup(main.boss.grid_position - Vector2i.RIGHT, main.dungeon, main.dungeon_renderer)
				player.facing = Vector2i.RIGHT
				main.boss.health.reset(1) # Presentation/cancellation fixture, not boss balance.
				assert(player.use_move(0) and main.victory and main.boss.health.current == 0)
				assert(not main.hud.get_node("Screen/GameOver").visible)
				if restart_during_defeat:
					main.start_new_run()
					Helper.complete_introduction(main)
					assert(not main.victory and not main.hud.get_node("Screen/GameOver").visible)
					assert(player.battle_state.remaining_pp == [PP[index], STATUS_PP[index]])
				else:
					Helper.complete(main)
					assert(main.victory and main.hud.get_node("Screen/GameOver").visible)
		main.free()
		await process_frame
	print("PASS: logarithmic shared damage, effective stats/STAB/modifiers, all starters U/Space, PP, guards, cardinal/ramp hits, turns, floor/restart/death cancellation and HUD")
	quit()
