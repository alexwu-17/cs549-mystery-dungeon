extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")
const Library = preload("res://scripts/effects/pokemon_sprite_library.gd")
var placeholders: bool = false

func _initialize() -> void:
	call_deferred("profile")

func summarize(values: Array[float]) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	var over_budget := 0
	for value in ordered:
		total += value
		if value > 16.667: over_budget += 1
	return {"mean_ms": total / ordered.size(), "p95_ms": ordered[int(ordered.size()*0.95)], "max_ms": ordered.back(), "over_16_667_ms": over_budget, "frames": ordered.size()}

func measure(main: Node, label: String, moving: bool) -> Dictionary:
	for frame in range(120): await process_frame
	var intervals: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var draws := 0.0
	var turns := 0
	var last := Time.get_ticks_usec()
	var last_move := last
	var directions := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
	var direction_index := 0
	var library_count := Library.cache.size()
	for frame in range(600):
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now-last)/1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if moving and now-last_move >= 80000 and not main.resolving_turn:
			last_move = now
			var previous: Vector2i = main.player.grid_position
			for attempt in range(4):
				var direction: Vector2i = directions[direction_index % 4]
				direction_index += 1
				var target := previous + direction
				if not main.dungeon.can_traverse(previous,target) or main.is_enemy_occupied(target): continue
				main.player._set_movement_speed(3.0)
				main.player.try_move(direction)
				if main.player.grid_position != previous:
					turns += 1
					break
	assert(Library.cache.size() == library_count)
	var result := summarize(intervals)
	var gpu_mean: float = summarize(gpu).mean_ms
	result["gpu_mean_ms"] = gpu_mean if gpu_mean > 0.0 else null
	result["render_cpu_mean_ms"] = summarize(cpu).mean_ms
	result["draws_mean"] = draws / 600.0
	result["successful_moves"] = turns
	result["label"] = label
	print("POKEMON_PROFILE ", JSON.stringify(result))
	return result

func profile() -> void:
	root.size = Vector2i(1920,1080)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	TestDungeonFactory.rng.seed = 4
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	placeholders = "--placeholder" in OS.get_cmdline_user_args()
	if placeholders:
		main.get_node("Player/VisualController").profile = null
		main.get_node("Entities").child_entered_tree.connect(func(actor: Node):
			if actor.has_node("VisualController"):
				actor.get_node("VisualController").profile = null)
	root.add_child(main)
	if placeholders:
		assert(main.player.character_visual.clips.is_empty())
		for enemy in main.enemies: assert(enemy.character_visual.clips.is_empty())
	Helper.complete_introduction(main)
	main.player.invincible = true
	main.turn_rng.seed = 549
	assert(root.size == Vector2i(1920,1080) and is_equal_approx(root.scaling_3d_scale,1.0))
	var results: Array = []
	results.append(await measure(main,"procedural_idle_animated",false))
	# Includes the actual sequential AI phases and animations, never forced completion.
	main.player._set_movement_speed(3.0)
	results.append(await measure(main,"procedural_movement_3x",true))
	while main.resolving_turn: await process_frame
	main.player.stop_held_movement()
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	Helper.complete_introduction(main)
	main.player.invincible = true
	main.player.setup(Vector2i(13,11), main.dungeon, main.dungeon_renderer)
	main.refresh_fog()
	main.player._set_movement_speed(3.0)
	results.append(await measure(main,"boss_arena_movement_3x",true))
	while main.resolving_turn: await process_frame
	main.player.stop_held_movement()
	var report := {"placeholders": placeholders, "engine": Engine.get_version_info().string, "resolution": root.size, "results": results}
	DirAccess.make_dir_recursive_absolute("res://.godot/pokemon_validation")
	var file := FileAccess.open("res://.godot/pokemon_validation/performance_%s.json" % ("placeholder" if placeholders else "pokemon"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	main.free()
	await process_frame
	print("PASS: completed native 1080p animation/real-round profiles; see measured budget results")
	quit()
