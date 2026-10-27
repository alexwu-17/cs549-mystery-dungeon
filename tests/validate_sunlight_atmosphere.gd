extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
const Snapshots = preload("res://tests/validate_terraces.gd")
const LightingChecks = preload("res://tests/validate_lighting_presets.gd")
func _initialize() -> void: call_deferred("validate")

func check_room_lifecycle(main: Node3D, effect: SunlightAtmosphere) -> void:
	effect.apply_mode(SunlightAtmosphere.Mode.MESH)
	var data: DungeonData = main.dungeon
	var anchors: Dictionary = {}
	var maximum_ms := 0.0
	var widths: Array = []
	for room_id in range(data.rooms.size()):
		var room: Rect2i = data.rooms[room_id]
		var tile := room.position+room.size/2
		assert(data.is_walkable(tile))
		main.player.setup(tile,data,main.dungeon_renderer)
		main.refresh_fog()
		var before := Snapshots.snapshot(data)
		var state: int = TestDungeonFactory.rng.state
		var started := Time.get_ticks_usec()
		effect._update_context()
		maximum_ms = maxf(maximum_ms,(Time.get_ticks_usec()-started)/1000.0)
		assert(effect._room_id == room_id and effect._room_cache.has(room_id))
		assert(effect.placement_safe and effect.mesh_effect.visible)
		assert(room.has_point(effect.receiver_tile))
		assert(effect.effective_width > effect.beam_width)
		widths.append(effect.effective_width)
		anchors[room_id] = effect.receiver
		var placements := effect.room_placements
		var mesh_id := effect.mesh_effect.mesh.get_instance_id()
		for i in range(3): effect._update_context()
		assert(effect.room_placements == placements and effect.mesh_effect.mesh.get_instance_id() == mesh_id)
		assert(Snapshots.snapshot(data) == before and state == TestDungeonFactory.rng.state)
	for tile: Vector2i in data.tiles:
		if data.get_tile(tile) != DungeonData.TileType.CORRIDOR or data.get_room_id(tile) >= 0: continue
		main.player.setup(tile,data,main.dungeon_renderer)
		main.refresh_fog()
		effect._update_context()
		assert(not effect.mesh_effect.visible and not effect.mist.visible)
		break
	var placements := effect.room_placements
	for room_id in anchors:
		var room: Rect2i = data.rooms[room_id]
		var tile := room.position+room.size/2
		main.player.setup(tile,data,main.dungeon_renderer)
		main.refresh_fog()
		effect._update_context()
		assert(effect.receiver == anchors[room_id] and effect.room_placements == placements)
	assert(effect._room_cache.size() <= data.rooms.size())
	print("ROOM SUNLIGHT widths=",widths," maximum first-entry visual update ms=",maximum_ms)

func validate() -> void:
	TestDungeonFactory.rng.seed = 4
	var main = load("res://scenes/demos/sunlight_demo.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	await process_frame
	await process_frame
	var effect: SunlightAtmosphere = main.get_node("SunlightAtmosphere")
	assert(effect.selected_mode == SunlightAtmosphere.Mode.MESH and effect.placement_safe and effect.mesh_effect.visible)
	var before := Snapshots.snapshot(main.dungeon)
	var rng_state: int = TestDungeonFactory.rng.state
	var turn_state: int = main.turn_rng.state
	var visuals := LightingChecks.visual_values(main)
	var baseline := LightingChecks.environment_values(effect.lighting.world.environment)
	var sun: DirectionalLight3D = effect.lighting.sun
	var sun_transform := sun.transform
	var energy := sun.light_energy
	var fog_energy := sun.light_volumetric_fog_energy
	var anchor := effect.receiver
	var camera: Camera3D = main.presentation_camera
	var start_pixel := camera.unproject_position(anchor-effect.direction*effect.beam_length)
	var end_pixel := camera.unproject_position(anchor)
	assert(start_pixel.x < end_pixel.x and start_pixel.y < end_pixel.y)
	for mode in [1,2,0,2,1,0]:
		effect.apply_mode(mode)
		assert(effect.mesh_effect.visible == (mode == 1) and effect.mist.visible == (mode == 2))
		assert(main.find_children("*","Light3D",true,false).size() == 1)
		assert(main.find_children("*","CollisionObject3D",true,false).is_empty())
		assert(effect.mesh_effect.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert(sun.transform == sun_transform and sun.light_energy == energy)
		assert(effect.direction.is_equal_approx(-sun.global_basis.z.normalized()))
		assert(Snapshots.snapshot(main.dungeon) == before and TestDungeonFactory.rng.state == rng_state and main.turn_rng.state == turn_state)
		assert(LightingChecks.visual_values(main) == visuals)
		if mode == 2:
			assert(effect.lighting.world.environment.volumetric_fog_enabled and effect.lighting.world.environment.volumetric_fog_density == 0.0)
		else:
			assert(LightingChecks.environment_values(effect.lighting.world.environment) == baseline)
			assert(sun.light_volumetric_fog_energy == fog_energy)
	effect.apply_mode(SunlightAtmosphere.Mode.MESH)
	var updates := effect.mask_updates
	assert(effect.get_node_or_null("AtmosphereControls") == null)
	assert(not effect.has_method("_unhandled_key_input"))
	for code in [KEY_L,KEY_F7]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		root.push_input(key,true)
		assert(effect.selected_mode == SunlightAtmosphere.Mode.MESH and Snapshots.snapshot(main.dungeon) == before)
		key.pressed = false
		root.push_input(key,true)
	for i in range(5): effect._update_context()
	assert(effect.mask_updates == updates)
	# Following the player cannot move the shaft's world anchor.
	for offset in DungeonData.CARDINALS:
		var tile: Vector2i = main.player.grid_position+offset
		if not main.dungeon.can_traverse(main.player.grid_position,tile) or main.is_enemy_occupied(tile): continue
		main.player.setup(tile,main.dungeon,main.dungeon_renderer)
		main.refresh_fog()
		effect._update_context()
		main.update_presentation()
		assert(effect.receiver == anchor and effect.mask_updates == updates+1)
		break
	# Force conceal/reveal without changing logical fog semantics in production.
	var bright: Dictionary = main.dungeon.bright_tiles.duplicate()
	main.dungeon.bright_tiles.clear()
	effect.refresh_visibility()
	effect.apply_mode(1)
	assert(not effect.mesh_effect.visible and not effect.mist.visible)
	main.dungeon.bright_tiles = bright
	effect.refresh_visibility()
	assert(effect.mesh_effect.visible)
	# Any intervening solid overhang must reject a fake shaft, even if faded.
	for visual in main.dungeon_renderer.fog_visuals:
		if visual.purpose != EnvironmentGeometryPlan.WALKWAY and visual.purpose != EnvironmentGeometryPlan.FOUNDATION: continue
		var bounds: AABB = visual.mesh.global_transform*visual.mesh.get_aabb()
		effect.receiver = bounds.get_center()+effect.direction*1.5
		effect.rebuild()
		assert(not effect.placement_safe and not effect.mesh_effect.visible)
		break
	effect.place_at(effect.receiver_tile)
	effect.apply_mode(2)
	for preset in [2,0,1]:
		effect.lighting.apply_preset(preset)
		assert(effect.lighting.world.environment.volumetric_fog_enabled)
		assert(effect.lighting.world.environment.ssao_enabled == (preset == 2))
		effect.apply_mode(0)
		assert(not effect.lighting.world.environment.volumetric_fog_enabled and sun.light_volumetric_fog_energy == fog_energy)
		effect.apply_mode(2)
	main.start_new_run()
	Helper.complete_introduction(main)
	effect._update_context()
	assert(effect._floor_id == main.dungeon.get_instance_id())
	check_room_lifecycle(main,effect)
	effect.apply_mode(0)
	main.free()
	# F5 and every ordinary entry inherit the automatic beam, not just the demo.
	for path in ["main","demo_main","limit_testing_main"]:
		TestDungeonFactory.rng.seed = 4
		var game = load("res://scenes/main/%s.tscn"%path).instantiate()
		root.add_child(game)
		Helper.complete_introduction(game)
		await process_frame
		await process_frame
		var automatic: SunlightAtmosphere = game.get_node("SunlightAtmosphere")
		assert(game.find_children("SunlightAtmosphere","",true,false).size() == 1)
		assert(automatic.selected_mode == SunlightAtmosphere.Mode.MESH and automatic.mesh_effect.visible)
		assert(automatic.mask_bounds.has_point(automatic.receiver_tile))
		assert(automatic.mask_image.get_pixelv(automatic.receiver_tile-automatic.mask_bounds.position).r > 0.9)
		assert(not automatic.mist.visible and automatic.get_node_or_null("AtmosphereControls") == null)
		game.start_new_run()
		Helper.complete_introduction(game)
		automatic._update_context()
		assert(automatic.selected_mode == SunlightAtmosphere.Mode.MESH and automatic.mesh_effect.visible)
		game.free()
	print("PASS: independent reversible prototypes, upper-left sun alignment, no added lights/collision, exact environment restoration, static anchor, dirty mask, concealment, overhang rejection, lighting and floor lifecycle")
	quit()
