extends SceneTree
## Standalone Forward+ idle + real movement comparison. Never edits the project.
const Helper = preload("res://tests/round_test_helper.gd")
const Snapshots = preload("res://tests/validate_terraces.gd")
var results: Array = []
var traces: Dictionary = {}
func _initialize() -> void: call_deferred("run")

func stats(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var over := 0
	for value in values:
		total += value
		if value > 16.67: over += 1
	return {"mean":total/values.size(),"p95":sorted[ceili(values.size()*0.95)-1],"p99":sorted[ceili(values.size()*0.99)-1],"max":sorted.back(),"over_budget_percent":100.0*over/values.size(),"frames":values.size()}

func run() -> void:
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
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/sunlight_prototypes/%d_%d.png"%[seed_value,mode])
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
			if mode == 0: traces[seed_value] = trace
			else: assert(traces[seed_value] == trace)
			var result := {"seed":seed_value,"mode":mode,"spawn":str(main.dungeon.player_spawn),"anchor":str(anchor),"direction":str(effect.direction),"room_width":effect.effective_width,"room_length":effect.effective_length,"idle_ms":stats(intervals),"gpu_ms":stats(gpu),"render_cpu_ms":stats(cpu),"draws":stats(draws),"movement_ms":stats(moving),"action_request_cpu_ms":stats(action_cpu),"raw_idle_ms":intervals,"raw_movement_ms":moving,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
			results.append(result)
			print("SUNLIGHT ",seed_value," mode=",mode," idle=",result.idle_ms," GPU=",result.gpu_ms.mean," moving=",result.movement_ms)
			main.free()
	var file := FileAccess.open("res://.godot/sunlight_prototypes/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":results,"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"volume_size":ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_size"),"volume_depth":ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_depth")},"\t"))
	file.close()
	print("PASS: 1080p fixed-seed atmosphere comparison, idle and four native movement turns, identical gameplay/fog traces, static anchors and zero idle mask uploads")
	quit()
