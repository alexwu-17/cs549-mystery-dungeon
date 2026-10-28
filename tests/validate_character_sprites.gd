extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
var seen: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	load("res://tests/round_test_helper.gd").use_placeholder_visuals(main)
	root.add_child(main)
	Helper.complete_introduction(main)
	var visual: CharacterVisual = main.player.character_visual
	var sprite: Sprite3D = visual.sprite
	var rect := sprite.get_item_rect()
	var feet := Vector2(rect.position.x + visual.foot_anchor.x, rect.end.y - visual.foot_anchor.y)
	print("SPRITE FEET local pixels: ", feet, " offset=", sprite.offset)
	assert(feet.is_zero_approx())
	await process_frame
	var bounds := sprite.get_aabb()
	assert(is_zero_approx(bounds.end.y - visual.foot_anchor.y * sprite.pixel_size))
	assert(is_equal_approx(main.player.position.y, main.dungeon_renderer.get_entity_world_position(main.player.grid_position).y))
	assert(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	for pair in [[Vector2i.DOWN,"front"],[Vector2i.UP,"back"],[Vector2i.LEFT,"left"],[Vector2i.RIGHT,"right"]]:
		main.player.facing = pair[0]
		visual.face(pair[0])
		assert(visual.current_frame == pair[1])
		main.player.attack_leap.play(pair[0])
		assert(visual.current_frame == "attack_" + pair[1])
		main.player.attack_leap.finish()
		assert(visual.current_frame == pair[1])
	var enemy: Skeleton = main.enemies[0]
	assert(is_zero_approx(enemy.character_visual.sprite.get_item_rect().end.y - enemy.character_visual.foot_anchor.y))
	enemy.dungeon_data.set_tile(enemy.grid_position + Vector2i.RIGHT, DungeonData.TileType.FLOOR, enemy.dungeon_data.get_elevation(enemy.grid_position))
	enemy.take_turn(enemy.grid_position + Vector2i.RIGHT,{})
	assert(enemy.character_visual.current_frame == "attack_right")
	enemy.attack_leap.finish()
	assert(enemy.character_visual.current_frame == "right")
	main.floor_number = 5
	main.load_test_floor()
	var boss: Minotaur = main.boss
	assert(is_zero_approx(boss.character_visual.sprite.get_item_rect().end.y - boss.character_visual.foot_anchor.y))
	main.player.setup(Vector2i(13,11),main.dungeon,main.dungeon_renderer)
	main.player.health.reset(18)
	boss.take_turn(main.player.grid_position)
	assert(boss.character_visual.current_frame == "charge" and boss.state == Minotaur.State.CHARGING)
	var position_before := boss.position
	var footprint_before := boss.footprint()
	boss.character_visual.frame_changed.connect(func(name):
		if name.begins_with("spin_"): seen.append(name))
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	main.player.attack_leap.finish()
	assert(main.game_over and main.player.health.current == 0 and boss.character_visual.active)
	assert(not main.hud.get_node("Screen/GameOver").visible and main.resolving_turn)
	assert(boss.markers.is_empty())
	boss.character_visual.animation.pause()
	for index in range(8):
		assert(boss.character_visual.current_frame == "spin_%02d" % (index+1))
		boss.character_visual.animation.custom_step(0.080001)
	assert(seen == ["spin_01","spin_02","spin_03","spin_04","spin_05","spin_06","spin_07","spin_08"])
	assert(not boss.character_visual.active and boss.position == position_before and boss.footprint() == footprint_before)
	assert(main.hud.get_node("Screen/GameOver").visible and not main.resolving_turn)
	assert(boss.character_visual.current_frame == boss.character_visual.direction_name())
	# Restart during a lethal spin must suppress the old overlay callback.
	main.start_new_run()
	Helper.complete_introduction(main)
	main.floor_number = 5
	main.load_test_floor()
	boss = main.boss
	main.player.setup(Vector2i(13,11),main.dungeon,main.dungeon_renderer)
	main.player.health.reset(18)
	boss.take_turn(main.player.grid_position)
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	main.player.attack_leap.finish()
	assert(boss.character_visual.active)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(not main.game_over and not main.hud.get_node("Screen/GameOver").visible and not main.resolving_turn)
	main.floor_number = 5
	main.load_test_floor()
	boss = main.boss
	main.player.setup(Vector2i(13,11),main.dungeon,main.dungeon_renderer)
	boss.take_turn(main.player.grid_position)
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	main.player.attack_leap.finish()
	assert(boss.character_visual.active and not main.game_over)
	main.free()
	await process_frame
	print("PASS: sprite anchors/directions/attack restoration, boss charge/spin ordering/0.64s, occupancy, lethal overlay ordering and cancellation")
	quit()
