extends SceneTree

func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	var settings := DungeonQualitySettings.new()
	var rooms: Array[Rect2i] = [Rect2i(0, 0, 3, 3), Rect2i(8, 0, 3, 3), Rect2i(20, 0, 3, 3)]
	var heights: Array[int] = [0, 1, -1]
	var saved_rooms := rooms.duplicate()
	var saved_heights := heights.duplicate()
	var state: int = TestDungeonFactory.rng.state
	var report := DungeonLayoutQuality.evaluate(rooms, heights, settings)
	assert(report.evaluated and report.pair_count == 3)
	assert(report.pairs[0].empty_separation == 5 and report.pairs[0].deficit == 0)
	assert(report.pairs[2].difference == 2 and report.pairs[2].empty_separation == 9 and report.pairs[2].deficit == 0)
	assert(rooms == saved_rooms and heights == saved_heights and TestDungeonFactory.rng.state == state)
	assert(report == DungeonLayoutQuality.evaluate(rooms, heights, settings))
	rooms[1].position.x -= 1
	var short := DungeonLayoutQuality.evaluate(rooms, heights, settings)
	assert(short.pairs[0].deficit == 1 and short.violating_pairs.has(Vector2i(0, 1)))
	settings.one_level_gap = 4
	assert(DungeonLayoutQuality.evaluate(rooms, heights, settings).pairs[0].deficit == 0)
	assert(DungeonLayoutQuality.empty_gaps(Rect2i(-3, -3, 3, 3), Rect2i(0, 0, 2, 2)) == Vector2i.ZERO)
	assert(DungeonLayoutQuality.empty_gaps(Rect2i(0, 0, 3, 3), Rect2i(6, 7, 3, 3)) == Vector2i(3, 4))
	settings.one_level_gap = 5
	rooms = [Rect2i(0, 0, 4, 4), Rect2i(0, 5, 4, 4)]
	heights = [0, 1]
	assert(DungeonLayoutQuality.evaluate(rooms, heights, settings).potential_overlap_pairs == [Vector2i(0, 1)])
	rooms[1].position.y = -5
	assert(DungeonLayoutQuality.evaluate(rooms, heights, settings).potential_overlap_pairs.is_empty())
	rooms[1].position = Vector2i(8, 0)
	assert(DungeonLayoutQuality.evaluate(rooms, heights, settings).potential_overlap_pairs.is_empty())
	heights = [0, 0]
	assert(DungeonLayoutQuality.evaluate(rooms, heights, settings).potential_overlap_pairs.is_empty())
	settings.one_level_gap = -1
	assert(not DungeonLayoutQuality.evaluate(rooms, heights, settings).evaluated)
	settings.one_level_gap = 5
	assert(not DungeonLayoutQuality.evaluate(rooms, [0], settings).evaluated)
	# Evaluation on/off must preserve all gameplay data, placement exhaustion, and RNG.
	var enabled := DungeonGenerationConfig.new()
	enabled.quality_settings = settings
	var disabled: DungeonGenerationConfig = enabled.duplicate(true)
	disabled.quality_settings.enabled = false
	var properties := ["tiles", "elevations", "rooms", "room_elevations", "connections", "ramp_segments", "ramp_tiles", "reserved_transitions", "player_spawn", "stairs_position", "enemy_spawns", "generation_attempts", "routing_attempts", "used_fallback"]
	for seed_value in range(12):
		var placement := 0 if seed_value == 11 else 250
		TestDungeonFactory.rng.seed = seed_value
		var a := TestDungeonFactory.create_test_dungeon(placement, Vector2i(30, 22), enabled)
		var report_snapshot := TestDungeonFactory.last_quality_report.duplicate(true)
		assert(report_snapshot.evaluated and report_snapshot.rooms == a.rooms)
		if not a.used_fallback:
			assert(TestDungeonFactory.last_quality_attempts.back().stage == "before_rasterization")
			assert(TestDungeonFactory.last_quality_attempts.back().outcome == "accepted")
		var after: int = TestDungeonFactory.rng.state
		TestDungeonFactory.rng.seed = seed_value
		var b := TestDungeonFactory.create_test_dungeon(placement, Vector2i(30, 22), disabled)
		assert(TestDungeonFactory.last_quality_report.is_empty() and TestDungeonFactory.last_quality_attempts.is_empty())
		for property in properties: assert(a.get(property) == b.get(property), property)
		assert(TestDungeonFactory.rng.state == after)
		assert(report_snapshot.evaluated) # Later generations cannot clear old snapshots.
	var sentinel := TestDungeonFactory.last_quality_report.duplicate(true)
	TestDungeonFactory.create_elevation_test_dungeon()
	BenchmarkDungeonFactory.create()
	DemoArenaFactory.create_arena()
	assert(TestDungeonFactory.last_quality_report == sentinel)
	print("PASS: all-pair spacing/boundaries/deficits, camera proxy, configuration, purity/replay, exact on/off dungeon and RNG equivalence, fallback and fixture exemptions")
	quit()
