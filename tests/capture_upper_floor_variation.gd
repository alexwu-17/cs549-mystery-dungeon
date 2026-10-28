extends SceneTree
const Helper=preload("res://tests/round_test_helper.gd")
const Snapshots=preload("res://tests/validate_terraces.gd")
func _initialize(): call_deferred("run")
func run():
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
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/sunlight_prototypes/upper_rotated_%s.png"%str(enabled))
		print("ROTATION enabled=",enabled," mean=",mean/120," p95=",samples[113]," gpu=",gpu/120," draws=",draws/120," primitives=",primitives/120," renderer nodes=",count)
	main.free()
	print("PASS: fixed-seed 1080p quarter-turn comparison, unchanged nodes/draws/topology")
	quit()
