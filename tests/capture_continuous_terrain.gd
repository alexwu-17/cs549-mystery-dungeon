extends SceneTree
## Normal Forward+ only: four reversible stages, fixed seeds/poses, 1080p.
## Writes local captures and raw samples to ignored .godot/continuous_terrain/.
const Helper=preload("res://tests/round_test_helper.gd")
const Snapshots=preload("res://tests/validate_terraces.gd")
var results: Array=[]
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
func run() -> void:
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
				var result: Dictionary={"seed":seed_value,"pose":pose,"tile":str(location),"stage":stage,"frame_ms":stats(intervals),"render_cpu_ms":stats(cpu),"gpu_ms":stats(gpu),"draw_calls":stats(draws),"primitives":stats(primitives),"counts":counts(main),"backdrop":backdrop.diagnostics,"raw_frame_ms":intervals,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
				if true:
					result["detailed_bounds"]=str(backdrop.scenery_apron.detailed_bounds)
					result["apron_bounds"]=str(backdrop.scenery_apron.visual_bounds)
					result["guard_margin"]=backdrop.scenery_apron.guard_margin
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/continuous_terrain/%d_%s_%d.png"%[seed_value,pose,stage])
				results.append(result)
				print("TERRAIN SAMPLE ",seed_value," ",pose," ",stage," frame=",result.frame_ms," GPU=",result.gpu_ms.mean," draws=",result.draw_calls.mean," meshes=",result.counts)
		main.free()
	var file:=FileAccess.open("res://.godot/continuous_terrain/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"results":results},"\t"))
	file.close()
	print("PASS: short fixed-seed stages 1/2/3/4 A/B, unchanged gameplay/RNG, 1080p")
	quit()
