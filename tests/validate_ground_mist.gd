extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
const Snapshots = preload("res://tests/validate_terraces.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	TestDungeonFactory.rng.seed = 4
	var main = load("res://scenes/demos/sunlight_demo.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	await process_frame
	await process_frame
	var effect = main.get_node("SunlightAtmosphere")
	var ground = effect.ground_mist
	var data: DungeonData = main.dungeon
	var snapshot = Snapshots.snapshot(data)
	var state: int = TestDungeonFactory.rng.state
	assert(ground.visible and ground.mesh.get_surface_count() == 1)
	assert(ground.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var started := Time.get_ticks_usec()
	ground.refresh(data)
	print("GROUND MIST refresh ms=",(Time.get_ticks_usec()-started)/1000.0)
	var outside := 0
	for y in range(ground.bounds.position.y,ground.bounds.end.y):
		for x in range(ground.bounds.position.x,ground.bounds.end.x):
			var tile := Vector2i(x,y)
			var value: float = ground.coverage.get_pixelv(tile-ground.bounds.position).r
			if data.is_bright(tile): assert(value > 0.99)
			elif data.is_walkable(tile) and not data.discovered_tiles.has(tile): assert(value == 0.0)
			elif not data.is_walkable(tile) and value > 0.0: outside += 1
	assert(outside > 0)
	var uploads: int = ground.uploads
	var mesh_id: int = ground.mesh.get_instance_id()
	for i in range(4): effect._update_context()
	assert(ground.uploads == uploads and ground.mesh.get_instance_id() == mesh_id)
	assert(Snapshots.snapshot(data) == snapshot and TestDungeonFactory.rng.state == state)
	# Room/corridor movement updates mist independently of the sunlight visibility.
	for tile: Vector2i in data.tiles:
		if data.get_room_id(tile) >= 0 or not data.is_walkable(tile): continue
		main.player.setup(tile,data,main.dungeon_renderer)
		main.refresh_fog()
		effect._update_context()
		assert(ground.visible and ground.coverage.get_pixelv(tile-ground.bounds.position).r > 0.99)
		break
	main.free()
	print("PASS: batched floor mist, outside coverage, undiscovered path protection, idle reuse, corridor coverage and unchanged topology/RNG")
	quit()
