extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

class CountData extends DungeonData:
	var updates: int = 0
	func update_fog(tile: Vector2i) -> void:
		updates += 1
		super.update_fog(tile)

class CountRenderer extends DungeonRenderer:
	var fog_updates: int = 0
	var state_writes: int = 0
	func apply_fog(elevation: int = 0) -> void:
		fog_updates += 1
		super.apply_fog(elevation)
	func apply_occlusion_state(visual: Dictionary) -> void:
		state_writes += 1
		super.apply_occlusion_state(visual)

func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	main.get_node("DungeonRenderer").set_script(CountRenderer)
	root.add_child(main)
	Helper.complete_introduction(main)
	var renderer: CountRenderer = main.dungeon_renderer
	var data := CountData.new()
	data.rooms = [Rect2i(0,0,3,3), Rect2i(5,0,3,3)]
	for room in data.rooms:
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x): data.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR)
	for x in range(3,5): data.set_tile(Vector2i(x,1),DungeonData.TileType.CORRIDOR)
	data.player_spawn = Vector2i(2,1)
	data.enemy_spawns = [Vector2i(5,1),Vector2i(6,1),Vector2i(7,1)]
	main.dungeon = data
	renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn,data,renderer)
	main.refresh_fog()
	var discovered := data.discovered_tiles.duplicate()
	var bright := data.bright_tiles.duplicate()
	var fog_count := renderer.fog_updates
	var requests := data.updates
	# Four logical refresh requests at an unchanged player tile do no terrain work.
	for i in range(4): main.refresh_turn_visibility()
	assert(renderer.fog_updates == fog_count and data.updates == requests)
	assert(data.discovered_tiles == discovered and data.bright_tiles == bright)
	# Actor visibility still changes immediately, independently of terrain fog.
	var enemy: Skeleton = main.enemies[0]
	assert(not enemy.visible)
	enemy.grid_position = Vector2i(3,1)
	main.refresh_turn_visibility()
	assert(enemy.visible)
	enemy.grid_position = Vector2i(5,1)
	main.refresh_turn_visibility()
	assert(not enemy.visible and renderer.fog_updates == fog_count)
	main.player.try_move(Vector2i.RIGHT)
	Helper.complete(main)
	assert(data.updates == requests + 1 and renderer.fog_updates == fog_count + 1)
	for actor in main.enemies: assert(actor.visible == data.is_bright(actor.grid_position))
	main.player.basic_attack()
	Helper.complete(main)
	assert(data.updates == requests + 1 and renderer.fog_updates == fog_count + 1)
	# Reference elevation is an independent dirty input; explicit refresh forces it.
	main.player.fog_elevation += 1
	main.refresh_turn_visibility()
	assert(renderer.fog_updates == fog_count + 2)
	main.refresh_fog()
	assert(renderer.fog_updates == fog_count + 3)
	# Same-frame identical view coalesces; changed points, view and fog do not.
	var camera: Camera3D = main.presentation_camera
	var sprite: Sprite3D = main.player.get_node("PlayerSprite")
	var points: Array[Vector3] = camera.sprite_samples(sprite)
	renderer.apply_fog()
	renderer.state_writes = 0
	renderer.update_occlusion(camera,main.player.grid_position,points)
	var writes := renderer.state_writes
	assert(writes > 0)
	renderer.update_occlusion(camera,main.player.grid_position,points)
	assert(renderer.state_writes == writes)
	points[0] += Vector3(0.1,0,0)
	renderer.update_occlusion(camera,main.player.grid_position,points)
	assert(renderer.state_writes > writes) # Input array wasn't aliased by cache.
	writes = renderer.state_writes
	camera.h_offset += 0.1
	renderer.update_occlusion(camera,main.player.grid_position,points)
	assert(renderer.state_writes > writes)
	writes = renderer.state_writes
	var old_frame := Engine.get_process_frames()
	while Engine.get_process_frames() == old_frame:
		await process_frame
	renderer.update_occlusion(camera,main.player.grid_position,points)
	assert(renderer.state_writes > writes) # No reuse across animation frames.
	renderer.apply_fog()
	writes = renderer.state_writes
	renderer.update_occlusion(camera,main.player.grid_position,points)
	assert(renderer.state_writes > writes)
	# Rebuild even the same data object invalidates the view cache.
	renderer.render_dungeon(data)
	renderer.state_writes = 0
	renderer.update_occlusion(camera,main.player.grid_position,points)
	assert(renderer.state_writes > 0)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.dungeon != data and main.dungeon.is_bright(main.player.grid_position))
	main.free()
	print("PASS: fog dirty inputs, immediate actor visibility, same-frame occlusion reuse/invalidation and restart")
	quit()
