extends SceneTree
## Owns: the continuous procedural out-of-bounds terrain. Coverage of the map's
## west/north/east surroundings without touching the map or the south band,
## crack-free chunks, coverage of border rocks, rise with distance, smoothness,
## winding/normals, per-floor determinism, shade lift, settings, toggles and
## fixture exemptions. Appearance is judged by the user in normal rendering.
const Snapshots = preload("res://tests/validate_terraces.gd")
const CameraScript = preload("res://scripts/core/presentation_camera.gd")
func _initialize() -> void: call_deferred("validate")


func signature(scenery: OutOfBoundsScenery) -> Array:
	var result: Array = []
	for chunk in scenery.chunks: result.append(chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return result


func check_geometry(scenery: OutOfBoundsScenery, data: DungeonData, backdrop: CaveTerrainBackdrop) -> void:
	var tops: Dictionary = {}
	var near_sum := 0.0
	var near_count := 0
	var far_sum := 0.0
	var far_count := 0
	for chunk in scenery.chunks:
		assert(chunk is MeshInstance3D and chunk.material_override == scenery.material)
		assert(chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert(chunk.get_meta("geometry_purpose") == "out_of_bounds_scenery")
		var arrays: Array = chunk.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(vertices.size()):
			var vertex := vertices[index]
			assert(is_equal_approx(normals[index].length(), 1.0))
			# Nothing south of the map; everything inside the configured region.
			assert(vertex.z <= scenery.south_cut + 0.0001)
			assert(scenery.region.grow(0.0001).has_point(Vector2(vertex.x, vertex.z)))
			if vertex.y <= CaveTerrainBackdrop.GROUND_BASE + 0.0001: continue # Skirt base.
			# Crack-free: every shared XZ position has one height across all chunks.
			var key := Vector2i(roundi(vertex.x * 2.0), roundi(vertex.z * 2.0))
			if tops.has(key): assert(is_equal_approx(tops[key], vertex.y))
			tops[key] = vertex.y
		for triangle in range(0, indices.size(), 3):
			var a := vertices[indices[triangle]]
			var b := vertices[indices[triangle + 1]]
			var c := vertices[indices[triangle + 2]]
			# Godot front faces are clockwise from the normal side: front normal = -(b-a)x(c-a).
			var front := -(b - a).cross(c - a)
			var shading := normals[indices[triangle]] + normals[indices[triangle + 1]] + normals[indices[triangle + 2]]
			assert(front.dot(shading) > 0.0)
			var centroid := (a + b + c) / 3.0
			if absf(front.normalized().y) > 0.2:
				# Surface triangles face up and never cover the logical map.
				assert(front.y > 0.0 and normals[indices[triangle]].y > 0.0)
				assert(not scenery.map_rect.grow(-0.0001).has_point(Vector2(centroid.x, centroid.z)))
	# The surface sits on or above every border rock it covers.
	var covered := 0
	for record in backdrop.records:
		if not record.external: continue
		var cell: Vector2i = record.cell
		var center := Vector2(cell)
		if not scenery.region.has_point(center) or scenery.map_rect.has_point(center): continue
		for offset in [Vector2.ZERO, Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			var point: Vector2 = center + offset
			if point.y > scenery.south_cut: continue
			assert(scenery.height_at(point.x, point.y) >= float(record.top) + OutOfBoundsScenery.CLEARANCE - 0.0001)
		covered += 1
	assert(covered > 100)
	# Rises with distance, bounded by the settings; the southern edge rests on the floor.
	for key in tops:
		var x: float = key.x * 0.5
		var z: float = key.y * 0.5
		var distance := scenery.map_distance(x, z)
		var height: float = tops[key]
		if distance > 0.0 and distance < 2.0:
			near_sum += height
			near_count += 1
		elif distance > 12.0 and z < scenery.south_cut - 12.0:
			far_sum += height
			far_count += 1
		if z >= scenery.south_cut - 0.001:
			assert(height <= scenery.floor_at(x, z) + OutOfBoundsScenery.CLEARANCE + 0.0001)
	assert(near_count > 0 and far_count > 0)
	assert(far_sum / far_count > near_sum / near_count + 1.5)


func check_smoothness(scenery: OutOfBoundsScenery, renderer: DungeonRenderer) -> void:
	# No needles: the steepest step between neighbouring vertices stays under ~67 degrees.
	var steepest := 0.0
	for row in range(scenery._rows):
		for column in range(scenery._columns):
			var height := scenery._grid_height(column, row)
			if column + 1 < scenery._columns: steepest = maxf(steepest, absf(scenery._grid_height(column + 1, row) - height))
			if row + 1 < scenery._rows: steepest = maxf(steepest, absf(scenery._grid_height(column, row + 1) - height))
	assert(steepest <= 1.2)
	var ceiling: float = scenery.ground_level + renderer.out_of_bounds_foothill_height + renderer.out_of_bounds_mountain_height
	assert(scenery.diagnostics.max_height <= ceiling + 0.001)
	assert(scenery.diagnostics.max_height >= scenery.ground_level + 0.4 * renderer.out_of_bounds_mountain_height)


func validate() -> void:
	root.size = Vector2i(1920, 1080)
	var camera := CameraScript.new()
	root.add_child(camera)
	camera.current = true
	camera.rotation_degrees.x = -camera.pitch_degrees
	camera.fov = camera.field_of_view
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	var floors: Array = []
	for mode in [true, false]:
		renderer.cave_continuous_ground_enabled = mode
		for seed_value in [4, 17]:
			TestDungeonFactory.rng.seed = seed_value
			var data := TestDungeonFactory.create_test_dungeon()
			data.update_fog(data.player_spawn)
			var before := Snapshots.snapshot(data)
			var rng_state: int = TestDungeonFactory.rng.state
			assert(renderer.render_dungeon(data))
			var children := renderer.get_child_count()
			var scenery := renderer.out_of_bounds_scenery
			assert(scenery != null and scenery.get_parent() == renderer)
			assert(scenery.get_child_count() == scenery.diagnostics.mesh_nodes and scenery.chunks.size() == scenery.diagnostics.mesh_nodes)
			assert(scenery.diagnostics.mesh_nodes > 4 and scenery.diagnostics.mesh_nodes <= 40)
			assert(scenery.diagnostics.triangles > 10000 and scenery.diagnostics.triangles < 60000)
			assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
			assert(scenery.region.position.x == scenery.map_rect.position.x - renderer.out_of_bounds_extent)
			assert(is_equal_approx(scenery.region.end.y, scenery.map_rect.end.y))
			check_geometry(scenery, data, renderer.cave_background)
			check_smoothness(scenery, renderer)
			# Deterministic per floor; the visual seed and the layout both change the range.
			var first := signature(scenery)
			if mode: floors.append(first)
			assert(renderer.render_dungeon(data) and signature(renderer.out_of_bounds_scenery) == first)
			assert(renderer.get_child_count() == children)
			renderer.floor_visual_seed = 99
			assert(renderer.render_dungeon(data) and signature(renderer.out_of_bounds_scenery) != first)
			renderer.floor_visual_seed = 0
			assert(renderer.render_dungeon(data))
			scenery = renderer.out_of_bounds_scenery
			# Shade follows the border palette with the configured lift; geometry is unaffected.
			renderer.apply_fog(0)
			var dim: Color = renderer.dim_material.albedo_color.lerp(Color.WHITE, renderer.out_of_bounds_shade_lift)
			dim.a = 1.0
			assert(scenery.current_shade() == dim)
			assert(scenery.material.get_shader_parameter("fog_shade") == Vector3(dim.r, dim.g, dim.b))
			renderer.apply_fog(1)
			var other: Color = renderer.other_elevation_material.albedo_color.lerp(Color.WHITE, renderer.out_of_bounds_shade_lift)
			other.a = 1.0
			assert(scenery.current_shade() == other and signature(scenery) == first)
			# Settings: flat terrain rests on the floor; a shorter extent shrinks the region.
			renderer.out_of_bounds_mountain_height = 0.0
			renderer.out_of_bounds_foothill_height = 0.0
			assert(renderer.render_dungeon(data))
			var flat := renderer.out_of_bounds_scenery
			for row in range(flat._rows):
				for column in range(flat._columns):
					var point := flat._grid_point(column, row)
					assert(is_equal_approx(flat._grid_height(column, row), maxf(flat.floor_at(point.x, point.y) + OutOfBoundsScenery.CLEARANCE, flat.ground_level)))
			renderer.out_of_bounds_mountain_height = 6.0
			renderer.out_of_bounds_foothill_height = 0.8
			renderer.out_of_bounds_extent = 10
			assert(renderer.render_dungeon(data))
			assert(renderer.out_of_bounds_scenery.region.size.x < scenery_width(data, 22) and renderer.out_of_bounds_scenery.diagnostics.triangles > 0)
			renderer.out_of_bounds_extent = 22
			# Toggles: disabled scenery or no border leaves nothing behind; re-enabling restores it.
			renderer.out_of_bounds_scenery_enabled = false
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery == null)
			assert(renderer.get_child_count() == children - 1)
			renderer.out_of_bounds_scenery_enabled = true
			renderer.cave_scenery_border_width = 0
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery == null)
			renderer.cave_scenery_border_width = 6
			assert(renderer.render_dungeon(data) and signature(renderer.out_of_bounds_scenery) == first)
			assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
	assert(floors.size() == 2 and floors[0] != floors[1])
	# Preserved fixtures never acquire out-of-bounds scenery.
	for data in [BenchmarkDungeonFactory.create(), DemoArenaFactory.create_arena(), TestDungeonFactory.create_elevation_test_dungeon()]:
		assert(renderer.render_dungeon(data, true) and renderer.out_of_bounds_scenery == null)
	renderer.free()
	camera.free()
	print("PASS: continuous out-of-bounds terrain stays off the map and south band, crack-free chunks, covers border rocks, rises with distance, no needle slopes, consistent winding/normals, per-floor determinism, shade lift, settings, toggles and fixture exemptions")
	quit()


func scenery_width(data: DungeonData, extent: int) -> float:
	return data.map_bounds.size.x + 2.0 * extent
