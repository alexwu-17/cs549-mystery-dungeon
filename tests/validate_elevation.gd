extends SceneTree

const Router = preload("res://scripts/dungeon/corridor_router.gd")
const SEEDS = 250


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	assert([TestDungeonFactory.change_probability(0), TestDungeonFactory.change_probability(1), TestDungeonFactory.change_probability(2), TestDungeonFactory.change_probability(3)] == [10, 40, 70, 100])
	for seed_value in range(100):
		TestDungeonFactory.rng.seed = seed_value
		var heights := TestDungeonFactory.assign_heights(100)
		var same := 0
		for index in range(1, heights.size()):
			assert(heights[index] in [-1, 0, 1])
			if heights[index] == heights[index - 1]:
				same += 1
				assert(same <= 3)
			else:
				assert(absi(heights[index] - heights[index - 1]) == 1)
				same = 0
	for direction: Vector2i in DungeonData.CARDINALS:
		check_orientation(direction)
	for size: Vector2i in [Vector2i(30, 22), Vector2i(36, 28)]:
		var fallbacks := 0
		var retries := 0
		var total_layouts := 0
		var routes := 0
		var max_layouts := 0
		var segment_count := 0
		for seed_value in range(SEEDS):
			TestDungeonFactory.rng.seed = seed_value
			var dungeon := TestDungeonFactory.create_test_dungeon(250, size)
			fallbacks += int(dungeon.used_fallback)
			retries += int(dungeon.generation_attempts > 1)
			total_layouts += dungeon.generation_attempts
			routes += dungeon.routing_attempts
			max_layouts = maxi(max_layouts, dungeon.generation_attempts)
			segment_count += dungeon.ramp_segments.size()
			check_floor(dungeon)
		print("ELEVATION METRICS size=", size, " seeds=", SEEDS, " random_success=", SEEDS - fallbacks, " retried_floors=", retries, " layout_attempts=", total_layouts, " max_layouts=", max_layouts, " footprint_attempts=", routes, " fallbacks=", fallbacks, " segments=", segment_count)
	print("PASS: elevation assignment, orientations, geometry, traversal, combat cliffs, routing atomicity, multi-seed connectivity")
	quit()


func check_floor(data: DungeonData) -> void:
	assert(data.room_elevations[0] == 0)
	for id in range(data.rooms.size()):
		assert(data.room_elevations[id] in [-1, 0, 1])
		var room := data.rooms[id]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				assert(data.get_elevation(Vector2i(x, y)) == data.room_elevations[id])
	for edge in data.connections:
		assert(absi(data.room_elevations[edge.x] - data.room_elevations[edge.y]) <= 1)
	var reachable := TestDungeonFactory.reachable_tiles(data)
	for tile: Vector2i in data.tiles:
		assert(reachable.has(tile))
	assert(reachable.has(data.stairs_position))
	var occupied: Dictionary = {data.player_spawn: true, data.stairs_position: true}
	for spawn in data.enemy_spawns:
		assert(reachable.has(spawn) and not occupied.has(spawn))
		occupied[spawn] = true
	for segment in data.ramp_segments:
		var lower: Vector2i = segment.lower_buffer
		var direction: Vector2i = segment.direction
		for index in range(5):
			var tile := lower + direction * index
			for room in data.rooms:
				assert(not room.has_point(tile))
			for side: Vector2i in [Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)]:
				assert(not data.is_walkable(tile + side))
			if index < 4:
				assert(data.can_traverse(tile, tile + direction) and data.can_traverse(tile + direction, tile))
		assert(data.can_traverse(lower, lower - direction))
		assert(data.can_traverse(lower + direction * 4, lower + direction * 5))


func check_orientation(direction: Vector2i) -> void:
	var data := DungeonData.new()
	var lower := Vector2i(10, 10)
	data.add_ramp(lower, direction, -1)
	data.set_tile(lower - direction, DungeonData.TileType.FLOOR, -1)
	data.set_tile(lower + direction * 5, DungeonData.TileType.FLOOR, 0)
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	renderer.render_dungeon(data)
	assert(renderer.get_child_count() == 5)
	var slope: MeshInstance3D
	for child in renderer.get_children():
		if child.mesh is ArrayMesh:
			slope = child
	assert(slope != null)
	var arrays := slope.mesh.surface_get_arrays(0)
	var mesh_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mesh_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(mesh_normals[0].y > 0)
	var start_edge := slope.transform * mesh_vertices[0]
	var end_edge := slope.transform * mesh_vertices[1]
	var lower_surface := renderer.get_entity_world_position(lower)
	var upper_surface := renderer.get_entity_world_position(lower + direction * 4)
	assert(is_equal_approx(start_edge.y, lower_surface.y) and is_equal_approx(end_edge.y, upper_surface.y))
	assert(is_equal_approx((Vector2(end_edge.x, end_edge.z) - Vector2(start_edge.x, start_edge.z)).dot(Vector2(direction)), 3.0))
	for index in range(3):
		var tile := lower + direction * (index + 1)
		assert(is_equal_approx(renderer.get_entity_world_position(tile).y, -3.0 + (index + 0.5) + 0.1))
		var side := tile + Vector2i(-direction.y, direction.x)
		data.set_tile(side, DungeonData.TileType.FLOOR, -1)
		assert(not data.can_traverse(tile, side) and not data.can_traverse(side, tile))
	# Walk the whole segment with a player, then with a skeleton, in both directions.
	var player := Player.new()
	root.add_child(player)
	player.health.reset(20)
	player.setup(lower, data, renderer)
	for index in range(4):
		player.try_move(direction)
	assert(player.grid_position == lower + direction * 4)
	for index in range(4):
		player.try_move(-direction)
	assert(player.grid_position == lower)
	var enemy := Skeleton.new()
	root.add_child(enemy)
	enemy.setup(lower - direction, data, renderer)
	for index in range(5):
		enemy.take_turn(lower + direction * 5, {enemy.grid_position: enemy})
	assert(enemy.grid_position == lower + direction * 4)
	for index in range(5):
		enemy.take_turn(lower - direction, {enemy.grid_position: enemy})
	assert(enemy.grid_position == lower)
	var cliff := Vector2i(20, 20)
	data.set_tile(cliff, DungeonData.TileType.FLOOR, -1)
	data.set_tile(cliff + direction, DungeonData.TileType.FLOOR, 1)
	assert(not data.can_traverse(cliff, cliff + direction))
	var attacks: Array[int] = [0]
	enemy.attack_requested.connect(func(_damage: int): attacks[0] += 1)
	enemy.setup(cliff, data, renderer)
	enemy.take_turn(cliff + direction, {})
	assert(attacks[0] == 0 and enemy.grid_position == cliff)
	var saved := data.tiles.duplicate()
	assert(not Router.flat_connection(cliff, cliff + direction, -1, data, Vector2i(30, 30), true))
	assert(data.tiles == saved)
	var saved_heights := data.elevations.duplicate()
	var saved_segments := data.ramp_segments.duplicate(true)
	assert(Router.elevated_connection(cliff, cliff + direction, -1, data, Vector2i(4, 4), TestDungeonFactory.rng) == -1)
	assert(data.tiles == saved and data.elevations == saved_heights and data.ramp_segments == saved_segments)
	# Both combat participants must reject a cliff, while a Space miss still acts.
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	data.player_spawn = cliff
	data.enemy_spawns = [cliff + direction]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(cliff, data, main.dungeon_renderer)
	main.player.facing = direction
	main.player.basic_attack()
	assert(main.enemies[0].health.current == 6 and main.player.health.current == 20)
	main.free()
	player.free()
	enemy.free()
	renderer.free()
