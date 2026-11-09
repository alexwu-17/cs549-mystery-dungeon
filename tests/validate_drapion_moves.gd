extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
const SPECIES = preload("res://config/species/drapion.tres")
const POLICY = preload("res://config/boss_attack_policy.tres")
const NAMES := ["chimchar", "piplup", "turtwig"]
const BASICS := [19, 18, 17]
const X_DAMAGE := [61, 60, 57]
const PLAYER_DAMAGE := [22, 22, 24]

func _initialize() -> void:
	call_deferred("validate")

func seed_for_move(use_move: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(1000):
		rng.seed = value
		if (rng.randf() < 0.95) == use_move: return value
	assert(false)
	return 0

func make_main(index: int = 0) -> Node3D:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	main.get_node("Player").species_data = load("res://config/species/%s.tres" % NAMES[index])
	main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % NAMES[index])
	root.add_child(main)
	Helper.complete_introduction(main)
	main.use_elevation_test = false
	main.game_mode = GameModeConfig.Mode.DEMO
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	return main

func restore_boss(main: Node3D) -> void:
	var boss: Minotaur = main.boss
	boss.character_visual.finish()
	boss.clear_charge()
	boss.state = Minotaur.State.HUNTING
	boss.setup(DemoArenaFactory.BOSS_CENTER, main.dungeon, main.dungeon_renderer)
	main.player.health.reset(main.player.maximum_hp)

func validate_policy() -> void:
	assert(SPECIES.level == 30 and SPECIES.maximum_hp == 92)
	assert(SPECIES.attack == 50 and SPECIES.defense == 43 and SPECIES.special_attack == 47 and SPECIES.special_defense == 43)
	var configured_types: PackedStringArray = SPECIES.get("types")
	assert(configured_types == PackedStringArray(["Poison", "Dark"]))
	var state := PokemonBattleState.new()
	state.reset(SPECIES)
	assert(state.remaining_pp == [10])
	var move := state.moves[0]
	assert(move.move_id == &"x_scissor" and move.move_type == "Bug" and move.category == PokemonMoveData.Category.PHYSICAL and move.power == 40 and move.range_tiles == 2)
	assert(move.targeting == PokemonMoveData.Targeting.FORWARD_LANE and is_equal_approx(POLICY.move_probability, 0.95))
	var rng := RandomNumberGenerator.new()
	var reference := RandomNumberGenerator.new()
	rng.seed = 45093
	reference.seed = 45093
	var chosen := 0
	for index in range(10000):
		var expected := reference.randf() < 0.95
		var slot := POLICY.choose_slot(state, rng)
		assert((slot == 0) == expected and rng.state == reference.state and state.remaining_pp == [10])
		if slot == 0: chosen += 1
	assert(chosen > 9400 and chosen < 9600)
	print("DRAPION SELECTION: ", chosen, "/10000 X-Scissor")
	for index in range(3):
		var player := PokemonBattleState.new()
		player.reset(load("res://config/species/%s.tres" % NAMES[index]))
		var basic := PokemonDamage.basic_damage(state, player)
		var damage := PokemonDamage.move_damage(state, player, move)
		var incoming := PokemonDamage.move_damage(player, state, player.moves[0])
		print("BALANCE ", NAMES[index], " basic=", basic, " X=", damage, " incoming=", incoming, " hits=", ceili(92.0 / incoming))
		assert(basic == BASICS[index] and damage == X_DAMAGE[index] and incoming == PLAYER_DAMAGE[index])
		assert(damage == PokemonDamage.modified_damage(PokemonDamage.raw_damage(state, player, move.category, 40))) # No STAB.
		state.change_stage(&"attack", -1)
		assert(PokemonDamage.basic_damage(state, player) < basic and PokemonDamage.move_damage(state, player, move) < damage)
		state.reset_stages()
		state.change_stage(&"defense", -1)
		assert(PokemonDamage.move_damage(player, state, player.moves[0]) > incoming)
		state.reset_stages()
	# The selector supports multiple slots without sharing or pre-spending PP.
	var copy := SPECIES.duplicate() as PokemonSpeciesData
	copy.starting_moves = [move, move]
	state.reset(copy)
	var selected := {}
	for index in range(100):
		var slot := POLICY.choose_slot(state, rng)
		if slot >= 0: selected[slot] = true
	assert(selected.size() == 2 and state.remaining_pp == [10, 10] and SPECIES.starting_moves.size() == 1)

func validate() -> void:
	validate_policy()
	for index in range(3):
		var main := make_main(index)
		var boss: Minotaur = main.boss
		assert(boss.health.current == 92 and boss.level == 30 and boss.battle_state.remaining_pp == [10])
		# Pursuit never selects, spends or changes the original movement rule.
		var before := boss.attack_rng.state
		boss.take_turn(main.player.grid_position)
		assert(boss.attack_rng.state == before and boss.battle_state.remaining_pp == [10])
		restore_boss(main)
		for direction: Vector2i in DungeonData.CARDINALS:
			for depth in [1, 2]:
				restore_boss(main)
				var target: Vector2i = boss.grid_position + direction * depth
				main.player.setup(target, main.dungeon, main.dungeon_renderer)
				boss.attack_rng.seed = seed_for_move(true)
				boss.take_turn(target)
				assert(boss.state == Minotaur.State.CHARGING and boss.markers.size() == 2 and boss.committed_move_slot == 0)
				assert(boss.battle_state.remaining_pp == [10] and main.player.health.current == main.player.maximum_hp)
				assert(boss.facing == direction and boss.character_visual.clip == "Charge")
				var frozen := boss.threatened_tiles.duplicate()
				before = boss.attack_rng.state
				boss.take_turn(target)
				assert(boss.state == Minotaur.State.COOLDOWN and boss.battle_state.remaining_pp == [9])
				assert(boss.attack_rng.state == before and boss.markers.is_empty() and boss.threatened_tiles.is_empty())
				assert(main.player.health.current == main.player.maximum_hp - X_DAMAGE[index])
				assert(boss.active_attack_move.move_id == &"x_scissor" and boss.character_visual.clip == "Strike")
				boss.character_visual.finish()
				boss.take_turn(target)
				assert(boss.state == Minotaur.State.HUNTING and boss.attack_rng.state == before and boss.battle_state.remaining_pp == [9])
				assert(boss.character_visual.clip == "Idle" and frozen.size() == 2)
				# The same two cells support immediate, PP-free basics without recharge.
				restore_boss(main)
				main.player.setup(target, main.dungeon, main.dungeon_renderer)
				boss.attack_rng.seed = seed_for_move(false)
				boss.take_turn(target)
				assert(boss.state == Minotaur.State.HUNTING and boss.markers.is_empty() and boss.active_attack_move == null)
				assert(boss.character_visual.clip == "Strike" and boss.battle_state.remaining_pp == [10])
				assert(main.player.health.current == main.player.maximum_hp - BASICS[index])
		# Exhaust all ten executions by dodging: charge spends nothing, misses always recharge.
		restore_boss(main)
		var target := boss.grid_position + Vector2i.DOWN
		main.player.setup(target, main.dungeon, main.dungeon_renderer)
		for use in range(10):
			boss.attack_rng.seed = seed_for_move(true)
			boss.take_turn(target)
			assert(boss.battle_state.remaining_pp == [10 - use])
			before = boss.attack_rng.state
			boss.take_turn(boss.grid_position + Vector2i.LEFT)
			assert(boss.state == Minotaur.State.COOLDOWN and boss.battle_state.remaining_pp == [9 - use])
			assert(boss.attack_rng.state == before and main.player.health.current == main.player.maximum_hp)
			assert(main.dialogue.history[-1].type == &"charge_miss")
			boss.character_visual.finish()
			boss.take_turn(target)
			assert(boss.state == Minotaur.State.HUNTING and boss.attack_rng.state == before)
		before = boss.attack_rng.state
		for use in range(3):
			main.player.health.reset(main.player.maximum_hp)
			boss.take_turn(target)
			assert(boss.state == Minotaur.State.HUNTING and boss.battle_state.remaining_pp == [0] and boss.attack_rng.state == before)
			boss.character_visual.finish()
		# Death during charge interrupts without spending PP.
		restore_boss(main)
		boss.attack_rng.seed = seed_for_move(true)
		boss.take_turn(target)
		boss.receive_damage(999)
		assert(main.victory and boss.battle_state.remaining_pp == [10] and boss.committed_move_slot == -1)
		Helper.complete(main)
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(not main.victory and main.boss == null)
		main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
		main.load_test_floor()
		assert(main.boss.health.current == 92 and main.boss.battle_state.remaining_pp == [10])
		main.free()
		await process_frame
	# Full production battle: U -> charge, dodge -> execution, return -> recharge.
	var main := make_main()
	var boss: Minotaur = main.boss
	boss.attack_policy = boss.attack_policy.duplicate()
	boss.attack_policy.move_probability = 1.0
	main.player.setup(boss.grid_position + Vector2i.DOWN, main.dungeon, main.dungeon_renderer)
	for hit in range(5):
		main.player.facing = Vector2i.UP
		assert(main.player.use_move(0))
		Helper.complete(main)
		if hit == 4: break
		assert(boss.state == Minotaur.State.CHARGING and boss.battle_state.remaining_pp == [10 - hit])
		main.player.try_move(Vector2i.RIGHT)
		Helper.complete(main)
		assert(boss.state == Minotaur.State.COOLDOWN and not main.game_over)
		main.player.try_move(Vector2i.LEFT)
		Helper.complete(main)
		assert(boss.state == Minotaur.State.HUNTING)
	assert(main.victory and boss.health.current == 0 and main.player.health.current == 76)
	assert(main.hud.get_node("Screen/GameOver").visible and boss.battle_state.remaining_pp == [6])
	main.free()
	await process_frame
	print("PASS: Drapion authored stats/shared damage, 95/5 attack-only selection, unchanged charged lanes/recharge, immediate basics, hit/miss PP/exhaustion, stages and full dodge/victory/reset")
	quit()
