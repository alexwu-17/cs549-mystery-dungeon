extends SceneTree
## Normal Forward+ only: three lighting presets, fixed seeds/poses, 1080p.
## Writes local captures and raw samples to ignored .godot/lighting_presets/.
const Helper=preload("res://tests/round_test_helper.gd")
const Snapshots=preload("res://tests/validate_terraces.gd")
var results: Array=[]
var preview: bool=false
func _initialize() -> void: call_deferred("run")
func stats(values: Array) -> Dictionary:
	var sorted:=values.duplicate()
	sorted.sort()
	var total:=0.0
	for value in values: total+=value
	return {"mean":total/values.size(),"p95":sorted[ceili(values.size()*.95)-1],"p99":sorted[ceili(values.size()*.99)-1],"max":sorted.back()}
func counts(node: Node) -> Dictionary:
	var result: Dictionary={"nodes":1,"mesh_nodes":int(node is MeshInstance3D),"multimesh_nodes":int(node is MultiMeshInstance3D)}
	for child in node.get_children():
		var sub:=counts(child)
		for key in result: result[key]+=sub[key]
	return result
func lighting_settings(lighting: DungeonLighting) -> Dictionary:
	return {
		"sun_degrees":str(lighting.sun.rotation_degrees),
		"energy":lighting.sun.light_energy,
		"angular_distance":lighting.sun.light_angular_distance,
		"shadow_mode":lighting.sun.directional_shadow_mode,
		"shadow_distance":lighting.sun.directional_shadow_max_distance,
		"ambient":str(lighting.world.environment.ambient_light_color),
		"ambient_energy":lighting.world.environment.ambient_light_energy,
		"ssao":lighting.world.environment.ssao_enabled,
		"tonemap":lighting.world.environment.tonemap_mode,
		"ssao_quality":ProjectSettings.get_setting("rendering/environment/ssao/quality","default"),
		"shadow_filter":ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality","default")
	}
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	# Hardware/display details are included in JSON; no cap or scaling changes.
	for arg in OS.get_cmdline_user_args():
		if arg=="preview": preview=true
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
		var views: Dictionary={"ramp":data.ramp_segments[0].lower_buffer}
		for tile in data.tiles:
			if data.get_tile(tile)==DungeonData.TileType.FLOOR and data.get_elevation(tile)==0:
				views["lower"]=tile
				break
		views["upper"]=edge
		for tile in data.tiles:
			if data.get_tile(tile)==DungeonData.TileType.CORRIDOR and data.get_elevation(tile)==1 and not data.reserved_transitions.has(tile):
				views["bridge"]=tile
				break
		var lighting: DungeonLighting=main.get_node("LightingPresets")
		for pose in views:
			var location: Vector2i=views[pose]
			for stage in [0,1,2]:
				var before:=Snapshots.snapshot(data)
				var rng: int=TestDungeonFactory.rng.state
				lighting.apply_preset(stage)
				assert(before==Snapshots.snapshot(data) and rng==TestDungeonFactory.rng.state)
				main.player.setup(location,data,main.dungeon_renderer)
				main.refresh_fog()
				for i in range(6 if preview else 60): await process_frame
				assert(root.get_texture().get_size()==Vector2(1920,1080) and root.scaling_3d_scale==1.0)
				var intervals: Array=[]
				var cpu: Array=[]
				var gpu: Array=[]
				var draws: Array=[]
				var primitives: Array=[]
				var surface=main.dungeon_renderer.cave_background.ground_surface
				var palette_uploads: int=surface.stats.palette_uploads if surface!=null else 0
				var previous:=Time.get_ticks_usec()
				for i in range(1 if preview else 120):
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
				var result: Dictionary={"seed":seed_value,"pose":pose,"tile":str(location),"preset":stage,"lighting":lighting_settings(lighting),"frame_ms":stats(intervals),"render_cpu_ms":stats(cpu),"gpu_ms":stats(gpu),"draw_calls":stats(draws),"primitives":stats(primitives),"counts":counts(main),"backdrop":backdrop.diagnostics,"raw_frame_ms":intervals,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
				if true:
					result["detailed_bounds"]=str(backdrop.scenery_apron.detailed_bounds)
					result["apron_bounds"]=str(backdrop.scenery_apron.visual_bounds)
					result["guard_margin"]=backdrop.scenery_apron.guard_margin
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/lighting_presets/%s_%d_%s_%d.png"%["preview" if preview else "final",seed_value,pose,stage])
				# Controlled shadow-off differential is an estimate, not a pass timestamp.
				if seed_value==4 and pose in ["lower","upper"] and not preview:
					lighting.sun.shadow_enabled=false
					for i in range(30): await process_frame
					var off_gpu: Array=[]
					var off_draws: Array=[]
					for i in range(90):
						await process_frame
						off_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
						off_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
					result["shadows_off_gpu_ms"]=stats(off_gpu)
					result["shadows_off_draws"]=stats(off_draws)
					lighting.sun.shadow_enabled=true
				results.append(result)
				print("LIGHTING SAMPLE ",seed_value," ",pose," ",stage," frame=",result.frame_ms," GPU=",result.gpu_ms.mean," draws=",result.draw_calls.mean," meshes=",result.counts)
		main.free()
	var file:=FileAccess.open("res://.godot/lighting_presets/%s.json"%("preview" if preview else "benchmark"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"results":results},"\t"))
	file.close()
	print("PASS: fixed-seed A/B/C lighting, shadow differential, unchanged gameplay/RNG, 1080p")
	quit()
