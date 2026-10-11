extends SceneTree


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	# The final iteration forces insufficient placement and exercises the fallback.
	for seed_value in range(101):
		TestDungeonFactory.rng.seed = seed_value
		var dungeon := TestDungeonFactory.create_test_dungeon(0 if seed_value == 100 else 250)
		var reachable := TestDungeonFactory.reachable_tiles(dungeon)
		var occupied: Dictionary = {dungeon.player_spawn: true}
		assert(dungeon.get_tile(dungeon.stairs_position) == DungeonData.TileType.STAIRS)
		assert(reachable.has(dungeon.stairs_position))
		assert(not occupied.has(dungeon.stairs_position))
		occupied[dungeon.stairs_position] = true
		assert(TestDungeonFactory.room_id_grid[dungeon.stairs_position.y][dungeon.stairs_position.x] > 0)
		assert(dungeon.enemy_spawns.size() == 3)
		for spawn: Vector2i in dungeon.enemy_spawns:
			assert(reachable.has(spawn) and not occupied.has(spawn))
			occupied[spawn] = true
		for position: Vector2i in dungeon.tiles:
			assert(dungeon.get_elevation(position) == 0)
			assert(not dungeon.is_walkable(position) or reachable.has(position))
	var fixture := TestDungeonFactory.create_elevation_test_dungeon()
	assert(fixture.player_spawn == Vector2i(2, 2))
	assert(fixture.enemy_spawns == [Vector2i(10, 2)])
	assert(fixture.stairs_position == Vector2i(11, 3))
	assert(fixture.tiles.size() == 53)
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	renderer.render_dungeon(fixture)
	assert(renderer.get_child_count() == 54)
	assert(renderer.get_entity_world_position(Vector2i(7, 2)).is_equal_approx(Vector3(7, 0.6, 2)))
	assert(renderer.get_entity_world_position(Vector2i(8, 2)).is_equal_approx(Vector3(8, 1.1, 2)))
	renderer.render_dungeon(fixture)
	assert(renderer.get_child_count() == 54)
	renderer.free()
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	assert(main.get_node("Entities").get_child_count() == 3)
	main.player.grid_position = main.dungeon.stairs_position - Vector2i.DOWN
	main.player.try_move(Vector2i.DOWN)
	assert(main.player.grid_position == main.dungeon.player_spawn)
	assert(main.get_node("Entities").get_child_count() == 3)
	main.use_elevation_test = true
	main.load_test_floor()
	assert(main.get_node("Entities").get_child_count() == 1)
	# Move from immediately above stairs to trigger the actual signal/reset path.
	main.player.setup(Vector2i(11, 2), main.dungeon, main.dungeon_renderer)
	main.player.try_move(Vector2i.DOWN)
	assert(main.player.grid_position == Vector2i(2, 2))
	assert(main.get_node("Entities").get_child_count() == 1)
	main.free()
	print("PASS: 100 seeds plus placement fallback, spawn reachability/uniqueness, fixture heights/meshes, both floor resets")
	quit()
