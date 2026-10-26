extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("capture")

func sample(main: Node3D, label: String, directory: String) -> Dictionary:
	for frame in range(90): await process_frame
	var intervals: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
	var sum := 0.0
	for value in intervals: sum += value
	intervals.sort()
	var result := {"mode": label, "frames": 180, "mean_interval_ms": sum / 180, "p95_interval_ms": intervals[170],
		"sampled_fps": 180000.0 / sum, "engine_fps": Engine.get_frames_per_second(), "mesh_nodes_added": 0, "instances_added": 0}
	var renderer: DungeonRenderer = main.dungeon_renderer
	if is_instance_valid(renderer.cave_background):
		var backdrop: CaveTerrainBackdrop = renderer.cave_background
		for index in range(backdrop.records.size()):
			var record: Dictionary = backdrop.records[index]
			assert(backdrop.cap_batch(record).multimesh.get_instance_transform(record.instance).is_equal_approx(record.cap_transform))
			assert(backdrop.body_batch(record).multimesh.get_instance_transform(record.instance).is_equal_approx(record.body_transform))
			var expected: Color = CaveTerrainBackdrop.instance_color(backdrop.records[index].shade, backdrop.records[index].tint)
			var actual := backdrop.cap_batch(record).multimesh.get_instance_color(record.instance)
			assert(absf(expected.r - actual.r) < 0.01 and absf(expected.g - actual.g) < 0.01 and absf(expected.b - actual.b) < 0.01)
		result.mesh_nodes_added = backdrop.diagnostics.mesh_nodes
		result.instances_added = backdrop.records.size() * 2
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory + "/" + label + ".png") == OK)
	print("CAVE GPU SAMPLE ", JSON.stringify(result))
	return result

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the normal renderer for independent GPU transform/color readback.")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	var directory := "res://.godot/cave_background"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	TestDungeonFactory.rng.seed = 4
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	# Keep comparison layout/camera identical even if the capture window receives
	# keyboard input while the developer is working in another application.
	main.set_process_unhandled_input(false)
	main.player.set_process_unhandled_input(false)
	main.player.gameplay_enabled = false
	main.hud.get_node("Screen/PerformanceOverlay").hide()
	var renderer: DungeonRenderer = main.dungeon_renderer
	var data: DungeonData = main.dungeon
	var position := data.player_spawn
	for tile: Vector2i in data.tiles:
		if data.get_tile(tile) == DungeonData.TileType.CORRIDOR and data.get_elevation(tile) == 1 and not data.reserved_transitions.has(tile):
			position = tile
			break
	var samples: Array[Dictionary] = []
	for enabled in [false, true]:
		renderer.cave_fill_enabled = enabled
		assert(renderer.render_dungeon(data))
		main.player.setup(position, data, renderer)
		main.spawn_test_enemies()
		main.refresh_fog()
		samples.append(await sample(main, "after" if enabled else "before", directory))
		assert(main.player.grid_position == position and main.dungeon == data and not main.resolving_turn)
	# Additional normal lower-room view; retain unchanged camera/light settings.
	for tile: Vector2i in data.tiles:
		if data.get_elevation(tile) == 0 and data.get_room_id(tile) >= 0 and data.get_tile(tile) == DungeonData.TileType.FLOOR:
			main.player.setup(tile, data, renderer)
			main.refresh_fog()
			break
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory + "/lower_room.png") == OK)
	var file := FileAccess.open(directory + "/performance.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"rendering_method": RenderingServer.get_current_rendering_method(), "size": [1920, 1080], "max_fps": Engine.max_fps, "samples": samples}, "\t"))
	file.close()
	assert(is_equal_approx(main.presentation_camera.pitch_degrees, 35.0))
	print("PASS: normal GPU readback, cap/body placement and fog colors, identical layout/camera before/after; ", directory)
	main.free()
	quit()
