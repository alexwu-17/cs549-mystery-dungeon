extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("capture")

func save_capture(name: String) -> void:
	for frame in range(3): await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png("res://.godot/drapion_swing/"+name+".png") == OK)

func capture() -> void:
	root.size = Vector2i(1920,1080)
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	main.floor_number = 5
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
		await save_capture(name+"Charge")
		boss.take_turn(target)
		visual.animation.pause()
		var hit := 0.00001
		for frame in range(visual.clips[visual.clip].hit_frame): hit += float(visual.clips[visual.clip].durations[frame])
		visual.animation.custom_step(hit)
		await save_capture(name+"Swing")
		main.player.hide()
		await save_capture(name+"Swing_pose")
		main.player.show()
		visual.animation.custom_step(visual.clips[visual.clip].total)
		assert(not visual.active and visual.action == "Idle")
		await save_capture(name+"Recharge")
		boss.take_turn(target)
		assert(boss.state == Minotaur.State.HUNTING)
	main.free()
	await process_frame
	print("PASS: native 1920x1080 Drapion Charge, Strike, Idle recharge, four cardinal two-tile line warnings and unobscured swing poses")
	quit()
