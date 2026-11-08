extends SceneTree
## Normal-render capture scenarios; use -- --list or -- --scenario=NAME/all.
const Support = preload("res://tests/capture_support.gd")
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await Support.run(self, {"sprites": sprites_capture, "motion": motion_capture, "boss": boss_capture, "defeat": defeat_capture}, "sprites")

func sprites_capture() -> bool:
	var main = Support.character_fixture(self)
	var actors := [main.player,main.enemies[0],main.boss]
	DirAccess.make_dir_recursive_absolute("res://.godot/pokemon_validation")
	for direction in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
		for action in ["Idle","Walk","Attack","Hurt"]:
			for actor in actors:
				var visual = actor.character_visual
				visual.set_process(false)
				visual.facing = direction
				visual.play_clip(action,true)
				# Attack's authored hit pose, otherwise initial source frame.
				if action == "Attack":
					for index in range(visual.clips.Attack.hit_frame):
						visual.clip_time += visual.clips.Attack.durations[index]
					visual.frame_index = -1
					visual.apply_frame()
			for frame in range(3): await process_frame
			var path: String = "res://.godot/pokemon_validation/"+str(direction.x)+"_"+str(direction.y)+"_"+action+".png"
			Support.save(self, path)
	main.free()
	await process_frame
	print("PASS: rendered 1920x1080 Pokémon cardinal/action captures")
	return true

func motion_capture() -> bool:
	var main = Support.character_fixture(self)
	var actors := [main.player,main.enemies[0],main.boss]
	DirAccess.make_dir_recursive_absolute("res://.godot/pokemon_validation")
	for pair in [["Idle",0],["Idle",3],["Idle",4],["Attack",0],["Attack",3],["Attack",5],["Attack",8],["Attack",9]]:
		var action: String = pair[0]
		for actor in actors:
			var visual = actor.character_visual
			visual.set_process(false)
			visual.facing = Vector2i.DOWN
			visual.play_clip(action,true)
			for index in range(mini(pair[1],visual.clips[action].durations.size()-1)):
				visual.clip_time += visual.clips[action].durations[index]
			visual.clip_time += 0.00001
			visual.frame_index = -1
			visual.apply_frame()
		for frame in range(3): await process_frame
		Support.save(self, "res://.godot/pokemon_validation/native_%s_%s.png" % [action,pair[1]])
	main.free()
	await process_frame
	print("PASS: rendered native idle-jump and attack anticipation/travel/recovery source frames")
	return true

func boss_save_capture(name: String) -> void:
	for frame in range(3): await process_frame
	Support.save(self, "res://.godot/drapion_swing/"+name+".png")

func boss_capture() -> bool:
	root.size = Vector2i(1920,1080)
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	Helper.complete_introduction(main)
	main.player.invincible = true
	var boss: Minotaur = main.boss
	var visual = boss.character_visual
	visual.set_process(false)
	DirAccess.make_dir_recursive_absolute("res://.godot/drapion_swing")
	for direction: Vector2i in DungeonData.CARDINALS:
		boss.clear_charge()
		boss.state = Minotaur.State.HUNTING
		visual.cancel()
		boss.facing = direction
		visual.face(direction)
		var target: Vector2i = boss.attack_tiles()[0]
		main.player.setup(target,main.dungeon,main.dungeon_renderer)
		main.refresh_fog()
		boss.take_turn(target)
		visual._process(0.101)
		var name := "%s_%s_" % [direction.x,direction.y]
		await boss_save_capture(name+"Charge")
		boss.take_turn(target)
		visual.animation.pause()
		var hit := 0.00001
		for frame in range(visual.clips[visual.clip].hit_frame): hit += float(visual.clips[visual.clip].durations[frame])
		visual.animation.custom_step(hit)
		await boss_save_capture(name+"Swing")
		main.player.hide()
		await boss_save_capture(name+"Swing_pose")
		main.player.show()
		visual.animation.custom_step(visual.clips[visual.clip].total)
		assert(not visual.active and visual.action == "Idle")
		await boss_save_capture(name+"Recharge")
		boss.take_turn(target)
		assert(boss.state == Minotaur.State.HUNTING)
	main.free()
	await process_frame
	print("PASS: native 1920x1080 Drapion Charge, Strike, Idle recharge, four cardinal two-tile line warnings and unobscured swing poses")
	return true

func defeat_save_capture(name: String) -> void:
	for frame in range(3): await process_frame
	Support.save(self, "res://.godot/enemy_defeat/"+name+".png")

func defeat_capture() -> bool:
	root.size = Vector2i(1920,1080)
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	DirAccess.make_dir_recursive_absolute("res://.godot/enemy_defeat")
	var data := DungeonData.new()
	data.rooms = [Rect2i(-2,-2,7,5)]
	data.room_elevations = [0]
	for y in range(-2,3):
		for x in range(-2,5): data.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i.RIGHT]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
	main.player.facing = Vector2i.RIGHT
	main.refresh_fog()
	var enemy: Skeleton = main.enemies[0]
	enemy.health.reset(3)
	main.player.basic_attack()
	enemy.character_visual.defeat_animation.pause()
	main.player.attack_leap.finish()
	assert(main.enemies.is_empty() and main.retiring_enemies.size() == 1)
	for pair in [["start",0.01],["blink_off",0.10],["collapse",0.35],["last",0.61]]:
		enemy.character_visual._sample_defeat(pair[1])
		await defeat_save_capture("Stunky_"+pair[0])
	enemy.character_visual.finish_defeat()
	await defeat_save_capture("Stunky_gone")
	assert(main.retiring_enemies.is_empty())
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	Helper.complete_introduction(main)
	var boss: Minotaur = main.boss
	main.player.setup(Vector2i(13,10),main.dungeon,main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	main.refresh_fog()
	boss.health.reset(3)
	main.player.basic_attack()
	boss.character_visual.defeat_animation.pause()
	assert(not main.hud.get_node("Screen/GameOver").visible)
	boss.character_visual._sample_defeat(0.01)
	await defeat_save_capture("Drapion_hurt_last")
	boss.character_visual._sample_defeat(0.10)
	await defeat_save_capture("Drapion_blink_off")
	assert(not main.hud.get_node("Screen/GameOver").visible)
	main.player.attack_leap.finish()
	boss.character_visual.finish_defeat()
	await defeat_save_capture("Demo_Complete")
	assert(not boss.visible and main.hud.get_node("Screen/GameOver").visible)
	main.free()
	await process_frame
	print("PASS: native 1080p Stunky Faint/blink/disappear and Drapion Hurt-last/blink followed by Demo Complete")
	return true
