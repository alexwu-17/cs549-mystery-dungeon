extends SceneTree


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var data := DungeonData.new()
	for x in range(6):
		data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i(5, 0)]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	var enemy: Skeleton = main.enemies[0]
	var requests: Array[int] = [0]
	main.player.attack_requested.connect(func(_target: Vector2i): requests[0] += 1)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	assert(space.is_action_pressed("basic_attack"))
	assert(main.player.facing == Vector2i.DOWN)
	# Default-facing wall miss consumes exactly one phase without moving player.
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(requests[0] == 1 and enemy.grid_position == Vector2i(4, 0))
	assert(main.player.grid_position == Vector2i.ZERO)
	space.echo = true
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	space.echo = false
	space.pressed = false
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(requests[0] == 1 and enemy.grid_position == Vector2i(4, 0))
	space.pressed = true
	main.player.try_move(Vector2i.UP)
	assert(main.player.facing == Vector2i.UP and enemy.grid_position == Vector2i(4, 0))
	main.player.facing = Vector2i.RIGHT
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(requests[0] == 2 and enemy.grid_position == Vector2i(3, 0))
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(enemy.grid_position == Vector2i(2, 0))
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(enemy.grid_position == Vector2i(1, 0) and main.player.health.current == 20)
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(enemy.health.current == 3 and main.player.health.current == 18)
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.enemies.is_empty() and main.enemy_occupancy.is_empty())
	assert(main.player.health.current == 20 and main.player.grid_position == Vector2i.ZERO)
	main.loading_floor = true
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.player.health.current == 20 and main.enemies.is_empty())
	main.loading_floor = false
	main.player.receive_damage(20)
	var before := requests[0]
	main.player._unhandled_input(space)
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.game_over and requests[0] == before)
	main.start_new_run()
	assert(main.player.facing == Vector2i.DOWN and main.player.health.current == 20)
	main.free()
	await process_frame
	print("PASS: Space mapping, facing, wall/empty misses, repeat/release filtering, hits/healing, loading/death guards, restart")
	quit()
