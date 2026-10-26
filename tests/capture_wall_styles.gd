extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run without --headless for normal-renderer wall inspection.")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	var directory := "res://.godot/wall_styles"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	TestDungeonFactory.rng.seed = 1
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	main.hud.get_node("Screen/PerformanceOverlay").hide() # Capture is not a benchmark.
	var data := BenchmarkDungeonFactory.create()
	main.dungeon = data
	var renderer: DungeonRenderer = main.dungeon_renderer
	var opacity := renderer.obstructing_wall_opacity
	# Opaque captures expose the underlying wall silhouette; the final capture
	# restores the existing selective-fading presentation unchanged.
	renderer.obstructing_wall_opacity = 1.0
	var positions := {"room": Vector2i(5, 8), "corridor": Vector2i(6, 10), "corner": Vector2i(1, 8)}
	for location in positions:
		for ratio in [1.0, 0.75, 0.5]:
			renderer.conventional_wall_height_scale = ratio
			assert(renderer.render_dungeon(data))
			main.player.setup(positions[location], data, renderer)
			main.spawn_test_enemies()
			main.refresh_fog()
			for frame in range(30): await process_frame
			await RenderingServer.frame_post_draw
			var path := directory + "/%s_%d.png" % [location, roundi(ratio * 100)]
			assert(root.get_texture().get_image().save_png(path) == OK)
			var hits := 0
			var camera: Camera3D = main.presentation_camera
			var feet: Vector3 = main.player.global_position
			for height in [0.1, 0.5, 0.9]:
				for side in [-0.3, 0.0, 0.3]:
					var target: Vector3 = feet + camera.global_basis.y * height + camera.global_basis.x * side
					for visual in renderer.fog_visuals:
						if not visual.wall: continue
						var mesh: MeshInstance3D = visual.mesh
						var inverse := mesh.global_transform.affine_inverse()
						if mesh.get_aabb().intersects_segment(inverse * camera.global_position, inverse * target) != null:
							hits += 1
							break
			print("WALL GPU CAPTURE ", path, " potential sprite-ray hits=", hits, "/9")
	renderer.obstructing_wall_opacity = opacity
	renderer.conventional_wall_height_scale = 0.75
	assert(renderer.render_dungeon(data))
	main.player.setup(positions.room, data, renderer)
	main.refresh_fog()
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory + "/room_75_fallback.png") == OK)
	assert(is_equal_approx(main.presentation_camera.pitch_degrees, 35.0))
	print("PASS: actual ", RenderingServer.get_current_rendering_method(), " wall comparison at 35 degrees, 1920x1080; no camera/project setting changes")
	main.free()
	quit()
