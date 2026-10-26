extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	# Optional pre-change source verifies exact seeded output without committing
	# a duplicate generator. Pass its absolute path after --.
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var baseline := GDScript.new()
		baseline.source_code = FileAccess.get_file_as_string(args[0]).replace("class_name TestDungeonFactory", "")
		assert(baseline.reload() == OK)
		var legacy: DungeonGenerationConfig = load("res://config/legacy_generation.tres")
		for seed_value in range(20):
			baseline.rng.seed = seed_value
			var before: DungeonData = baseline.create_test_dungeon(20 if seed_value == 19 else 250)
			TestDungeonFactory.rng.seed = seed_value
			var after := TestDungeonFactory.create_test_dungeon(20 if seed_value == 19 else 250, Vector2i(30, 22), legacy)
			for property in ["tiles", "elevations", "rooms", "room_elevations", "connections", "ramp_segments", "player_spawn", "stairs_position", "enemy_spawns", "generation_attempts", "routing_attempts", "used_fallback"]:
				assert(before.get(property) == after.get(property), property)
			assert(baseline.rng.state == TestDungeonFactory.rng.state)
		print("PASS: exact pre-change generator comparison across 20 seeds, including placement exhaustion")
	var config := DungeonGenerationConfig.new()
	for size in [Vector2i(30, 22), Vector2i(36, 28), Vector2i(44, 34)]:
		config.map_size = size
		config.minimum_rooms = 3
		config.maximum_rooms = 5
		config.minimum_room_size = Vector2i(3, 3)
		config.maximum_room_size = Vector2i(6, 5)
		for seed_value in range(10):
			config.skeleton_limit = 0 if seed_value % 2 == 0 else 8
			TestDungeonFactory.rng.seed = seed_value
			var data := TestDungeonFactory.create_configured_dungeon(config)
			assert(data != null and TestDungeonFactory.validate_floor(data))
			if not data.used_fallback:
				assert(data.rooms.size() >= config.minimum_rooms and data.rooms.size() <= config.maximum_rooms)
				for room in data.rooms:
					assert(room.size.x >= 3 and room.size.x <= 6 and room.size.y >= 3 and room.size.y <= 5)
			assert(data.enemy_spawns.size() == config.skeleton_limit)
			var reached := TestDungeonFactory.reachable_tiles(data)
			var occupied := {data.player_spawn: true, data.stairs_position: true}
			for tile: Vector2i in data.tiles:
				assert(tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y)
			for enemy in data.enemy_spawns:
				assert(reached.has(enemy) and not occupied.has(enemy))
				occupied[enemy] = true
	# Bounded forced fallback and spawn shortfall.
	config.placement_attempts = 0
	config.layout_attempts = 1
	config.skeleton_limit = 1000
	var fallback := TestDungeonFactory.create_configured_dungeon(config)
	assert(fallback.used_fallback and fallback.generation_attempts == 1)
	assert(fallback.enemy_spawns.size() == 30)
	config.map_size = Vector2i(8, 8)
	assert(not config.validation_errors().is_empty())
	config.map_size = Vector2i(30, 22)
	config.minimum_rooms = 8
	assert(not config.validation_errors().is_empty())
	config.minimum_rooms = 3
	config.maximum_room_size = Vector2i(100, 5)
	assert(not config.validation_errors().is_empty())
	config.maximum_room_size = Vector2i(6, 5)
	config.skeleton_limit = -1
	assert(not config.validation_errors().is_empty())
	var resource: DungeonGenerationConfig = load("res://config/limit_testing.tres")
	# The resource is intentionally user-editable; defaults belong to the script.
	assert(resource != null)
	var defaults := DungeonGenerationConfig.new()
	assert(defaults.map_size == Vector2i(30, 22) and defaults.skeleton_limit == 3)
	assert(resource.validation_errors().is_empty())
	print("PASS: 30 configured floors at 30x22/36x28/44x34, range/bounds/reachability/spawns, fallback/shortfall, validation, resource isolation")
	quit()
