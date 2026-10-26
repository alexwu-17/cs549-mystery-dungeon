extends SceneTree

func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	var standard := DungeonGenerationConfig.new()
	var legacy: DungeonGenerationConfig = load("res://config/legacy_generation.tres")
	var starts := [0, 0]
	for seed_value in range(100):
		TestDungeonFactory.rng.seed = seed_value
		var heights := TestDungeonFactory.assign_heights(30, standard)
		starts[heights[0]] += 1
		assert(heights.has(0) and heights.has(1))
		var same := 0
		for index in range(1, heights.size()):
			assert(heights[index] in [0, 1])
			same = same + 1 if heights[index] == heights[index - 1] else 0
			assert(same <= 3)
		# Two-room exhausted placements still prefer both heights, without retries.
		TestDungeonFactory.rng.seed = seed_value
		var short := TestDungeonFactory.assign_heights(2, standard)
		assert(short.has(0) and short.has(1))
		TestDungeonFactory.rng.seed = seed_value
		var old := TestDungeonFactory.assign_heights(100, legacy)
		assert(old[0] == 0 and old.has(-1) and old.has(1))
	assert(starts[0] > 0 and starts[1] > 0)
	assert(TestDungeonFactory.assign_heights(0, standard).is_empty())
	# Confirm the actual camera side agrees with the fixed policy, without changing it.
	var camera = load("res://scripts/core/presentation_camera.gd").new()
	assert(is_equal_approx(camera.pitch_degrees, 35.0) and camera.follow_offset.z > 0)
	camera.free()
	var helper = load("res://tests/diagnose_generation_profiles.gd")
	for restricted in [false, true]:
		standard.restrict_camera_hidden_ramps = restricted
		for seed_value in range(12):
			TestDungeonFactory.rng.seed = seed_value
			var data := TestDungeonFactory.create_configured_dungeon(standard)
			helper.verify(data, standard)
			var state: int = TestDungeonFactory.rng.state
			TestDungeonFactory.rng.seed = seed_value
			var replay := TestDungeonFactory.create_configured_dungeon(standard)
			assert(data.tiles == replay.tiles and data.room_elevations == replay.room_elevations and data.enemy_spawns == replay.enemy_spawns)
			assert(TestDungeonFactory.rng.state == state)
	# Forced fallback remains known-valid and obeys the strict orientation policy.
	standard.placement_attempts = 0
	standard.layout_attempts = 1
	standard.restrict_camera_hidden_ramps = true
	var fallback := TestDungeonFactory.create_configured_dungeon(standard)
	assert(fallback.used_fallback)
	helper.verify(fallback, standard)
	assert(DungeonData.ELEVATION_HEIGHT == 3.0)
	print("PASS: two-level assignment/start variety/progression, legacy heights, deterministic policies, camera direction, bidirectional ramps, fallback")
	quit()
