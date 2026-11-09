extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")
const SPECIES = preload("res://config/species/stunky.tres")
const POLICY = preload("res://config/enemy_melee_attack_policy.tres")
const NAMES := ["chimchar", "piplup", "turtwig"]
const MOVE_DAMAGE := [6, 5, 2]
const BASIC_DAMAGE := [2, 1, 1]


func _initialize() -> void:
	call_deferred("validate")


func seed_for_move(use_move: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(1000):
		rng.seed = value
		if (rng.randf() < POLICY.move_probability) == use_move:
			return value
	assert(false, "No deterministic choice seed found")
	return 0


func validate_policy() -> void:
	assert(is_equal_approx(POLICY.move_probability, 0.95))
	assert(SPECIES.level == 10 and SPECIES.maximum_hp == 42)
	assert(SPECIES.attack == 21 and SPECIES.defense == 18 and SPECIES.special_attack == 20 and SPECIES.special_defense == 22)
	assert(SPECIES.starting_moves.size() == 1)
	assert(SPECIES.starting_moves[0].move_id == &"scratch" and SPECIES.starting_moves[0].maximum_pp == 28)
	var first := PokemonBattleState.new()
	var second := PokemonBattleState.new()
	first.reset(SPECIES)
	second.reset(SPECIES)
	var rng := RandomNumberGenerator.new()
	var reference := RandomNumberGenerator.new()
	rng.seed = 45093
	reference.seed = 45093
	var moves := 0
	# Independent full-PP trials; production never refills PP during combat.
	for trial in range(10000):
		first.remaining_pp[0] = 28
		var expected_move := reference.randf() < 0.95
		var chosen := POLICY.choose_and_spend(first, rng)
		assert((chosen != null) == expected_move and rng.state == reference.state)
		assert(first.remaining_pp[0] == (27 if expected_move else 28))
		if chosen != null: moves += 1
	assert(moves > 9400 and moves < 9600)
	assert(second.remaining_pp == [28] and SPECIES.starting_moves[0].maximum_pp == 28)
	print("Enemy policy seeded trials: ", moves, " Scratch / ", 10000 - moves, " basic")
	first.remaining_pp[0] = 1
	rng.seed = seed_for_move(true)
	assert(POLICY.choose_and_spend(first, rng) != null and first.remaining_pp == [0])
	var before := rng.state
	for attempt in range(5):
		assert(POLICY.choose_and_spend(first, rng) == null and first.remaining_pp == [0])
		assert(rng.state == before)
	# The same policy/state works for future bosses, without unlimited PP shortcuts.
	var boss := Minotaur.new()
	boss.battle_state.reset(SPECIES)
	boss.battle_state.remaining_pp[0] = 1
	rng.seed = seed_for_move(true)
	assert(POLICY.choose_and_spend(boss.battle_state, rng) != null)
	assert(POLICY.choose_and_spend(boss.battle_state, rng) == null)
	assert(boss.battle_state.remaining_pp == [0])
	boss.free()
	# Future actors may filter unsupported targeting without spending or rolling.
	first.reset(SPECIES)
	before = rng.state
	assert(POLICY.choose_and_spend(first, rng, func(_move: PokemonMoveData): return false) == null)
	assert(first.remaining_pp == [28] and rng.state == before)


func make_main(species: String, distant: bool) -> Node3D:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	main.get_node("Player").species_data = load("res://config/species/%s.tres" % species)
	main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % species)
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(6): data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i(3 if distant else 1, 0), Vector2i(5, 0)]
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.player.facing = Vector2i.UP # Empty basic attack advances exactly one round.
	main.refresh_fog()
	return main


func advance_round(main: Node3D) -> void:
	main.player.basic_attack()
	Helper.complete(main)
	assert(not main.resolving_turn)


func validate() -> void:
	validate_policy()
	for index in range(3):
		var main := make_main(NAMES[index], index == 0)
		var enemy: Skeleton = main.enemies[0]
		var other: Skeleton = main.enemies[1]
		var attacks: Array[StringName] = []
		enemy.attack_requested.connect(func(_damage: int):
			attacks.append(enemy.active_attack_move.move_id if enemy.active_attack_move != null else &"basic"))
		enemy.attack_rng.seed = seed_for_move(true)
		if index == 0:
			var before := enemy.attack_rng.state
			var other_before := other.attack_rng.state
			advance_round(main)
			assert(enemy.grid_position == Vector2i(2, 0) and attacks.is_empty())
			assert(enemy.attack_rng.state == before and other.attack_rng.state == other_before)
			advance_round(main)
			assert(enemy.grid_position == Vector2i(1, 0) and attacks.is_empty())
			assert(enemy.attack_rng.state == before and enemy.battle_state.remaining_pp == [28])
			assert(other.attack_rng.state == other_before and other.battle_state.remaining_pp == [28])
		var hp: int = main.player.health.current
		var starts: Array[int] = []
		main.enemy_action_started.connect(func(actor: Node3D): starts.append(actor.get_instance_id()))
		advance_round(main)
		assert(attacks == [&"scratch"] and main.player.health.current == hp - MOVE_DAMAGE[index])
		assert(starts.count(enemy.get_instance_id()) == 1)
		assert(starts.count(other.get_instance_id()) == 1)
		assert(enemy.battle_state.remaining_pp == [27] and other.battle_state.remaining_pp == [28])
		assert(enemy.active_attack_move == null and not enemy.attack_leap.active)
		# Force a deterministic roll in the 5% branch; Scratch PP stays unchanged.
		enemy.attack_rng.seed = seed_for_move(false)
		hp = main.player.health.current
		advance_round(main)
		assert(attacks.size() == 2 and attacks[-1] == &"basic")
		assert(main.player.health.current == hp - BASIC_DAMAGE[index] and enemy.battle_state.remaining_pp == [27])
		# Last PP is spent once; exhausted fallback neither rolls nor restores PP.
		enemy.battle_state.remaining_pp[0] = 1
		enemy.attack_rng.seed = seed_for_move(true)
		advance_round(main)
		assert(attacks[-1] == &"scratch" and enemy.battle_state.remaining_pp == [0])
		var before := enemy.attack_rng.state
		for attempt in range(3):
			hp = main.player.health.current
			var count := attacks.size()
			advance_round(main)
			assert(attacks.size() == count + 1 and attacks[-1] == &"basic")
			assert(main.player.health.current == hp - BASIC_DAMAGE[index])
			assert(enemy.battle_state.remaining_pp == [0] and enemy.attack_rng.state == before)
		assert(other.battle_state.remaining_pp == [28])
		assert(SPECIES.starting_moves[0].maximum_pp == 28)
		# Effective stats, not species constants, feed both calculator branches.
		var saved := enemy.battle_state.attack
		enemy.battle_state.attack += 12
		assert(PokemonDamage.move_damage(enemy.battle_state, main.player.battle_state, enemy.battle_state.moves[0]) > MOVE_DAMAGE[index])
		assert(PokemonDamage.basic_damage(enemy.battle_state, main.player.battle_state) > BASIC_DAMAGE[index])
		enemy.battle_state.attack = saved
		# Overlap and death cannot roll.
		before = enemy.attack_rng.state
		enemy.take_turn(enemy.grid_position, main.enemy_occupancy)
		assert(enemy.attack_rng.state == before)
		enemy.health.damage(enemy.health.current)
		enemy.take_turn(main.player.grid_position, main.enemy_occupancy)
		assert(enemy.attack_rng.state == before)
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(main.enemies[0].level == 10 and main.enemies[0].battle_state.remaining_pp == [28])
		main.free()
		await process_frame
	# Explicitly blocked pursuit has no attack selection.
	var main := make_main("chimchar", true)
	var enemy: Skeleton = main.enemies[0]
	var before := enemy.attack_rng.state
	enemy.take_turn(Vector2i.ZERO, {Vector2i(2, 0): true})
	assert(enemy.grid_position == Vector2i(3, 0) and enemy.attack_rng.state == before)
	assert(enemy.battle_state.remaining_pp == [28])
	main.free()
	await process_frame
	print("PASS: level10 Stunky stats, exact shared damage, 95/5 attack-only RNG, independent PP/exhaustion, single-action turns and reusable boss policy")
	quit()
