extends SceneTree
## Run without --headless: capture the real shared scene at its unchanged camera angle.
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("capture")

func save_frame(path: String) -> void:
	# Let shader compilation and the first presentation update settle. These
	# screenshots are visual evidence, not an FPS benchmark.
	for frame in range(60): await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(picture != null and not picture.is_empty())
	assert(picture.save_png(path) == OK)
	print("GPU CAPTURE ", path, " size=", picture.get_size())

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This inspection requires the normal renderer, without --headless.")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	root.title = "Environmental geometry validation"
	var directory := "res://.godot/environment_geometry"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	TestDungeonFactory.rng.seed = 0
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	var data := TestDungeonFactory.create_fallback_dungeon()
	for y in range(6, 11): data.set_tile(Vector2i(13, y), DungeonData.TileType.CORRIDOR, 1)
	data.player_spawn = Vector2i(12, 5)
	data.stairs_position = Vector2i(12, 3)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS, 1)
	data.enemy_spawns = [Vector2i(14, 4)]
	main.dungeon = data
	assert(TestDungeonFactory.validate_floor(data))
	main.dungeon_renderer.geometry_validation_enabled = false
	assert(main.dungeon_renderer.render_dungeon(data))
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.spawn_test_enemies()
	main.refresh_fog()
	await save_frame(directory + "/before.png")
	main.dungeon_renderer.geometry_validation_enabled = true
	main.dungeon_renderer.geometry_diagnostics_enabled = true
	assert(main.dungeon_renderer.render_dungeon(data))
	main.refresh_fog()
	await save_frame(directory + "/after.png")
	main.player.setup(Vector2i(13, 8), data, main.dungeon_renderer)
	main.refresh_fog()
	await save_frame(directory + "/walkway.png")
	# Find a real seeded lower path where required foundation stone intersects
	# opaque sprite samples; inspect the existing selective fading on the GPU.
	var lower_captured := false
	for seed_value in range(8):
		if lower_captured: break
		TestDungeonFactory.rng.seed = seed_value
		var generated := TestDungeonFactory.create_test_dungeon()
		main.dungeon = generated
		assert(main.dungeon_renderer.render_dungeon(generated))
		main.spawn_test_enemies()
		for tile: Vector2i in generated.tiles:
			if not generated.is_walkable(tile) or generated.get_elevation(tile) != 0 or generated.get_tile(tile) == DungeonData.TileType.RAMP or generated.enemy_spawns.has(tile): continue
			main.player.setup(tile, generated, main.dungeon_renderer)
			main.refresh_fog()
			for visual in main.dungeon_renderer.fog_visuals:
				if visual.purpose == EnvironmentGeometryPlan.FOUNDATION and visual.occluded:
					assert(visual.mesh.visible and is_equal_approx(visual.mesh.transparency, 0.8))
					print("GPU LOWER FOUNDATION VIEW seed=", seed_value, " player=", tile, " foundation=", visual.get("plan_id", ""))
					await save_frame(directory + "/lower_path.png")
					lower_captured = true
					break
			if lower_captured: break
	if not lower_captured: push_warning("No foundation-fading capture found in the first eight seeds; inspect manually.")
	assert(is_equal_approx(main.presentation_camera.pitch_degrees, 35.0))
	print("GPU INSPECTION ", DisplayServer.get_name(), " renderer=", RenderingServer.get_current_rendering_method(), " diagnostics=", main.dungeon_renderer.geometry_diagnostics)
	main.free()
	quit()
