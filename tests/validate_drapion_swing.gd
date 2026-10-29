extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	Helper.complete_introduction(main)
	var boss: Minotaur = main.boss
	var visual = boss.character_visual
	visual.set_process(false)
	assert(visual.clips.has("Charge") and visual.clips.has("Strike"))
	assert(is_equal_approx(visual.clips.Charge.total,20.0/60.0))
	assert(is_equal_approx(visual.clips.Strike.total,27.0/60.0))
	var origin := boss.position
	var footprint := boss.footprint()
	var events: Array[int] = []
	boss.attack_requested.connect(func(damage: int): events.append(damage))
	var patterns := {
		Vector2i.DOWN: [Vector2i(0,1),Vector2i(0,2)],
		Vector2i.UP: [Vector2i(0,-1),Vector2i(0,-2)],
		Vector2i.RIGHT: [Vector2i(1,0),Vector2i(2,0)],
		Vector2i.LEFT: [Vector2i(-1,0),Vector2i(-2,0)]}
	for facing: Vector2i in DungeonData.CARDINALS:
		boss.clear_charge()
		boss.state = Minotaur.State.HUNTING
		boss.health.reset(30)
		visual.cancel()
		boss.facing = facing
		visual.face(facing)
		var region := boss.attack_tiles()
		assert(region.size() == 2)
		for offset: Vector2i in patterns[facing]: assert(region.has(boss.grid_position+offset))
		var target: Vector2i = region[0]
		main.player.setup(target,main.dungeon,main.dungeon_renderer)
		main.player.health.reset(20)
		var before := events.size()
		boss.take_turn(target)
		assert(boss.state == Minotaur.State.CHARGING and events.size() == before)
		assert(boss.facing == facing and boss.threatened_tiles == region and boss.markers.size() == 2)
		assert(visual.action == "Charge" and visual.clip == "Charge" and not visual.active)
		assert(visual.sprite.texture.atlas.resource_path.ends_with("/Charge-Anim.png"))
		visual._process(2.0/60.0+0.00001)
		assert(visual.action == "Charge" and visual.frame_index == 1)
		# A surviving hit briefly interrupts Charge, then restores its waiting pose.
		boss.receive_damage(1)
		assert(visual.action == "Hurt")
		visual._process(visual.clips.Hurt.total+0.001)
		assert(visual.action == "Charge")
		boss.take_turn(target)
		assert(boss.state == Minotaur.State.COOLDOWN and boss.markers.is_empty())
		assert(events.size() == before+1 and events.back() == 18 and main.player.health.current == 2)
		assert(visual.action == "Swing" and visual.clip == "Strike" and visual.active)
		assert(visual.sprite.texture.atlas.resource_path.ends_with("/Strike-Anim.png"))
		visual.animation.pause()
		visual.animation.custom_step(2.0/60.0+0.00001)
		assert(visual.frame_index == 1 and visual.active)
		visual.animation.custom_step(25.0/60.0-0.00002)
		assert(visual.active) # Last source frame still holds its original duration.
		visual.animation.custom_step(0.001)
		assert(not visual.active and visual.action == "Idle" and events.size() == before+1)
		assert(boss.position == origin and boss.footprint() == footprint)
		boss.take_turn(target)
		assert(boss.state == Minotaur.State.HUNTING and visual.action == "Idle" and events.size() == before+1)
		# Facing and markers remain locked after a dodge; Swing still plays on a miss.
		boss.take_turn(target)
		var locked := boss.threatened_tiles.duplicate()
		var escaped := boss.grid_position-facing*3
		assert(not locked.has(escaped))
		boss.take_turn(escaped)
		assert(events.size() == before+1 and boss.facing == facing)
		assert(visual.active and visual.action == "Swing")
		visual.finish()
		assert(visual.action == "Idle")
	# No second occupied row: all attacks start directly beyond the anchor.
	for direction in [Vector2i.LEFT,Vector2i.RIGHT]:
		var target: Vector2i = boss.grid_position+direction
		boss.face_player(target)
		assert(boss.facing == direction)
		assert(boss.attack_tiles() == [target,target+direction])
		assert(not boss.attack_tiles().has(target+Vector2i.DOWN))
	# Arena boundaries clip warning cells to real floor without widening the attack.
	for tile: Vector2i in main.dungeon.tiles:
		if not main.dungeon.is_walkable(tile): continue
		boss.grid_position = tile
		for direction: Vector2i in DungeonData.CARDINALS:
			boss.facing = direction
			assert(boss.attack_tiles().size() <= 2)
			for threatened in boss.attack_tiles():
				assert(main.dungeon.is_walkable(threatened) and not boss.footprint().has(threatened))
	# Restart cancels the native lethal Swing and suppresses stale overlay completion.
	main.start_new_run()
	Helper.complete_introduction(main)
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	Helper.complete_introduction(main)
	boss = main.boss
	main.player.setup(Vector2i(13,10),main.dungeon,main.dungeon_renderer)
	main.player.health.reset(18)
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	Helper.complete(main)
	assert(boss.character_visual.action == "Charge")
	main.player.basic_attack()
	main.player.attack_leap.finish()
	assert(main.game_over and boss.character_visual.active and boss.character_visual.action == "Swing")
	assert(not main.hud.get_node("Screen/GameOver").visible)
	var old_boss: WeakRef = weakref(boss)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(old_boss.get_ref() == null and not main.game_over and main.player.health.current == 20)
	assert(not main.hud.get_node("Screen/GameOver").visible)
	main.free()
	await process_frame
	print("PASS: Drapion four-direction two-tile line telegraph, frozen aim/dodge, native Charge/Strike timing, Hurt recovery, Idle recharge, single 18-damage event, fixed footprint and lethal/restart cancellation")
	quit()
