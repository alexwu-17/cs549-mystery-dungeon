extends SceneTree
const Snapshots = preload("res://tests/validate_terraces.gd")
func _initialize() -> void: call_deferred("validate")

func required_signature(renderer: DungeonRenderer) -> Array:
	var result: Array = []
	for visual in renderer.fog_visuals:
		if visual.purpose in [EnvironmentGeometryPlan.TERRACE,EnvironmentGeometryPlan.BOUNDARY]: continue
		result.append([visual.tiles,visual.purpose,visual.mesh.transform,visual.mesh.get_aabb()])
	return result

func validate() -> void:
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	for seed_value in [0,4,8,17,23,54903]:
		TestDungeonFactory.rng.seed = seed_value
		var data := TestDungeonFactory.create_test_dungeon()
		data.update_fog(data.player_spawn)
		var before := Snapshots.snapshot(data)
		var rng_state: int = TestDungeonFactory.rng.state
		renderer.cave_continuous_ground_enabled = false
		renderer.cave_stone_mapping_enabled = false
		assert(renderer.render_dungeon(data))
		var structures := required_signature(renderer)
		var original: Array = []
		for record in renderer.cave_background.records:
			original.append([record.cell,record.top,record.bottom,record.underlay,record.structural,record.varied])
		for stage in [2,3,4]:
			renderer.cave_continuous_ground_enabled = true
			renderer.cave_stone_mapping_enabled = stage >= 3
			renderer.cave_weathered_edges_enabled = stage >= 4
			assert(renderer.render_dungeon(data))
			assert(required_signature(renderer) == structures)
			assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
			var backdrop := renderer.cave_background
			var surface := backdrop.ground_surface
			assert(surface != null and backdrop.batches.is_empty())
			assert(surface.chunks.size() <= 40 and backdrop.diagnostics.mesh_nodes <= 41)
			assert(backdrop.get_child_count() == backdrop.diagnostics.mesh_nodes)
			assert(surface.stats.omitted_sides > 0 and surface.stats.top_rectangles > 0)
			assert(surface.stats.triangles < backdrop.records.size()*16)
			var shared_shapes: Dictionary = {}
			var plan_records: Dictionary = {}
			for entry in renderer.geometry_plan.get("elements",[]): plan_records[entry.id] = entry
			for visual in renderer.fog_visuals:
				var entry: Dictionary = plan_records.get(visual.get("plan_id",""),{})
				if entry.has("rock_profile"):
					var shape := CaveRockSlopes.shape_key(entry)
					if shared_shapes.has(shape): assert(shared_shapes[shape] == visual.mesh.mesh)
					shared_shapes[shape] = visual.mesh.mesh
				if visual.purpose not in [EnvironmentGeometryPlan.FOUNDATION,EnvironmentGeometryPlan.TERRACE,EnvironmentGeometryPlan.BOUNDARY]: continue
				for states in visual.materials:
					for state_material in states:
						assert(state_material.uv1_world_triplanar == (stage >= 3))
						if stage >= 3: assert(state_material.albedo_texture == CaveStoneMaterial.detail())
			for index in range(original.size()):
				var record := backdrop.records[index]
				assert(original[index] == [record.cell,record.top,record.bottom,record.underlay,record.structural,record.varied])
				for corner in surface.top_corners(record.cell):
					assert(corner.y >= record.top-0.001 and corner.y <= DungeonData.ELEVATION_HEIGHT+0.1)
					if record.underlay or not surface.slope_profiles.has(record.cell): assert(is_equal_approx(corner.y,record.top))
			# A shared-height vertex must be identical on either side of any chunk.
			for cell: Vector2i in surface.cells:
				for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
					var neighbor: Vector2i = cell+direction
					if not surface.cells.has(neighbor) or not is_equal_approx(surface.cells[cell].top,surface.cells[neighbor].top): continue
					# Deliberate clearance clips can retain a vertical boundary.
					if surface.slope_profiles.has(cell) != surface.slope_profiles.has(neighbor): continue
					var a := surface.top_corners(cell)
					var b := surface.top_corners(neighbor)
					if direction == Vector2i.RIGHT: assert(a[1] == b[0] and a[2] == b[3])
					else: assert(a[3] == b[0] and a[2] == b[1])
			for reference in [0,1,0]:
				renderer.apply_fog(reference)
				for record in backdrop.records:
					var bright: bool = data.is_bright(record.cell) or (record.adjacent and data.is_bright(record.owner))
					var expected := renderer.dim_material.albedo_color if reference == 0 else renderer.other_elevation_material.albedo_color
					if bright and not record.external: expected = Color.WHITE
					assert(record.shade == expected)
					var pixel := surface.palette.get_pixelv(record.cell-surface.bounds.position)
					var color := ModularDungeonVisuals.FILL_COLOR*expected
					color.a = record.tint*0.5
					for channel in range(4): assert(absf(pixel[channel]-color[channel]) <= 1.0/255.0)
				var uploads: int = surface.stats.palette_uploads
				renderer.apply_fog(reference)
				assert(surface.stats.palette_uploads == uploads)
			for node in surface.chunks:
				assert(node.material_override == surface.material and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				var arrays := node.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in range(vertices.size()):
					assert(vertices[i].is_finite() and normals[i].is_normalized())
					assert(vertices[i].y >= CaveTerrainBackdrop.GROUND_BASE-0.001)
				for i in range(0,vertices.size(),3):
					var face_normal := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
					assert(face_normal.dot(normals[i]) < -0.999) # Clockwise front faces.
			# Immediate discovery/conceal updates, without geometry rebuilds.
			var mesh_id := surface.chunks[0].mesh.get_instance_id()
			var steps := 0
			for tile in data.tiles:
				if not data.is_walkable(tile): continue
				data.update_fog(tile)
				renderer.apply_fog(data.get_elevation(tile))
				assert(surface.chunks[0].mesh.get_instance_id() == mesh_id)
				steps += 1
				if steps == 12: break
			# Restore fixture fog for subsequent stages.
			data.bright_tiles = before.bright_tiles.duplicate()
			data.discovered_tiles = before.discovered_tiles.duplicate()
		# Reverting all switches leaves no shader/chunk state in the old renderer.
		renderer.cave_continuous_ground_enabled = false
		renderer.cave_stone_mapping_enabled = true
		assert(renderer.render_dungeon(data) and renderer.cave_background.ground_surface == null)
		assert(renderer.cave_background.caps.material_override.uv1_world_triplanar)
		renderer.cave_stone_mapping_enabled = false
		assert(renderer.render_dungeon(data) and renderer.cave_background.ground_surface == null)
		assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
	renderer.free()
	print("PASS: six fixed seeds, reversible rocky slopes, identical required structures/data/RNG, shared corners and protected underlays, exact immediate fog palettes and no static uploads")
	quit()
