extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1920,1080)
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	data.rooms = [Rect2i(-3,-3,9,8)]
	data.room_elevations = [0]
	for y in range(-3,5):
		for x in range(-3,6):
			data.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i(2,0)]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	var boss = load("res://scenes/enemies/minotaur.tscn").instantiate()
	main.entities.add_child(boss)
	boss.setup(Vector2i(3,-2),data,main.dungeon_renderer)
	main.boss = boss
	main.refresh_fog()
	var actors := [main.player,main.enemies[0],boss]
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
			await RenderingServer.frame_post_draw
			var path: String = "res://.godot/pokemon_validation/"+str(direction.x)+"_"+str(direction.y)+"_"+action+".png"
			assert(root.get_texture().get_image().save_png(path) == OK)
	main.free()
	await process_frame
	print("PASS: rendered 1920x1080 Pokémon cardinal/action captures")
	quit()
