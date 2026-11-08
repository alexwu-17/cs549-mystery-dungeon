extends SceneTree
## Normal-render capture scenarios; use -- --list or -- --scenario=NAME/all.
const Support = preload("res://tests/capture_support.gd")
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await Support.run(self, {"attacks": attacks_capture, "poses": poses_capture}, "attacks")

func attacks_capture() -> bool:
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
				var path := "res://.godot/ramp_attacks/%s_%s_%s_%s.png" % [uphill.x,uphill.y,sign_value,"player" if player_attacks else "enemy"]
				if exits: path = path.replace(".png","_exit.png")
				if edge: path = path.replace(".png","_edge.png")
				Support.save(self, path)
				# An additional view hides the target so attack contact cannot obscure the pose.
				var target = main.enemies[0] if player_attacks else main.player
				target.hide()
				for frame in range(3): await process_frame
				Support.save(self, path.replace(".png","_pose.png"))
				target.show()
				actor.attack_leap.finish()
	main.free()
	await process_frame
	print("PASS: 32 native 1080p interaction/pose uphill/downhill ramp attack captures")
	return true

func poses_capture() -> bool:
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
				var path := "res://.godot/front_ramps/%s_%s_%s_%s_%s.png" % [label,uphill.x,uphill.y,"player" if player_visible else "enemy",pair[0]]
				Support.save(self, path)
	main.free()
	await process_frame
	print("PASS: 32 native 1080p front/side ramp pose captures ",label)
	return true
