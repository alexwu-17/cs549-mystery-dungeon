extends SceneTree

func _initialize() -> void: call_deferred("validate")

func hit_height(faces: PackedVector3Array, x: float, z: float) -> float:
	var result := -INF
	for index in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(Vector3(x, 5, z), Vector3.DOWN, faces[index], faces[index + 1], faces[index + 2])
		if hit != null: result = maxf(result, hit.y)
	return result

func validate() -> void:
	var data := DungeonData.new()
	data.rooms = [Rect2i(0, 0, 3, 3), Rect2i(8, 0, 3, 3)]
	data.room_elevations = [0, 1]
	for room_index in range(data.rooms.size()):
		var room := data.rooms[room_index]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x): data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, room_index)
	data.add_ramp(Vector2i(3, 1), Vector2i.RIGHT, 0)
	data.player_spawn = Vector2i(1, 1)
	data.stairs_position = Vector2i(9, 1)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS, 1)
	data.enemy_spawns = [Vector2i(9, 2)]
	data.update_fog(data.player_spawn)
	var tiles := data.tiles.duplicate()
	var elevations := data.elevations.duplicate()
	var discovered := data.discovered_tiles.duplicate()
	var bright := data.bright_tiles.duplicate()
	var segments := data.ramp_segments.duplicate(true)
	var reachable := TestDungeonFactory.reachable_tiles(data)
	var rng_state: int = TestDungeonFactory.rng.state
	var renderer := DungeonRenderer.new()
	renderer.conventional_wall_height_scale = 1.0
	renderer.upper_elevation_open_platforms = false # Original filler/rollback contract.
	root.add_child(renderer)
	renderer.render_dungeon(data)
	var layout := TerrainFillVisuals.layout(data, renderer.terrain_fill_margin)
	assert(layout.cells == renderer.terrain_fill_cells)
	for y in range(layout.bounds.position.y, layout.bounds.end.y):
		for x in range(layout.bounds.position.x, layout.bounds.end.x):
			var tile := Vector2i(x, y)
			assert(renderer.terrain_fill_cells.has(tile) == not data.is_walkable(tile))
	var front: Dictionary
	var upper: Dictionary
	var lower: Dictionary
	for visual in renderer.fog_visuals:
		if not visual.filler: continue
		var tile: Vector2i = visual.tiles[0]
		assert(not data.is_walkable(tile) and not data.reserved_transitions.has(tile))
		var bounds: AABB = visual.mesh.global_transform * visual.mesh.get_aabb()
		assert(is_equal_approx(bounds.position.y, layout.base))
		assert(is_equal_approx(bounds.end.y, layout.cells[tile].height * DungeonData.ELEVATION_HEIGHT + TerrainFillVisuals.wall_top_offset(0.1)))
		assert(is_equal_approx(bounds.size.x, 1) and is_equal_approx(bounds.size.z, 1))
		if tile == Vector2i(1, 3): front = visual
		if tile == Vector2i(-1, 1): lower = visual
		if tile == Vector2i(11, 1): upper = visual
	assert(not front.is_empty() and not lower.is_empty() and not upper.is_empty())
	assert(is_equal_approx(upper.mesh.position.y - lower.mesh.position.y, DungeonData.ELEVATION_HEIGHT))
	renderer.apply_fog(0)
	assert(lower.fog_state == 0 and upper.fog_state == 2)
	assert(lower.materials[0][0].albedo_color.is_equal_approx(Color("#6A6D78")))
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.rotation.x = deg_to_rad(-50)
	camera.position = Vector3(1, 10.1, 10)
	var points: Array[Vector3] = [Vector3(1, 0.3, 2)]
	renderer.update_occlusion(camera, Vector2i(1, 2), points)
	assert(front.occluded and front.mesh.visible and is_equal_approx(front.mesh.transparency, 0.8))
	assert(front.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var material: Material = front.mesh.get_surface_override_material(0)
	renderer.apply_fog(0)
	assert(front.mesh.get_surface_override_material(0) == material and is_equal_approx(front.mesh.transparency, 0.8))
	renderer.update_occlusion(camera, Vector2i(1, 2), [])
	assert(not front.occluded and front.mesh.transparency == 0.0)
	assert(front.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert(data.tiles == tiles and data.elevations == elevations and data.ramp_segments == segments)
	assert(data.discovered_tiles == discovered and data.bright_tiles == bright)
	assert(TestDungeonFactory.rng.state == rng_state)
	assert(TestDungeonFactory.reachable_tiles(data) == reachable)
	# The backing is continuous across recessed tile ends and meets buffer thickness.
	for count in [1, 3]:
		var sealed := ModularDungeonVisuals.ramp_mesh(count, true)
		var original := ModularDungeonVisuals.ramp_mesh(count, false)
		assert(sealed.get_surface_count() == original.get_surface_count() + 1)
		var backing := ModularDungeonVisuals.surface_mesh(sealed, sealed.get_surface_count() - 1)
		var faces := backing.get_faces()
		for z in [-0.49, 0.0, 0.49]:
			for tile in range(count + 1):
				for side in [-0.001, 0.001]:
					var x: float = tile + side
					if x <= 0 or x >= count: continue
					assert(hit_height(faces, x, z) > 0)
		assert(backing.get_aabb().position.y < -0.15)
		assert(backing.get_aabb().end.y > DungeonData.ELEVATION_HEIGHT - 0.1)
	renderer.terrain_fill_enabled = false
	renderer.stair_seams_enabled = false
	renderer.render_dungeon(data)
	assert(renderer.terrain_fill_cells.is_empty())
	for visual in renderer.fog_visuals:
		assert(not visual.filler)
		if visual.tiles.size() == 3: assert(visual.mesh.mesh == ModularDungeonVisuals.ramp_mesh(3, false))
	camera.free()
	renderer.free()
	print("PASS: complete non-walkable fill, local elevations/backing, fog/fade restoration, unchanged dungeon/discovery/reachability, sealed stair joins/buffers, independent rollback toggles")
	quit()
