extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var baseline := BenchmarkDungeonFactory.create()
	var reachable := TestDungeonFactory.reachable_tiles(baseline)
	for tile: Vector2i in baseline.tiles:
		assert(tile.x >= 0 and tile.y >= 0 and tile.x < 30 and tile.y < 22)
		if baseline.is_walkable(tile): assert(reachable.has(tile))
	var candidates := BenchmarkDungeonFactory.candidates(baseline)
	assert(candidates.size() == 382)
	assert(candidates == BenchmarkDungeonFactory.candidates(BenchmarkDungeonFactory.create()))
	var seen := {}
	for tile in candidates:
		assert(not seen.has(tile) and reachable.has(tile))
		assert(tile != baseline.player_spawn and tile != baseline.stairs_position)
		seen[tile] = true
	var original_cap := Engine.max_fps
	Engine.max_fps = 144
	var main = load("res://scenes/main/limit_testing_main.tscn").instantiate()
	main.generation_config = DungeonGenerationConfig.new()
	main.generation_config.invincible_player = true
	root.add_child(main)
	var benchmark: LimitBenchmark = main.benchmark
	assert(Engine.max_fps == 60)
	Helper.complete_introduction(main)
	assert(main.enemies.size() == 20)
	var positions: Array[Vector2i] = main.dungeon.enemy_spawns.duplicate()
	benchmark.change_count(-5)
	assert(benchmark.selected == 15)
	benchmark.change_count(5)
	for index in range(4): benchmark.change_count(5)
	assert(benchmark.selected == 40)
	assert(main.enemies.size() == 20 and benchmark.actual == 20)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.enemies.size() == 40 and main.dungeon.enemy_spawns.slice(0, 20) == positions)
	assert(main.dungeon.tiles == baseline.tiles and main.player.grid_position == baseline.player_spawn)
	var reset_state: int = main.turn_rng.state
	main.run_enemy_turn()
	Helper.complete(main)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.turn_rng.state == reset_state and main.enemy_occupancy.size() == 40)
	benchmark.change_count(-10000)
	assert(benchmark.selected == 0)
	benchmark.change_count(10000)
	assert(benchmark.selected == 1000)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(benchmark.actual == 382 and main.enemies.size() == 382)
	assert(main.dungeon.tiles == baseline.tiles)
	assert(main.player.health.current == 20 and main.player.invincible)
	main.player.attack_leap.play(Vector2i.UP)
	main.run_enemy_turn()
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(not main.resolving_turn and not main.player.round_locked)
	main.free()
	assert(Engine.max_fps == 144)
	Engine.max_fps = original_cap
	for mode in ["main", "demo_main"]:
		var ordinary = load("res://scenes/main/%s.tscn" % mode).instantiate()
		root.add_child(ordinary)
		assert(ordinary.benchmark == null and Engine.max_fps == original_cap)
		ordinary.free()
	assert(not InputMap.has_action("benchmark_advance_turn"))
	print("PASS: 30x22 connected layout, 382 capacity, deterministic prefix spawns, count buttons/reset/cancellation, mode/cap isolation")
	quit()
