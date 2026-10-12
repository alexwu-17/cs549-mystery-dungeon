extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")
var acted: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	var data := DungeonData.new()
	for x in range(-3, 4):
		for y in range(-3, 4):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.player.health.reset(100)
	main.player.facing = Vector2i.DOWN
	main.enemy_action_started.connect(func(actor):
		assert(not main.player.attack_leap.active)
		for enemy in main.enemies:
			assert(not enemy.attack_leap.active)
		assert(not acted.has(actor))
		acted.append(actor))
	var orders: Dictionary = {}
	for seed_value in range(1, 7):
		acted.clear()
		main.turn_rng.seed = seed_value
		var expected_rng := RandomNumberGenerator.new()
		expected_rng.seed = seed_value
		expected_rng.randi_range(0, 2)
		expected_rng.randi_range(0, 1)
		for enemy in main.enemies:
			enemy.visible = false
		var hp: int = main.player.health.current
		main.player.basic_attack()
		assert(acted.is_empty() and main.player.health.current == hp)
		assert(main.resolving_turn and main.player.round_locked)
		main.player.basic_attack()
		main.player.try_move(Vector2i.DOWN)
		assert(main.player.grid_position == Vector2i.ZERO)
		main.player.attack_leap.finish()
		assert(acted.size() == 1 and main.player.health.current == hp - 2)
		assert(main.turn_rng.state == expected_rng.state)
		var first = acted[0]
		main.player.basic_attack()
		assert(not main.player.attack_leap.active)
		first.attack_leap.finish()
		assert(acted.size() == 2)
		Helper.complete(main)
		assert(acted.size() == 3 and main.player.health.current == hp - 6)
		assert(main.turn_rng.state == expected_rng.state)
		assert(not main.resolving_turn and not main.player.round_locked)
		orders[str(acted.map(func(actor): return actor.grid_position))] = true
	assert(orders.size() > 1)
	# A scheduled enemy killed while the first animation plays must be skipped.
	acted.clear()
	main.player.basic_attack()
	main.player.attack_leap.finish()
	var doomed: Skeleton
	for enemy in main.enemies:
		if enemy != acted[0]:
			doomed = enemy
			break
	doomed.receive_damage(99)
	Helper.complete(main)
	assert(acted.size() == 2 and not acted.has(doomed))
	doomed.health.reset(6)
	# The lethal leap finishes with no next action.
	acted.clear()
	main.player.health.reset(2)
	main.player.basic_attack()
	main.player.attack_leap.finish()
	assert(main.game_over and acted.size() == 1 and acted[0].attack_leap.active)
	acted[0].attack_leap.finish()
	assert(not main.resolving_turn and acted.size() == 1)
	main.start_new_run()
	# Cancellation emits completion, but the old token cannot unlock a new round.
	acted.clear()
	main.player.basic_attack()
	var old_token: int = main.round_generation
	main.load_test_floor()
	assert(main.round_generation > old_token and not main.resolving_turn)
	assert(not main.player.round_locked and not main.player.attack_leap.active)
	main.player.basic_attack()
	assert(main.resolving_turn and main.player.round_locked and acted.is_empty())
	Helper.complete(main)
	assert(not main.resolving_turn)
	main.free()
	await process_frame
	print("PASS: sequential player/enemy presentations, shuffled once-per-round order, hidden actors, input lock, lethal stop, cancellation")
	quit()
