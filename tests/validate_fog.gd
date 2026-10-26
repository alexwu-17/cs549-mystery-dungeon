extends SceneTree


func _initialize() -> void:
	call_deferred("validate")


func fog_state(renderer: DungeonRenderer, mesh: MeshInstance3D) -> int:
	for visual in renderer.fog_visuals:
		if visual.mesh == mesh:
			if visual.asset:
				assert(mesh.get_surface_override_material(0) == visual.materials[0][visual.fog_state])
			return visual.fog_state
	return -1


func validate() -> void:
	var data := DungeonData.new()
	data.rooms = [Rect2i(0, 0, 3, 3), Rect2i(5, 0, 3, 3)]
	for room in data.rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	for tile: Vector2i in [Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3)]:
		data.set_tile(tile, DungeonData.TileType.CORRIDOR)
	data.set_tile(Vector2i(3, 0), DungeonData.TileType.WALL)
	data.stairs_position = Vector2i(1, 1)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS)
	data.add_ramp(Vector2i(10, 6), Vector2i.RIGHT, 0)
	data.update_fog(Vector2i(2, 1))
	assert(data.is_bright(Vector2i(0, 0)))
	assert(data.is_bright(Vector2i(3, 2))) # Room visibility includes diagonal corridor.
	assert(not data.is_bright(Vector2i(3, 0))) # Room visibility excludes walls.
	assert(not data.is_bright(Vector2i(4, 1)))
	assert(data.discovered_tiles.has(Vector2i(3, 3))) # Entire one-tile border.
	assert(not data.discovered_tiles.has(Vector2i(4, 2)))
	data.update_fog(Vector2i(4, 1))
	assert(data.is_bright(Vector2i(5, 1))) # One-tile peek into the room entrance.
	assert(not data.is_bright(Vector2i(5, 2))) # No diagonal room reveal.
	assert(not data.is_bright(Vector2i(6, 1))) # No deeper room reveal.
	assert(data.discovered_tiles.has(Vector2i(5, 1))) # Cardinal discovery includes room.
	assert(not data.discovered_tiles.has(Vector2i(5, 2)))
	assert(data.is_bright(Vector2i(3, 2)))
	assert(data.discovered_tiles.has(Vector2i(0, 0))) # Memory persists.
	data.discovered_tiles.clear()
	data.update_fog(Vector2i(4, 1))
	assert(data.is_bright(Vector2i(3, 2)) and not data.discovered_tiles.has(Vector2i(3, 2)))
	data.update_fog(Vector2i(3, 1))
	assert(data.is_bright(Vector2i(3, 0))) # Nearby wall is bright in corridor.
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	renderer.render_dungeon(data)
	renderer.apply_fog()
	var slope: MeshInstance3D
	var stairs: MeshInstance3D
	for visual in renderer.fog_visuals:
		if visual.tiles.size() == 3:
			slope = visual.mesh
		if visual.stairs:
			stairs = visual.mesh
		else:
			assert(visual.mesh.visible) # Includes unexplored terrain.
	assert(not stairs.visible)
	assert(fog_state(renderer, slope) == 1)
	data.update_fog(Vector2i(10, 6))
	renderer.apply_fog()
	assert(data.is_bright(Vector2i(11, 6)) and not data.is_bright(Vector2i(13, 6)))
	assert(fog_state(renderer, slope) == 0) # Any bright tile.
	data.update_fog(Vector2i(1, 1))
	renderer.apply_fog()
	assert(stairs.visible and stairs.material_override == renderer.normal_material)
	assert(fog_state(renderer, slope) == 1)
	renderer.free()
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.dungeon.is_bright(Vector2i(0, 0)))
	assert(not main.enemies[0].visible)
	main.player.setup(Vector2i(8, 2), main.dungeon, main.dungeon_renderer)
	main.refresh_fog()
	assert(main.enemies[0].visible)
	main.player.try_move(Vector2i.LEFT) # Ramp is corridor; room enemy is hidden.
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	for enemy: Skeleton in main.enemies:
		assert(enemy.visible == main.dungeon.is_bright(enemy.grid_position))
	var old_data: DungeonData = main.dungeon
	main.load_test_floor()
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.dungeon != old_data)
	assert(not main.dungeon.discovered_tiles.has(Vector2i(12, 4)))
	assert(not main.enemies[0].visible)
	# A blocking enemy at either side of a doorway must be visible before moving.
	main.dungeon = data
	data.player_spawn = Vector2i(4, 1)
	data.enemy_spawns = [Vector2i(5, 1)]
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.refresh_fog()
	assert(main.enemies[0].visible)
	main.player.try_move(Vector2i.RIGHT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.grid_position == data.player_spawn and main.enemies[0].visible)
	data.player_spawn = Vector2i(2, 1)
	data.enemy_spawns = [Vector2i(3, 1)]
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.refresh_fog()
	assert(main.enemies[0].visible)
	main.player.try_move(Vector2i.RIGHT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.grid_position == data.player_spawn and main.enemies[0].visible)
	# Elevation shading is independent of discovery and bright visibility.
	main.use_elevation_test = true
	main.load_test_floor()
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	main.dungeon.enemy_spawns.clear()
	main.spawn_test_enemies()
	main.player.setup(Vector2i(6, 2), main.dungeon, main.dungeon_renderer)
	main.player.try_move(Vector2i.RIGHT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.fog_elevation == 0) # Uphill ramp retains departure level.
	main.player.try_move(Vector2i.RIGHT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.fog_elevation == 1)
	for visual in main.dungeon_renderer.fog_visuals:
		if visual.room == 0:
			assert(visual.fog_state == 2)
		elif visual.room == 1 and not visual.stairs:
			assert(visual.fog_state == 0)
	main.player.try_move(Vector2i.LEFT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.fog_elevation == 1) # Downhill ramp retains upper level.
	main.player.try_move(Vector2i.RIGHT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.fog_elevation == 1) # Turning back on the ramp.
	main.player.try_move(Vector2i.LEFT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	main.player.try_move(Vector2i.LEFT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.fog_elevation == 0)
	main.refresh_fog()
	for visual in main.dungeon_renderer.fog_visuals:
		if visual.room == 1 and not main.dungeon.is_bright(visual.tiles[0]):
			assert(visual.fog_state == 2)
	main.dungeon = TestDungeonFactory.create_fallback_dungeon()
	main.dungeon_renderer.render_dungeon(main.dungeon)
	main.player.setup(Vector2i(6, 3), main.dungeon, main.dungeon_renderer)
	# Each pair is (destination X, expected fog reference elevation).
	for step: Vector2i in [Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(10, 1), Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 0)]:
		var x := step.x
		main.player.try_move(Vector2i.RIGHT if x > main.player.grid_position.x else Vector2i.LEFT)
		load("res://tests/round_test_helper.gd").complete_introduction(main)
		assert(main.player.fog_elevation == step.y)
		for visual in main.dungeon_renderer.fog_visuals:
			var tile: Vector2i = visual.tiles[0]
			var bright := false
			for covered: Vector2i in visual.tiles:
				bright = bright or main.dungeon.is_bright(covered)
			if bright:
				assert(visual.fog_state == 0)
			elif main.dungeon.get_tile(tile) == DungeonData.TileType.RAMP:
				assert(visual.fog_state == 1)
			elif main.dungeon.get_tile(tile) == DungeonData.TileType.CORRIDOR:
				var expected: StandardMaterial3D = main.dungeon_renderer.dim_material if main.dungeon.get_elevation(tile) == step.y else main.dungeon_renderer.other_elevation_material
				assert(visual.fog_state == (1 if expected == main.dungeon_renderer.dim_material else 2))
	main.load_test_floor()
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.fog_elevation == 0)
	main.free()
	print("PASS: room/corridor doorway peeks, discovery, walls, whole ramps, stairs, blocking enemies, floor reset")
	quit()
