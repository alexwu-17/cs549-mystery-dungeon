extends SceneTree
## Normal-render capture scenarios; use -- --list or -- --scenario=NAME/all.
const Support = preload("res://tests/capture_support.gd")
const Helper = preload("res://tests/round_test_helper.gd")
const Snapshots = preload("res://tests/validate_terraces.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await Support.run(self, {"foundations": foundations_capture, "backing": backing_capture, "terrain": terrain_run, "walls": walls_capture, "rotation": rotation_run}, "foundations")

## Run without --headless: capture the real shared scene at its unchanged camera angle.


func foundations_save_frame(path: String) -> void:
	# Let shader compilation and the first presentation update settle. These
	# screenshots are visual evidence, not an FPS benchmark.
	for frame in range(60): await process_frame
	var picture := Support.image(self)
	assert(picture != null and not picture.is_empty())
	assert(picture.save_png(path) == OK)
	print("GPU CAPTURE ", path, " size=", picture.get_size())

func foundations_capture() -> bool:
	if DisplayServer.get_name() == "headless":
		push_error("This inspection requires the normal renderer, without --headless.")
		return false
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
	await foundations_save_frame(directory + "/before.png")
	main.dungeon_renderer.geometry_validation_enabled = true
	main.dungeon_renderer.geometry_diagnostics_enabled = true
	assert(main.dungeon_renderer.render_dungeon(data))
	main.refresh_fog()
	await foundations_save_frame(directory + "/after.png")
	main.player.setup(Vector2i(13, 8), data, main.dungeon_renderer)
	main.refresh_fog()
	await foundations_save_frame(directory + "/walkway.png")
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
					await foundations_save_frame(directory + "/lower_path.png")
					lower_captured = true
					break
			if lower_captured: break
	if not lower_captured: push_warning("No foundation-fading capture found in the first eight seeds; inspect manually.")
	assert(is_equal_approx(main.presentation_camera.pitch_degrees, 35.0))
	print("GPU INSPECTION ", DisplayServer.get_name(), " renderer=", RenderingServer.get_current_rendering_method(), " diagnostics=", main.dungeon_renderer.geometry_diagnostics)
	main.free()
	return true

func backing_sample(main: Node3D, label: String, directory: String) -> Dictionary:
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
	Support.save(self, directory + "/" + label + ".png")
	print("CAVE GPU SAMPLE ", JSON.stringify(result))
	return result

func backing_capture() -> bool:
	if DisplayServer.get_name() == "headless":
		push_error("Use the normal renderer for independent GPU transform/color readback.")
		return false
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
	# This diagnostic explicitly exercises the retained MultiMesh backing path.
	# Current continuous mesh coverage belongs to the terrain scenario.
	renderer.cave_continuous_ground_enabled = false
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
		samples.append(await backing_sample(main, "after" if enabled else "before", directory))
		assert(main.player.grid_position == position and main.dungeon == data and not main.resolving_turn)
	# Additional normal lower-room view; retain unchanged camera/light settings.
	for tile: Vector2i in data.tiles:
		if data.get_elevation(tile) == 0 and data.get_room_id(tile) >= 0 and data.get_tile(tile) == DungeonData.TileType.FLOOR:
			main.player.setup(tile, data, renderer)
			main.refresh_fog()
			break
	for frame in range(30): await process_frame
	Support.save(self, directory + "/lower_room.png")
	var file := FileAccess.open(directory + "/performance.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"rendering_method": RenderingServer.get_current_rendering_method(), "size": [1920, 1080], "max_fps": Engine.max_fps, "samples": samples}, "\t"))
	file.close()
	assert(is_equal_approx(main.presentation_camera.pitch_degrees, 35.0))
	print("PASS: normal GPU readback, cap/body placement and fog colors, identical layout/camera before/after; ", directory)
	main.free()
	return true

## Normal Forward+ only: four reversible stages, fixed seeds/poses, 1080p.
## Writes local captures and raw samples to ignored .godot/continuous_terrain/.
var terrain_results: Array=[]
func terrain_run() -> bool:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute("res://.godot/continuous_terrain")
	root.size=Vector2i(1920,1080)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for seed_value in [4,17]:
		TestDungeonFactory.rng.seed=seed_value
		var main=load("res://scenes/main/main.tscn").instantiate()
		main.get_node("DungeonRenderer").cave_scenery_border_width=6
		root.add_child(main)
		Helper.complete_introduction(main)
		main.set_process_unhandled_input(false)
		main.player.set_process_unhandled_input(false)
		main.hud.get_node("Screen/PerformanceOverlay").hide()
		var data: DungeonData=main.dungeon
		var edge:=data.player_spawn
		var closest:=100000
		for tile in data.tiles:
			if not data.is_walkable(tile) or data.get_elevation(tile)!=1 or data.get_tile(tile)==DungeonData.TileType.RAMP: continue
			var distance:=mini(mini(tile.x-data.map_bounds.position.x,data.map_bounds.end.x-1-tile.x),mini(tile.y-data.map_bounds.position.y,data.map_bounds.end.y-1-tile.y))
			if distance<closest:
				closest=distance
				edge=tile
		var views: Dictionary={"spawn":data.player_spawn,"edge":edge,"ramp":data.ramp_segments[0].lower_buffer}
		for tile in data.tiles:
			if data.get_tile(tile)==DungeonData.TileType.CORRIDOR and data.get_elevation(tile)==1 and not data.reserved_transitions.has(tile):
				views["bridge"]=tile
				break
		for pose in views:
			var location: Vector2i=views[pose]
			for stage in [1,2,3,4]:
				var before:=Snapshots.snapshot(data)
				var rng: int=TestDungeonFactory.rng.state
				main.dungeon_renderer.cave_continuous_ground_enabled=stage>=2
				main.dungeon_renderer.cave_stone_mapping_enabled=stage>=3
				main.dungeon_renderer.cave_weathered_edges_enabled=stage>=4
				assert(main.dungeon_renderer.render_dungeon(data))
				assert(before==Snapshots.snapshot(data) and rng==TestDungeonFactory.rng.state)
				main.player.setup(location,data,main.dungeon_renderer)
				main.refresh_fog()
				for i in range(60): await process_frame
				assert(root.get_texture().get_size()==Vector2(1920,1080) and root.scaling_3d_scale==1.0)
				var intervals: Array=[]
				var cpu: Array=[]
				var gpu: Array=[]
				var draws: Array=[]
				var primitives: Array=[]
				var surface=main.dungeon_renderer.cave_background.ground_surface
				var palette_uploads: int=surface.stats.palette_uploads if surface!=null else 0
				var previous:=Time.get_ticks_usec()
				for i in range(120):
					await process_frame
					var now:=Time.get_ticks_usec()
					intervals.append((now-previous)/1000.0)
					previous=now
					cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
					draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
					primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				if surface!=null: assert(surface.stats.palette_uploads==palette_uploads)
				var backdrop: CaveTerrainBackdrop=main.dungeon_renderer.cave_background
				var result: Dictionary={"seed":seed_value,"pose":pose,"tile":str(location),"stage":stage,"frame_ms":Support.stats(intervals),"render_cpu_ms":Support.stats(cpu),"gpu_ms":Support.stats(gpu),"draw_calls":Support.stats(draws),"primitives":Support.stats(primitives),"counts":Support.counts(main),"backdrop":backdrop.diagnostics,"raw_frame_ms":intervals,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
				if true:
					result["detailed_bounds"]=str(backdrop.scenery_apron.detailed_bounds)
					result["apron_bounds"]=str(backdrop.scenery_apron.visual_bounds)
					result["guard_margin"]=backdrop.scenery_apron.guard_margin
				Support.save(self, "res://.godot/continuous_terrain/%d_%s_%d.png"%[seed_value,pose,stage])
				terrain_results.append(result)
				print("TERRAIN SAMPLE ",seed_value," ",pose," ",stage," frame=",result.frame_ms," GPU=",result.gpu_ms.mean," draws=",result.draw_calls.mean," meshes=",result.counts)
		main.free()
	var file:=FileAccess.open("res://.godot/continuous_terrain/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"results":terrain_results},"\t"))
	file.close()
	print("PASS: short fixed-seed stages 1/2/3/4 A/B, unchanged gameplay/RNG, 1080p")
	return true

func walls_capture() -> bool:
	if DisplayServer.get_name() == "headless":
		push_error("Run without --headless for normal-renderer wall inspection.")
		return false
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
			var path := directory + "/%s_%d.png" % [location, roundi(ratio * 100)]
			Support.save(self, path)
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
	Support.save(self, directory + "/room_75_fallback.png")
	assert(is_equal_approx(main.presentation_camera.pitch_degrees, 35.0))
	print("PASS: actual ", RenderingServer.get_current_rendering_method(), " wall comparison at 35 degrees, 1920x1080; no camera/project setting changes")
	main.free()
	return true

func rotation_run() -> bool:
	root.size=Vector2i(1920,1080)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	TestDungeonFactory.rng.seed=4
	var main=load("res://scenes/demos/sunlight_demo.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	var room:Rect2i=main.dungeon.rooms[2]
	main.player.setup(room.position+room.size/2,main.dungeon,main.dungeon_renderer)
	main.refresh_fog()
	for i in range(15): await process_frame
	main.hud.hide()
	main.get_node("SunlightAtmosphere").ground_mist.material.set_shader_parameter("preview_time",0.0)
	var before=Snapshots.snapshot(main.dungeon)
	var nodes:=0
	var draws_before:=0.0
	for enabled in [false,true]:
		main.dungeon_renderer.upper_floor_quarter_turns_enabled=enabled
		assert(main.dungeon_renderer.render_dungeon(main.dungeon))
		main.refresh_fog()
		main.update_presentation()
		for i in range(45): await process_frame
		var samples:Array=[]
		var gpu:=0.0
		var draws:=0.0
		var primitives:=0.0
		var last=Time.get_ticks_usec()
		for i in range(120):
			await process_frame
			var now=Time.get_ticks_usec()
			samples.append((now-last)/1000.0)
			last=now
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var mean:=0.0
		for value in samples: mean+=value
		samples.sort()
		var count=main.dungeon_renderer.get_child_count()
		if not enabled:
			nodes=count
			draws_before=draws/120
		else:
			assert(count==nodes and draws/120==draws_before)
		assert(Snapshots.snapshot(main.dungeon)==before)
		Support.save(self, "res://.godot/sunlight_prototypes/upper_rotated_%s.png"%str(enabled))
		print("ROTATION enabled=",enabled," mean=",mean/120," p95=",samples[113]," gpu=",gpu/120," draws=",draws/120," primitives=",primitives/120," renderer nodes=",count)
	main.free()
	print("PASS: fixed-seed 1080p quarter-turn comparison, unchanged nodes/draws/topology")
	return true
