extends SceneTree
## Reproducible comparisons; never loads the user-edited Limit benchmark config.
const Router = preload("res://scripts/dungeon/corridor_router.gd")

func _initialize() -> void: call_deferred("diagnose")

static func verify(data: DungeonData, config: DungeonGenerationConfig) -> void:
	assert(data != null and TestDungeonFactory.validate_floor(data))
	var reached := TestDungeonFactory.reachable_tiles(data)
	assert(reached.has(data.player_spawn) and reached.has(data.stairs_position))
	for tile: Vector2i in data.tiles:
		assert(reached.has(tile))
		assert(tile.x >= 0 and tile.y >= 0 and tile.x < config.map_size.x and tile.y < config.map_size.y)
	for room in data.rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x): assert(reached.has(Vector2i(x, y)))
	var occupied := {data.player_spawn: true, data.stairs_position: true}
	for spawn in data.enemy_spawns:
		assert(reached.has(spawn) and not occupied.has(spawn))
		occupied[spawn] = true
	for height in data.room_elevations:
		assert(height in ([0, 1] if config.elevation_mode == DungeonGenerationConfig.ElevationMode.TWO_LEVEL else [-1, 0, 1]))
	for segment in data.ramp_segments:
		assert(not config.restrict_camera_hidden_ramps or segment.direction != Vector2i.DOWN)
		for index in range(4):
			var tile: Vector2i = segment.lower_buffer + segment.direction * index
			assert(data.can_traverse(tile, tile + segment.direction) and data.can_traverse(tile + segment.direction, tile))

func run_profile(name: String, config: DungeonGenerationConfig, count: int) -> Dictionary:
	var result := {"profile": name, "size": config.map_size, "room_min": config.minimum_room_size, "room_max": config.maximum_room_size,
		"seeds": count, "fallbacks": 0, "retried_floors": 0, "layouts": 0, "routes": 0, "max_layouts": 0,
		"spacing_floors": 0, "camera_risk_floors": 0, "spacing_pairs": 0, "camera_risk_pairs": 0, "pairs": 0,
		"deficit": 0, "starts": [0, 0, 0], "both_levels": 0, "rooms": 0, "room_tiles": 0, "walkable_tiles": 0,
		"ramps": [0, 0, 0, 0], "generation_usec": 0, "verified_floors": 0, "examples": []}
	for seed_value in range(count):
		TestDungeonFactory.rng.seed = seed_value
		var began := Time.get_ticks_usec()
		var data := TestDungeonFactory.create_configured_dungeon(config)
		result.generation_usec += Time.get_ticks_usec() - began
		verify(data, config)
		result.verified_floors += 1
		var quality := TestDungeonFactory.last_quality_report.duplicate(true)
		assert(quality.evaluated)
		result.fallbacks += int(data.used_fallback)
		result.retried_floors += int(data.generation_attempts > 1)
		result.layouts += data.generation_attempts
		result.routes += data.routing_attempts
		result.max_layouts = maxi(result.max_layouts, data.generation_attempts)
		result.spacing_floors += int(not quality.violating_pairs.is_empty())
		result.camera_risk_floors += int(not quality.potential_overlap_pairs.is_empty())
		result.spacing_pairs += quality.violating_pairs.size()
		result.camera_risk_pairs += quality.potential_overlap_pairs.size()
		result.pairs += quality.pair_count
		result.deficit += quality.total_deficit
		result.starts[data.room_elevations[0] + 1] += 1 # Index order: -1, 0, +1.
		result.both_levels += int(data.room_elevations.has(0) and data.room_elevations.has(1))
		result.rooms += data.rooms.size()
		result.walkable_tiles += data.tiles.size()
		for room in data.rooms: result.room_tiles += room.get_area()
		for segment in data.ramp_segments: result.ramps[Router.DIRECTIONS.find(segment.direction)] += 1
		if result.examples.size() < 3 and not quality.potential_overlap_pairs.is_empty():
			result.examples.append({"seed": seed_value, "rooms": data.rooms, "heights": data.room_elevations, "camera_pairs": quality.potential_overlap_pairs})
		# Explicit replay checks; neither elapsed time nor reports affect generation.
		if seed_value < 5:
			var state: int = TestDungeonFactory.rng.state
			TestDungeonFactory.rng.seed = seed_value
			var replay := TestDungeonFactory.create_configured_dungeon(config)
			for property in ["rooms", "room_elevations", "tiles", "elevations", "connections", "ramp_segments", "player_spawn", "stairs_position", "enemy_spawns", "generation_attempts", "routing_attempts", "used_fallback"]:
				assert(data.get(property) == replay.get(property), property)
			assert(TestDungeonFactory.rng.state == state)
	result["random_success_rate"] = float(count - int(result.fallbacks)) / count
	result["average_layouts"] = float(result.layouts) / count
	result["average_routing_attempts"] = float(result.routes) / count
	result["average_rooms"] = float(result.rooms) / count
	result["average_room_area"] = float(result.room_tiles) / int(result.rooms)
	result["average_generation_ms"] = float(result.generation_usec) / count / 1000.0
	print("PROFILE ", JSON.stringify(DungeonLayoutQuality.serializable(result)))
	return result

func diagnose() -> void:
	var count := 100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): count = arg.trim_prefix("--seeds=").to_int()
		else:
			push_error("Use --seeds=100.")
			quit(1)
			return
	if count < 1 or count > 10000:
		quit(1)
		return
	var profiles: Array[Dictionary] = []
	for size: Vector2i in [Vector2i(30, 22), Vector2i(36, 28), Vector2i(42, 32)]:
		for variant in range(3):
			var config: DungeonGenerationConfig = load("res://config/legacy_generation.tres").duplicate()
			config.map_size = size
			var name := "legacy_unrestricted"
			if variant > 0:
				config.elevation_mode = DungeonGenerationConfig.ElevationMode.TWO_LEVEL
				config.prefer_both_elevations = true
				config.restrict_camera_hidden_ramps = variant == 2
				name = "two_restricted" if variant == 2 else "two_unrestricted"
			profiles.append(run_profile(name, config, count))
	# Separate experiment: moderate room growth, same 5..7 requested room counts.
	for size: Vector2i in [Vector2i(36, 28), Vector2i(42, 32)]:
		var spacious: DungeonGenerationConfig = TestDungeonFactory.get_default_config().duplicate()
		spacious.map_size = size
		spacious.minimum_room_size = Vector2i(5, 5)
		spacious.maximum_room_size = Vector2i(8, 7)
		profiles.append(run_profile("two_restricted_larger_rooms", spacious, count))
	var output := "res://.godot/quality_diagnostics/generation_profiles.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(DungeonLayoutQuality.serializable({"engine": Engine.get_version_info().string,
		"seed_start": 0, "notes": "Spacing and camera flags remain evaluation-only; routing attempts include rejected layouts; starts [-1,0,+1]; ramps [right,left,down,up].",
		"profiles": profiles}), "\t"))
	file.close()
	print("PASS: profile connectivity, spawns, policies, ramp bidirectionality and deterministic replay; REPORT ", ProjectSettings.globalize_path(output))
	quit()
