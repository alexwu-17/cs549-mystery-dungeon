extends SceneTree
## Normal-render capture scenarios; use -- --list or -- --scenario=NAME/all.
const Support = preload("res://tests/capture_support.gd")
const Helper = preload("res://tests/round_test_helper.gd")
const Snapshots = preload("res://tests/validate_terraces.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await Support.run(self, {"lighting": lighting_run, "sunlight": sunlight_run, "fog": fog_run, "mist": mist_run}, "lighting")

## Normal Forward+ only: three lighting presets, fixed seeds/poses, 1080p.
## Writes local captures and raw samples to ignored .godot/lighting_presets/.
var lighting_results: Array=[]
var lighting_preview: bool=false
func lighting_lighting_settings(lighting: DungeonLighting) -> Dictionary:
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
func lighting_run() -> bool:
	assert(DisplayServer.get_name()!="headless")
	# Hardware/display details are included in JSON; no cap or scaling changes.
	for arg in OS.get_cmdline_user_args():
		if arg=="preview": lighting_preview=true
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
				for i in range(6 if lighting_preview else 60): await process_frame
				assert(root.get_texture().get_size()==Vector2(1920,1080) and root.scaling_3d_scale==1.0)
				var intervals: Array=[]
				var cpu: Array=[]
				var gpu: Array=[]
				var draws: Array=[]
				var primitives: Array=[]
				var surface=main.dungeon_renderer.cave_background.ground_surface
				var palette_uploads: int=surface.stats.palette_uploads if surface!=null else 0
				var previous:=Time.get_ticks_usec()
				for i in range(1 if lighting_preview else 120):
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
				var result: Dictionary={"seed":seed_value,"pose":pose,"tile":str(location),"preset":stage,"lighting":lighting_lighting_settings(lighting),"frame_ms":Support.stats(intervals),"render_cpu_ms":Support.stats(cpu),"gpu_ms":Support.stats(gpu),"draw_calls":Support.stats(draws),"primitives":Support.stats(primitives),"counts":Support.counts(main),"backdrop":backdrop.diagnostics,"raw_frame_ms":intervals,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
				if true:
					result["detailed_bounds"]=str(backdrop.scenery_apron.detailed_bounds)
					result["apron_bounds"]=str(backdrop.scenery_apron.visual_bounds)
					result["guard_margin"]=backdrop.scenery_apron.guard_margin
				Support.save(self, "res://.godot/lighting_presets/%s_%d_%s_%d.png"%["preview" if lighting_preview else "final",seed_value,pose,stage])
				# Controlled shadow-off differential is an estimate, not a pass timestamp.
				if seed_value==4 and pose in ["lower","upper"] and not lighting_preview:
					lighting.sun.shadow_enabled=false
					for i in range(30): await process_frame
					var off_gpu: Array=[]
					var off_draws: Array=[]
					for i in range(90):
						await process_frame
						off_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
						off_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
					result["shadows_off_gpu_ms"]=Support.stats(off_gpu)
					result["shadows_off_draws"]=Support.stats(off_draws)
					lighting.sun.shadow_enabled=true
				lighting_results.append(result)
				print("LIGHTING SAMPLE ",seed_value," ",pose," ",stage," frame=",result.frame_ms," GPU=",result.gpu_ms.mean," draws=",result.draw_calls.mean," meshes=",result.counts)
		main.free()
	var file:=FileAccess.open("res://.godot/lighting_presets/%s.json"%("preview" if lighting_preview else "benchmark"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"results":lighting_results},"\t"))
	file.close()
	print("PASS: fixed-seed A/B/C lighting, shadow differential, unchanged gameplay/RNG, 1080p")
	return true

## Standalone Forward+ idle + real movement comparison. Never edits the project.
var sunlight_results: Array = []
var sunlight_traces: Dictionary = {}

func sunlight_run() -> bool:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute("res://.godot/sunlight_prototypes")
	root.size = Vector2i(1920,1080)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for seed_value in [4,17]:
		for mode in [0,1,2]:
			TestDungeonFactory.rng.seed = seed_value
			var main = load("res://scenes/demos/sunlight_demo.tscn").instantiate()
			root.add_child(main)
			Helper.complete_introduction(main)
			main.turn_rng.seed = 54903
			main.set_process_unhandled_input(false)
			main.player.set_process_unhandled_input(false)
			main.hud.get_node("Screen/PerformanceOverlay").hide()
			await process_frame
			await process_frame
			var effect: SunlightAtmosphere = main.get_node("SunlightAtmosphere")
			assert(effect.placement_safe and main.dungeon.is_bright(effect.receiver_tile))
			var before := Snapshots.snapshot(main.dungeon)
			var rng_state: int = TestDungeonFactory.rng.state
			effect.apply_mode(mode)
			assert(before == Snapshots.snapshot(main.dungeon) and rng_state == TestDungeonFactory.rng.state)
			for i in range(60): await process_frame
			assert(root.get_texture().get_size() == Vector2(1920,1080) and root.scaling_3d_scale == 1.0)
			var intervals: Array = []
			var gpu: Array = []
			var cpu: Array = []
			var draws: Array = []
			var updates := effect.mask_updates
			var previous := Time.get_ticks_usec()
			for i in range(180):
				await process_frame
				var now := Time.get_ticks_usec()
				intervals.append((now-previous)/1000.0)
				previous = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			assert(effect.mask_updates == updates)
			Support.save(self, "res://.godot/sunlight_prototypes/%d_%d.png"%[seed_value,mode])
			var anchor := effect.receiver
			var moving: Array = []
			var action_cpu: Array = []
			var trace: Array = []
			for step in range(4):
				var from: Vector2i = main.player.grid_position
				var choices := [Vector2i.RIGHT,Vector2i.LEFT] if step%2 == 0 else [Vector2i.LEFT,Vector2i.RIGHT]
				choices.append_array([Vector2i.DOWN,Vector2i.UP])
				var moved := false
				previous = Time.get_ticks_usec()
				var begin := previous
				for direction: Vector2i in choices:
					var next: Vector2i = from+direction
					if main.dungeon.get_tile(next) != DungeonData.TileType.FLOOR or not main.dungeon.can_traverse(from,next) or main.is_enemy_occupied(next): continue
					main.player.try_move(direction)
					moved = true
					break
				assert(moved and main.player.grid_position != from)
				action_cpu.append((Time.get_ticks_usec()-begin)/1000.0)
				for frame in range(600):
					await process_frame
					var now := Time.get_ticks_usec()
					moving.append((now-previous)/1000.0)
					previous = now
					if not main.resolving_turn: break
				assert(not main.resolving_turn and effect.receiver == anchor)
				trace.append([main.player.grid_position,main.player.health.current,main.dungeon.bright_tiles.duplicate(),main.dungeon.discovered_tiles.duplicate()])
				for enemy in main.enemies: trace.append([enemy.grid_position,enemy.health.current])
			if mode == 0: sunlight_traces[seed_value] = trace
			else: assert(sunlight_traces[seed_value] == trace)
			var result := {"seed":seed_value,"mode":mode,"spawn":str(main.dungeon.player_spawn),"anchor":str(anchor),"direction":str(effect.direction),"room_width":effect.effective_width,"room_length":effect.effective_length,"idle_ms":Support.stats(intervals),"gpu_ms":Support.stats(gpu),"render_cpu_ms":Support.stats(cpu),"draws":Support.stats(draws),"movement_ms":Support.stats(moving),"action_request_cpu_ms":Support.stats(action_cpu),"raw_idle_ms":intervals,"raw_movement_ms":moving,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
			sunlight_results.append(result)
			print("SUNLIGHT ",seed_value," mode=",mode," idle=",result.idle_ms," GPU=",result.gpu_ms.mean," moving=",result.movement_ms)
			main.free()
	var file := FileAccess.open("res://.godot/sunlight_prototypes/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":sunlight_results,"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"volume_size":ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_size"),"volume_depth":ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_depth")},"\t"))
	file.close()
	print("PASS: 1080p fixed-seed atmosphere comparison, idle and four native movement turns, identical gameplay/fog traces, static anchors and zero idle mask uploads")
	return true

func fog_capture() -> Image:
	for i in range(3): await process_frame
	return Support.image(self)
func fog_run() -> bool:
	root.size=Vector2i(1920,1080)
	TestDungeonFactory.rng.seed=4
	var main=load("res://scenes/demos/sunlight_demo.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	for i in range(15): await process_frame
	var effect=main.get_node("SunlightAtmosphere")
	main.hud.hide()
	main.process_mode=Node.PROCESS_MODE_DISABLED
	effect.ground_mist.material.set_shader_parameter("preview_time",0.0)
	var snapshot=Snapshots.snapshot(main.dungeon)
	var rng=main.turn_rng.state
	var hidden:Array=[]
	for enemy in main.enemies:
		if not enemy.visible: hidden.append(enemy)
	assert(not hidden.is_empty(),"Fixture must include hidden enemies")
	effect.mesh_effect.hide()
	var off=await fog_capture()
	effect.mesh_effect.show()
	var on=await fog_capture()
	var dark_changed:=0
	for y in range(on.get_height()):
		for x in range(on.get_width()):
			var a=off.get_pixel(x,y)
			var b=on.get_pixel(x,y)
			if maxf(a.r,maxf(a.g,a.b))<0.15 and b.r-a.r>0.01: dark_changed+=1
	assert(dark_changed>20,"Beam must render across dark backgrounds")
	assert(Snapshots.snapshot(main.dungeon)==snapshot and main.turn_rng.state==rng)
	for enemy in hidden: assert(not enemy.visible)
	Support.save_image(on, "res://.godot/sunlight_prototypes/continuous_fog_beam.png")
	print("PASS: beam crosses dark background pixels=",dark_changed,"; dungeon/fog/RNG unchanged, hidden enemies remain hidden")
	main.free()
	return true

func mist_difference(a:Image,b:Image) -> float:
	var aa=a.get_data()
	var bb=b.get_data()
	var total:=0.0
	for i in range(aa.size()): total+=abs(int(aa[i])-int(bb[i]))
	return total/aa.size()
func mist_capture() -> Image:
	for i in range(3): await process_frame
	return Support.image(self)
func mist_run() -> bool:
	root.size=Vector2i(1920,1080)
	TestDungeonFactory.rng.seed=4
	var main=load("res://scenes/demos/sunlight_demo.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	for i in range(30): await process_frame
	main.hud.hide()
	main.process_mode=Node.PROCESS_MODE_DISABLED
	var ground=main.get_node("SunlightAtmosphere").ground_mist
	var uploads=ground.uploads
	ground.material.set_shader_parameter("preview_time",0.0)
	var a=await mist_capture()
	var frozen=await mist_capture()
	assert(mist_difference(a,frozen)==0.0,"Frozen scene must match exactly")
	ground.material.set_shader_parameter("preview_time",3.0)
	var b=await mist_capture()
	var delta=mist_difference(a,b)
	assert(delta>0.01,"Mist alone must visibly change the frame")
	Support.save_image(a, "res://.godot/sunlight_prototypes/mist_motion_0.png")
	Support.save_image(b, "res://.godot/sunlight_prototypes/mist_motion_3.png")
	ground.material.set_shader_parameter("preview_time",-1.0)
	var live_a=await mist_capture()
	# Advance rendered shader time explicitly even when the capture window is
	# inactive. Merely awaiting process frames need not submit a GPU frame.
	for i in range(180):
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	var live_b=await mist_capture()
	var live_delta=mist_difference(live_a,live_b)
	assert(live_delta>0.01, "Engine-time mist must animate; image delta=%f" % live_delta)
	assert(ground.uploads==uploads, "Idle mist must not upload its mask")
	print("PASS: isolated fog animation; frozen delta=0, 3s fog-only delta=",delta," live idle delta=",live_delta," (mean 8-bit channel levels); no mask uploads")
	main.free()
	return true
