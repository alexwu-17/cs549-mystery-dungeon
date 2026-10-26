extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	for name in ["floor", "floor_wall", "floor_corner", "wall", "up_stairs", "down_stairs", "torch"]:
		var mesh: Mesh = load("res://assets/environment/modular_dungeon/%s.obj" % name)
		assert(mesh != null and mesh.get_surface_count() > 0)
		if name not in ["torch", "down_stairs"]:
			for surface in range(mesh.get_surface_count()):
				assert(mesh.surface_get_material(surface) != null)
	var renderer := DungeonRenderer.new()
	renderer.conventional_wall_height_scale = 1.0
	renderer.floor_variation_enabled = false
	renderer.upper_elevation_open_platforms = false # Exercise the retained all-walled asset selection.
	renderer.terrain_fill_enabled = false # Asset selection is tested separately from decorative fill.
	root.add_child(renderer)
	for elevation in [-1, 0, 1]:
		var data := DungeonData.new()
		data.rooms = [Rect2i(0, 0, 5, 5)]
		for y in range(5):
			for x in range(5): data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, elevation)
		var saved := data.tiles.duplicate()
		renderer.render_dungeon(data)
		assert(data.tiles == saved)
		var floors := 0
		var walls := 0
		for visual in renderer.fog_visuals:
			assert(visual.asset)
			var mesh: MeshInstance3D = visual.mesh
			var bounds := mesh.global_transform * mesh.get_aabb()
			if visual.wall:
				walls += 1
				assert(bounds.size.y > 0.9)
			else:
				floors += 1
				assert(is_equal_approx(bounds.end.y, elevation * DungeonData.ELEVATION_HEIGHT + 0.1))
				assert(is_equal_approx(bounds.size.x, 1.0) and is_equal_approx(bounds.size.z, 1.0))
		assert(floors == 25 and walls == 16)
		data.update_fog(Vector2i(2, 2))
		renderer.apply_fog(elevation)
		for visual in renderer.fog_visuals:
			assert(visual.fog_state == 0 and visual.mesh.material_override == null)
			assert(visual.mesh.get_surface_override_material(0) == visual.materials[0][0])
			assert(visual.materials[0][0].albedo_color.is_equal_approx(ModularDungeonVisuals.WALL_COLOR if visual.wall else ModularDungeonVisuals.FLOOR_COLOR))
			assert(visual.materials[0][1].albedo_color.r < visual.materials[0][0].albedo_color.r)
		data.bright_tiles.clear()
		renderer.apply_fog(elevation + 1)
		for visual in renderer.fog_visuals:
			assert(visual.fog_state == 2)
			assert(visual.mesh.get_surface_override_material(0) == visual.materials[0][2])
	renderer.free()
	print("PASS: seven OBJ imports, floor/wall/corner selection, surface alignment, original materials/fog, unchanged topology")
	quit()
