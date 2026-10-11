extends SceneTree

var moves := 0


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var data := DungeonData.new()
	for x in range(7):
		for y in range(3):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i(0, 1)
	data.enemy_spawns = [Vector2i(5, 1), Vector2i(6, 1)]
	data.stairs_position = Vector2i(0, 2)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS)
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.player.moved.connect(func(): moves += 1)
	var first: Skeleton = main.enemies[0]
	var second: Skeleton = main.enemies[1]
	main.player.try_move(Vector2i.LEFT)
	assert(moves == 0 and first.grid_position == Vector2i(5, 1))
	main.player.try_move(Vector2i.RIGHT)
	assert(moves == 1 and first.grid_position == Vector2i(4, 1))
	assert(second.grid_position == Vector2i(5, 1))
	main.player.try_move(Vector2i.RIGHT)
	assert(moves == 2 and first.grid_position == Vector2i(3, 1))
	main.player.try_move(Vector2i.RIGHT)
	assert(moves == 2 and main.player.grid_position == Vector2i(2, 1))
	assert(first.health.current == 6 and main.player.health.current == 20)
	assert(first.grid_position == Vector2i(3, 1) and second.grid_position == Vector2i(4, 1))
	main.player.try_move(Vector2i.DOWN)
	assert(moves == 3)
	assert(main.enemy_occupancy.size() == 2)
	for enemy: Skeleton in main.enemies:
		assert(enemy.grid_position != main.player.grid_position)
		assert(main.enemy_occupancy[enemy.grid_position] == enemy)
		assert(enemy.position.is_equal_approx(main.dungeon_renderer.get_entity_world_position(enemy.grid_position)))
	# A detour must go around missing terrain, even when it initially leads away.
	var detour := DungeonData.new()
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)]:
		detour.set_tile(tile, DungeonData.TileType.FLOOR)
	main.dungeon_renderer.render_dungeon(detour)
	first.setup(Vector2i.ZERO, detour, main.dungeon_renderer)
	assert(first.next_step_toward(Vector2i(2, 0), {}) == Vector2i(0, 1))
	assert(first.next_step_toward(Vector2i(2, 0), {Vector2i(0, 1): second}) == Vector2i.ZERO)
	assert(first.next_step_toward(Vector2i(9, 9), {}) == Vector2i.ZERO)
	first.take_turn(Vector2i(0, 1), {})
	assert(first.grid_position == Vector2i.ZERO)
	# Stairs must free old enemies and skip the movement/enemy-phase signal.
	main.dungeon_renderer.render_dungeon(data)
	main.player.setup(Vector2i(0, 1), data, main.dungeon_renderer)
	var old_first: WeakRef = weakref(first)
	var old_second: WeakRef = weakref(second)
	main.player.try_move(Vector2i.DOWN)
	assert(moves == 3)
	assert(old_first.get_ref() == null and old_second.get_ref() == null)
	assert(main.enemy_occupancy.size() == main.enemies.size())
	for enemy: Skeleton in main.enemies:
		assert(enemy.dungeon_data == main.dungeon)
		assert(enemy.grid_position in main.dungeon.enemy_spawns)
		assert(main.enemy_occupancy[enemy.grid_position] == enemy)
	main.free()
	print("PASS: movement turns, blocked actions, sequential occupancy, adjacency, BFS detour/no path, stairs cleanup")
	quit()
