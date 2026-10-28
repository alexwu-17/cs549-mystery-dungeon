extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("capture")

func save_capture(name: String) -> void:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/enemy_defeat/"+name+".png") == OK)

func capture() -> void:
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
		await save_capture("Stunky_"+pair[0])
	enemy.character_visual.finish_defeat()
	await save_capture("Stunky_gone")
	assert(main.retiring_enemies.is_empty())
	main.floor_number = 5
	main.load_test_floor()
	Helper.complete_introduction(main)
	var boss: Minotaur = main.boss
	main.player.setup(Vector2i(13,11),main.dungeon,main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	main.refresh_fog()
	boss.health.reset(3)
	main.player.basic_attack()
	boss.character_visual.defeat_animation.pause()
	assert(not main.hud.get_node("Screen/GameOver").visible)
	boss.character_visual._sample_defeat(0.01)
	await save_capture("Drapion_hurt_last")
	boss.character_visual._sample_defeat(0.10)
	await save_capture("Drapion_blink_off")
	assert(not main.hud.get_node("Screen/GameOver").visible)
	main.player.attack_leap.finish()
	boss.character_visual.finish_defeat()
	await save_capture("Demo_Complete")
	assert(not boss.visible and main.hud.get_node("Screen/GameOver").visible)
	main.free()
	await process_frame
	print("PASS: native 1080p Stunky Faint/blink/disappear and Drapion Hurt-last/blink followed by Demo Complete")
	quit()
