extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1920,1080)
	var label := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	DirAccess.make_dir_recursive_absolute("res://.godot/front_ramps")
	for uphill: Vector2i in DungeonData.CARDINALS:
		main.cancel_round()
		var data := DungeonData.new()
		data.add_ramp(Vector2i.ZERO,uphill,0)
		data.player_spawn = uphill*2
		data.enemy_spawns = [uphill*2]
		main.dungeon = data
		main.dungeon_renderer.render_dungeon(data)
		main.spawn_test_enemies()
		main.player.setup(data.player_spawn,data,main.dungeon_renderer)
		main.refresh_fog()
		for player_visible in [true,false]:
			main.player.visible = player_visible
			main.enemies[0].visible = not player_visible
			var actor = main.player if player_visible else main.enemies[0]
			var visual = actor.character_visual
			visual.set_process(false)
			visual.facing = -uphill
			for pair in [["Idle",0],["Walk",2],["Hurt",1],["Faint",3]]:
				visual.play_clip(pair[0],true)
				for index in range(pair[1]): visual.clip_time += visual.clips[pair[0]].durations[index]
				visual.clip_time += 0.00001
				visual.frame_index = -1
				visual.apply_frame()
				for frame in range(3): await process_frame
				RenderingServer.force_draw(false)
				var path := "res://.godot/front_ramps/%s_%s_%s_%s_%s.png" % [label,uphill.x,uphill.y,"player" if player_visible else "enemy",pair[0]]
				assert(root.get_texture().get_image().save_png(path) == OK)
	main.free()
	await process_frame
	print("PASS: 32 native 1080p front/side ramp pose captures ",label)
	quit()
