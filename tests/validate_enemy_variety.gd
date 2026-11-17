extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")
const NAMES := ["glameow", "mankey", "psyduck", "tangela", "vulpix"]
const MOVE_IDS := [&"scratch", &"scratch", &"bubble", &"razor_leaf", &"ember"]
const CLIPS := ["Attack", "MultiStrike", "Shoot", "Shoot", "Shoot"]

func _initialize() -> void:
	call_deferred("validate")

func choice_seed(probability: float, use_move: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(1000):
		rng.seed = value
		if (rng.randf() < probability) == use_move: return value
	assert(false)
	return 0

func make_main(name: String, tile: Vector2i) -> Node3D:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(7):
		for y in range(3): data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	main.player.health.reset(1000)
	var enemy: Skeleton = load("res://scenes/enemies/%s.tscn" % name).instantiate()
	main.entities.add_child(enemy)
	enemy.setup(tile, data, main.dungeon_renderer)
	enemy.attack_requested.connect(main._on_enemy_attack.bind(enemy))
	main.enemies.append(enemy)
	main.enemy_occupancy[tile] = enemy
	main.refresh_fog()
	return main

func validate() -> void:
	for index in range(NAMES.size()):
		var ranged := index >= 2
		var main := make_main(NAMES[index], Vector2i(3 if ranged else 1, 0))
		var enemy: Skeleton = main.enemies[0]
		var visual = enemy.character_visual
		assert(enemy.level == 10 and enemy.battle_state.moves.size() == 1)
		var move := enemy.battle_state.moves[0]
		assert(move.move_id == MOVE_IDS[index])
		assert(visual.profile.display_name.to_lower() == NAMES[index])
		for action in ["Idle", "Walk", "Hurt", "Attack"]:
			assert(visual.profile.animations[action] == action and visual.clips.has(action))
		assert(visual.profile.animations[str(move.animation_action)] == CLIPS[index])
		assert(visual.clips.has(CLIPS[index]))
		assert(is_equal_approx(enemy.attack_policy.move_probability, 0.25 if ranged else 0.95))
		var hp: int = main.player.health.current
		var pp := enemy.battle_state.remaining_pp[0]
		enemy.attack_rng.seed = choice_seed(enemy.attack_policy.move_probability, true)
		main.player.basic_attack()
		Helper._complete_leap(main.player.attack_leap)
		assert(main.resolving_turn and enemy.active_attack_move == move)
		assert(visual.clip == CLIPS[index])
		assert(enemy.battle_state.remaining_pp[0] == pp - 1)
		assert(main.player.health.current == hp) # No pre-contact/pre-arrival damage.
		if ranged:
			Helper._complete_leap(enemy.attack_leap)
			assert(main.resolving_turn and enemy.attack_resolution_pending)
			assert(main.player.health.current == hp)
			assert(Helper._complete_projectile(main))
			assert(main.player.health.current == hp and main.resolving_turn)
			assert(Helper._complete_impact(main))
		Helper.complete(main)
		assert(main.player.health.current == hp - PokemonDamage.move_damage(enemy.battle_state, main.player.battle_state, move))
		assert(not enemy.attack_resolution_pending and not main.player.round_locked)
		# Basic branch never spends PP. At range it pursues; adjacent it attacks.
		enemy.attack_rng.seed = choice_seed(enemy.attack_policy.move_probability, false)
		hp = main.player.health.current
		var before := enemy.grid_position
		main.player.basic_attack()
		Helper._complete_leap(main.player.attack_leap)
		if not ranged: assert(visual.clip == "Attack")
		Helper.complete(main)
		assert(enemy.battle_state.remaining_pp[0] == pp - 1)
		if ranged:
			assert(enemy.grid_position == before + Vector2i.LEFT and main.player.health.current == hp)
		else:
			assert(main.player.health.current == hp - PokemonDamage.basic_damage(enemy.battle_state, main.player.battle_state))
		if ranged:
			validate_lanes(main, enemy, move)
			# Cancellation during flight and impact cannot apply damage or revive a round.
			for during_impact in [false, true]:
				enemy.setup(Vector2i(3, 0), main.dungeon, main.dungeon_renderer)
				main.enemy_occupancy = {enemy.grid_position: enemy}
				enemy.attack_rng.seed = choice_seed(0.25, true)
				hp = main.player.health.current
				main.player.basic_attack()
				Helper._complete_leap(main.player.attack_leap)
				if during_impact: assert(Helper._complete_projectile(main))
				main.cancel_round()
				assert(main.player.health.current == hp)
				assert(not main.resolving_turn and not enemy.attack_resolution_pending)
		main.free()
		await process_frame
	print("PASS: five prepared enemy scenes, native action mappings, independent PP, 95/5 melee and 25/75 projectile policy, lane eligibility, arrival/impact gating and cancellation; Stunky spawning unchanged")
	quit()

func validate_lanes(main: Node3D, enemy: Skeleton, move: PokemonMoveData) -> void:
	enemy.setup(Vector2i(3, 0), main.dungeon, main.dungeon_renderer)
	var target := Vector2i.ZERO
	var blocker := func(tile: Vector2i): return tile == target
	assert(not enemy.projectile_plan(move, target, blocker).is_empty())
	assert(enemy.projectile_plan(move, Vector2i(0, 1), blocker).is_empty())
	assert(enemy.projectile_plan(move, Vector2i(6, 2), blocker).is_empty())
	enemy.grid_position = Vector2i(5, 0)
	assert(enemy.projectile_plan(move, target, blocker).is_empty())
	enemy.grid_position = Vector2i(3, 0)
	var friend_blocker := func(tile: Vector2i): return tile == target or tile == Vector2i(2, 0)
	assert(enemy.projectile_plan(move, target, friend_blocker).is_empty())
	main.dungeon.set_tile(Vector2i(2, 0), DungeonData.TileType.WALL)
	assert(enemy.projectile_plan(move, target, blocker).is_empty())
	var pp := enemy.battle_state.remaining_pp[0]
	var rng_before := enemy.attack_rng.state
	enemy.take_turn(target, {enemy.grid_position: enemy}, blocker)
	assert(enemy.battle_state.remaining_pp[0] == pp and enemy.attack_rng.state == rng_before)
	main.dungeon.set_tile(Vector2i(2, 0), DungeonData.TileType.FLOOR)
