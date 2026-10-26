extends SceneTree
const Checks = preload("res://tests/diagnose_generation_profiles.gd")

func _initialize() -> void: call_deferred("diagnose")

static func percentile(values: Array[int], fraction: float) -> int:
	if values.is_empty(): return 0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(sorted.size() * fraction)) - 1, 0, sorted.size() - 1)]

func diagnose() -> void:
	var profiles := [
		["baseline", 5, 7, Vector2i(4, 4), Vector2i(7, 6)],
		["six_eight", 6, 8, Vector2i(5, 5), Vector2i(8, 7)],
		["six_nine", 6, 9, Vector2i(5, 5), Vector2i(8, 7)],
		["larger_six_eight", 6, 8, Vector2i(6, 5), Vector2i(9, 8)]]
	var results: Array[Dictionary] = []
	for profile in profiles:
		var config: DungeonGenerationConfig = TestDungeonFactory.get_default_config().duplicate()
		config.map_size = Vector2i(42, 32)
		config.minimum_rooms = profile[1]
		config.maximum_rooms = profile[2]
		config.minimum_room_size = profile[3]
		config.maximum_room_size = profile[4]
		var result := {"name": profile[0], "seeds": 100, "fallbacks": 0, "retried": 0, "layouts": 0, "routes": 0, "rooms": {}, "room_tiles": 0, "total_rooms": 0, "corridor_tiles": 0, "min_room_shortfall": 0}
		var lengths: Array[int] = []
		for seed_value in range(100):
			TestDungeonFactory.rng.seed = seed_value
			var data := TestDungeonFactory.create_configured_dungeon(config)
			Checks.verify(data, config)
			for a in range(data.rooms.size()):
				for b in range(a + 1, data.rooms.size()): assert(not data.rooms[a].grow(1).intersects(data.rooms[b]))
			result.fallbacks += int(data.used_fallback)
			result.retried += int(data.generation_attempts > 1)
			result.layouts += data.generation_attempts
			result.routes += data.routing_attempts
			result.rooms[data.rooms.size()] = int(result.rooms.get(data.rooms.size(), 0)) + 1
			result.min_room_shortfall += int(data.rooms.size() < config.minimum_rooms)
			result.total_rooms += data.rooms.size()
			for room in data.rooms: result.room_tiles += room.get_area()
			for tile: Vector2i in data.tiles:
				if data.get_tile(tile) == DungeonData.TileType.CORRIDOR: result.corridor_tiles += 1
			# Actual traversal distance between successive chain rooms, not a new
			# routing policy. Shared corridors/room interiors are included explicitly.
			var saved_spawn := data.player_spawn
			for connection in data.connections:
				data.player_spawn = data.rooms[connection.x].get_center()
				var reached := TestDungeonFactory.reachable_tiles(data)
				lengths.append(int(reached[data.rooms[connection.y].get_center()]))
			data.player_spawn = saved_spawn
		result["mean_room_area"] = float(result.room_tiles) / int(result.total_rooms)
		result["mean_layouts"] = float(result.layouts) / 100
		result["mean_routes"] = float(result.routes) / 100
		result["mean_corridor_tiles"] = float(result.corridor_tiles) / 100
		result["chain_distance_median"] = percentile(lengths, 0.5)
		result["chain_distance_p90"] = percentile(lengths, 0.9)
		result["chain_distance_max"] = percentile(lengths, 1.0)
		results.append(result)
		print("ROOM PROFILE ", JSON.stringify(result))
	var file := FileAccess.open("res://.godot/quality_diagnostics/spacious_rooms.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	quit()
