extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func save_capture(name: String) -> void:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/pokemon_validation/"+name+".png") == OK)

func validate() -> void:
	root.size = Vector2i(1920,1080)
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	data.rooms = [Rect2i(-2,-2,5,5), Rect2i(7,-2,5,5)]
	data.room_elevations = [0,0]
	for room in data.rooms:
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x):
				data.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR)
	for x in range(3,7): data.set_tile(Vector2i(x,0),DungeonData.TileType.CORRIDOR)
	data.enemy_spawns = [Vector2i(1,0)]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
	var boss = load("res://scenes/enemies/minotaur.tscn").instantiate()
	main.entities.add_child(boss)
	boss.setup(Vector2i(9,0),data,main.dungeon_renderer)
	main.boss = boss
	main.refresh_fog()
	assert(main.enemies[0].visible and not boss.visible)
	assert(not boss.character_visual.sprite.is_visible_in_tree())
	await save_capture("visibility_first_room")
	main.player.setup(Vector2i(8,0),data,main.dungeon_renderer)
	main.refresh_fog()
	assert(not main.enemies[0].visible and boss.visible)
	assert(not main.enemies[0].character_visual.sprite.is_visible_in_tree())
	await save_capture("visibility_second_room")
	# Every source frame's atlas/mask remains consistent with actual texture readback.
	for actor in [main.player,main.enemies[0],boss]:
		var visual = actor.character_visual
		visual.set_process(false)
		assert(visual.sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
		var original_size: float = visual.original_pixel_size
		for name in visual.clips:
			var clip: Dictionary = visual.clips[name]
			for row in clip.rows:
				for frame in clip.rows[row]:
					var atlas: AtlasTexture = frame.texture
					var image := atlas.get_image()
					assert(image.get_size() == Vector2i(atlas.region.size))
					var expected := PackedVector2Array()
					for y in range(9):
						for x in range(9):
							var uv := Vector2((x+0.5)/9.0,(y+0.5)/9.0)
							if image.get_pixelv(Vector2i(Vector2(image.get_size())*uv)).a > 0.5: expected.append(uv)
					assert(atlas.get_meta("pokemon_opaque_uvs") == expected)
		assert(visual.original_pixel_size == original_size)
	# Use real Chimchar samples against an upper platform in front of the player.
	var obstruction := DungeonData.new()
	obstruction.rooms = [Rect2i(-1,-1,3,3),Rect2i(-1,2,3,1)]
	obstruction.room_elevations = [0,1]
	for id in range(2):
		var room: Rect2i = obstruction.rooms[id]
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x):
				obstruction.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR,id)
	main.dungeon = obstruction
	main.dungeon_renderer.render_dungeon(obstruction)
	main.player.setup(Vector2i.ZERO,obstruction,main.dungeon_renderer)
	main.refresh_fog()
	var player_visual = main.player.character_visual
	player_visual.facing = Vector2i.DOWN
	for name in ["Idle","Walk","Attack","Hurt"]:
		player_visual.play_clip(name,true)
		main.update_presentation()
		var count := 0
		var fog_before: Array = []
		for item in main.dungeon_renderer.fog_visuals:
			fog_before.append(item.fog_state)
			if item.occluded:
				count += 1
				if item.wall or item.get("filler",false):
					assert(item.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				else: assert(not item.mesh.visible)
		assert(count > 0)
		main.dungeon_renderer.apply_fog()
		for index in range(fog_before.size()):
			assert(main.dungeon_renderer.fog_visuals[index].fog_state == fog_before[index])
		await save_capture("occlusion_"+name)
	main.free()
	await process_frame
	print("PASS: rendered Pokémon fog visibility, atlas cropping/opaque masks, all source-frame dimensions, character shadows, real sprite occlusion and fog restoration")
	quit()
