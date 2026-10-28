extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1920,1080)
	var exits := "--exits" in OS.get_cmdline_user_args()
	var edge := "--edge" in OS.get_cmdline_user_args()
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	DirAccess.make_dir_recursive_absolute("res://.godot/ramp_attacks")
	for uphill: Vector2i in DungeonData.CARDINALS:
		for sign_value in [-1,1]:
			for player_attacks in [true,false]:
				main.cancel_round()
				var data := DungeonData.new()
				data.add_ramp(Vector2i.ZERO,uphill,0)
				var source_index := (1 if sign_value < 0 else 3) if exits else 2
				data.player_spawn = uphill * (source_index if player_attacks else source_index+sign_value)
				data.enemy_spawns = [uphill*(source_index+sign_value if player_attacks else source_index)]
				main.dungeon = data
				assert(main.dungeon_renderer.render_dungeon(data))
				main.spawn_test_enemies()
				main.player.setup(data.player_spawn,data,main.dungeon_renderer)
				main.refresh_fog()
				var actor = main.player if player_attacks else main.enemies[0]
				actor.facing = uphill * sign_value
				actor.character_visual.face(actor.facing)
				actor.attack_leap.play(actor.facing)
				actor.attack_leap.animation.pause()
				var info: Dictionary = actor.character_visual.clips.Attack
				var time := 0.00001
				for frame in range(info.hit_frame): time += float(info.durations[frame])
				if edge:
					var rush := 0.0
					for frame in range(info.rush_frame): rush += float(info.durations[frame])
					time = (time+rush)/2.0
				actor.attack_leap._sample(time/actor.attack_leap.duration)
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				var path := "res://.godot/ramp_attacks/%s_%s_%s_%s.png" % [uphill.x,uphill.y,sign_value,"player" if player_attacks else "enemy"]
				if exits: path = path.replace(".png","_exit.png")
				if edge: path = path.replace(".png","_edge.png")
				assert(root.get_texture().get_image().save_png(path) == OK)
				# An additional view hides the target so attack contact cannot obscure the pose.
				var target = main.enemies[0] if player_attacks else main.player
				target.hide()
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(path.replace(".png","_pose.png")) == OK)
				target.show()
				actor.attack_leap.finish()
	main.free()
	await process_frame
	print("PASS: 32 native 1080p interaction/pose uphill/downhill ramp attack captures")
	quit()
