extends SceneTree

func _initialize() -> void: call_deferred("validate")

func snapshot(data: DungeonData) -> Dictionary:
	var result := {}
	for property in ["tiles", "elevations", "rooms", "room_elevations", "connections", "ramp_segments", "ramp_tiles", "reserved_transitions", "player_spawn", "stairs_position", "enemy_spawns", "bright_tiles", "discovered_tiles"]:
		var value: Variant = data.get(property)
		result[property] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func lower_visuals(renderer: DungeonRenderer) -> Array:
	var result := []
	for visual in renderer.fog_visuals:
		var tile: Vector2i = visual.tiles[0]
		var height: int = visual.fill_elevation if visual.filler else renderer.dungeon_data.get_elevation(tile)
		if height != 0: continue
		var mesh: MeshInstance3D = visual.mesh
		result.append([tile, visual.wall, visual.filler, mesh.mesh, mesh.transform, visual.materials])
	return result

func validate() -> void:
	var data := TestDungeonFactory.create_fallback_dungeon()
	data.set_tile(Vector2i(3, 6), DungeonData.TileType.CORRIDOR, 0)
	data.set_tile(Vector2i(3, 7), DungeonData.TileType.CORRIDOR, 0)
	for y in range(6, 10): data.set_tile(Vector2i(13, y), DungeonData.TileType.CORRIDOR, 1)
	data.stairs_position = Vector2i(12, 4)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS, 1)
	data.enemy_spawns = [Vector2i(12, 3)]
	data.update_fog(data.player_spawn)
	var original := snapshot(data)
	var reachable := TestDungeonFactory.reachable_tiles(data)
	var state: int = TestDungeonFactory.rng.state
	var renderer := DungeonRenderer.new()
	renderer.upper_terrain_mode = UpperTerrainVisuals.Mode.UNLIMITED # Original open-platform filler contract.
	root.add_child(renderer)
	renderer.upper_elevation_open_platforms = false
	renderer.render_dungeon(data)
	var lower := lower_visuals(renderer)
	var old_upper_walls := 0
	for visual in renderer.fog_visuals:
		if visual.wall and data.get_elevation(visual.tiles[0]) == 1: old_upper_walls += 1
	assert(old_upper_walls > 0)
	renderer.upper_elevation_open_platforms = true
	renderer.render_dungeon(data)
	assert(lower_visuals(renderer) == lower) # Exact lower meshes, transforms, fog materials.
	var support_count := 0
	var upper_floors := 0
	var lower_walls := 0
	var room_fill := 0
	var support: Dictionary
	var ramp: Dictionary
	for visual in renderer.fog_visuals:
		var tile: Vector2i = visual.tiles[0]
		var mesh: MeshInstance3D = visual.mesh
		var bounds := mesh.global_transform * mesh.get_aabb()
		if visual.wall:
			assert(data.get_elevation(tile) == 0)
			lower_walls += 1
		if visual.filler:
			if data.get_elevation(visual.fill_owner) == 1:
				assert(data.get_tile(visual.fill_owner) != DungeonData.TileType.CORRIDOR)
				assert(is_equal_approx(bounds.end.y, 3.1))
				room_fill += 1
		elif visual.get("support", false):
			support_count += 1
			assert(not visual.wall and data.get_tile(tile) == DungeonData.TileType.CORRIDOR and data.get_elevation(tile) == 1)
			assert(is_equal_approx(bounds.size.y, 1.0) and is_equal_approx(bounds.size.x, 1.0) and is_equal_approx(bounds.size.z, 1.0))
			var floor_mesh := ModularDungeonVisuals.FLOOR
			var bottom := 3.1 + (floor_mesh.get_aabb().position.y - ModularDungeonVisuals.FLOOR_TOP) * ModularDungeonVisuals.SOURCE_SCALE
			assert(is_equal_approx(bounds.end.y, bottom))
			assert(visual.materials[0][0].albedo_color.is_equal_approx(ModularDungeonVisuals.FILL_COLOR))
			if tile == Vector2i(13, 8): support = visual
		elif not visual.stairs and data.get_elevation(tile) == 1:
			assert(mesh.mesh == ModularDungeonVisuals.surface_mesh(ModularDungeonVisuals.FLOOR, 0))
			assert(is_equal_approx(bounds.end.y, 3.1))
			upper_floors += 1
		if visual.tiles.size() == 3: ramp = visual
	var corridors := 0
	for tile: Vector2i in data.tiles:
		if data.get_tile(tile) == DungeonData.TileType.CORRIDOR and data.get_elevation(tile) == 1: corridors += 1
	assert(support_count == corridors and upper_floors == 16 + corridors)
	assert(lower_walls > 0 and room_fill > 0 and not support.is_empty() and not ramp.is_empty())
	renderer.apply_fog(0)
	assert(support.fog_state == 2 and support.mesh.visible)
	assert(snapshot(data) == original and TestDungeonFactory.reachable_tiles(data) == reachable and TestDungeonFactory.rng.state == state)
	# Support uses the existing higher-terrain occlusion and restores fog materials.
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(13, 5, 12)
	camera.look_at(Vector3(13, 0.4, 5))
	var points: Array[Vector3] = [Vector3(13, 0.4, 5)]
	renderer.update_occlusion(camera, Vector2i(3, 7), points)
	assert(support.occluded and not support.mesh.visible)
	renderer.apply_fog(0)
	assert(not support.mesh.visible and support.fog_state == 2)
	renderer.update_occlusion(camera, Vector2i(3, 7), [])
	assert(not support.occluded and support.mesh.visible)
	data.update_fog(Vector2i(13, 8))
	var visibility := snapshot(data)
	renderer.apply_fog(1)
	assert(support.fog_state == 0 and support.mesh.get_surface_override_material(0) == support.materials[0][0])
	assert(snapshot(data) == visibility)
	var first: Vector2i = data.ramp_segments[0].lower_buffer
	data.update_fog(first + Vector2i.RIGHT)
	renderer.apply_fog(0)
	assert(ramp.fog_state == 0 and ramp.mesh.visible)
	for index in range(4):
		var tile := first + Vector2i.RIGHT * index
		assert(data.can_traverse(tile, tile + Vector2i.RIGHT) and data.can_traverse(tile + Vector2i.RIGHT, tile))
	# Independent height/disable controls and complete all-walled rollback.
	renderer.upper_corridor_support_height = 0.5
	renderer.render_dungeon(data)
	for visual in renderer.fog_visuals:
		if visual.get("support", false): assert(is_equal_approx(visual.mesh.mesh.get_aabb().size.y, 0.5))
	renderer.upper_corridor_support_height = 0.0
	renderer.render_dungeon(data)
	for visual in renderer.fog_visuals: assert(not visual.get("support", false))
	renderer.upper_elevation_open_platforms = false
	renderer.render_dungeon(data)
	var restored := 0
	for visual in renderer.fog_visuals:
		assert(not visual.get("support", false))
		if visual.wall and data.get_elevation(visual.tiles[0]) == 1: restored += 1
	assert(restored == old_upper_walls and lower_visuals(renderer) == lower)
	camera.free()
	renderer.free()
	print("PASS: unchanged lower visuals/topology/RNG, open upper rooms/walkways, exact floor/support alignment, retained room cliffs, ramp traversal, fog/occlusion restoration, configurable rollback")
	quit()
