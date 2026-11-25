extends SceneTree
## Owns: the plateau out-of-bounds terrain. Coverage of the map's west/north/east
## surroundings without touching the map or the south band; ownership of those
## sides (no flat border ground, north apron strip or out-of-map filler there);
## rim at map level dropping to a lowland whose mountains stay near map level;
## crack-free chunks, winding/normals, smoothness, shadows, per-floor
## determinism, shade lift, settings, toggles and fixture exemptions; the rock
## texture array. Appearance is judged by the user in normal rendering.
const Snapshots = preload("res://tests/validate_terraces.gd")
const CameraScript = preload("res://scripts/core/presentation_camera.gd")
func _initialize() -> void: call_deferred("validate")


func signature(scenery: OutOfBoundsScenery) -> Array:
	var result: Array = []
	for chunk in scenery.chunks: result.append(chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return result


func check_ownership(renderer: DungeonRenderer, data: DungeonData) -> void:
	# Border ground, apron and filler remain only where the terrain does not reach.
	var south_records := 0
	for record in renderer.cave_background.records:
		if record.external:
			assert(record.cell.y >= data.map_bounds.end.y)
			south_records += 1
	assert(south_records > 0)
	# Filler stays only on cells the layout keeps (its outline plus a one-tile buffer).
	var kept := renderer.terrain_kept
	assert(not kept.is_empty())
	for element in renderer.geometry_plan.get("elements", []):
		assert(kept.has(element.cell) or element.cell.y >= data.map_bounds.end.y)
	for cell in renderer.terrain_fill_cells:
		assert(kept.has(cell) or cell.y >= data.map_bounds.end.y)
	for record in renderer.cave_background.records:
		assert(record.external or kept.has(record.cell))
	# Every walkable tile and its eight neighbours stay rock or floor, never terrain.
	for tile in data.tiles:
		if not data.is_walkable(tile): continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell: Vector2i = tile + Vector2i(dx, dy)
				assert(kept.has(cell) or not data.map_bounds.has_point(cell))
	var apron := renderer.cave_background.scenery_apron
	assert(apron.terrain_owned_until == data.map_bounds.end.y - 0.5)
	assert(apron.mesh.get_faces().size() == 18) # South strip plus two side strips.
	for vertex in apron.mesh.get_faces(): assert(vertex.z >= apron.terrain_owned_until - 0.0001)


func check_geometry(scenery: OutOfBoundsScenery, renderer: DungeonRenderer) -> void:
	var tops: Dictionary = {}
	for chunk in scenery.chunks:
		assert(chunk is MeshInstance3D and chunk.material_override == scenery.material)
		assert(chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
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
			if vertex.y <= scenery.skirt_base() + 0.0001: continue # Skirt base.
			# Crack-free: every shared XZ position has one height across all chunks.
			var key := Vector2i(roundi(vertex.x * 4.0), roundi(vertex.z * 4.0))
			if tops.has(key): assert(is_equal_approx(tops[key], vertex.y))
			tops[key] = vertex.y
		for triangle in range(0, indices.size(), 3):
			var a := vertices[indices[triangle]]
			var b := vertices[indices[triangle + 1]]
			var c := vertices[indices[triangle + 2]]
			# Godot front faces are clockwise from the normal side: front normal = -(b-a)x(c-a).
			var front := -(b - a).cross(c - a)
			var shading := normals[indices[triangle]] + normals[indices[triangle + 1]] + normals[indices[triangle + 2]]
			var centroid := (a + b + c) / 3.0
			# Triangles of the strip tucked under the edge rock are hidden; their
			# normals follow the visible surface instead of the hidden drop.
			assert(front.dot(shading) > 0.0 or scenery.is_kept_point(centroid.x, centroid.z))
			if absf(front.normalized().y) > 0.2:
				# Surface triangles face up and stay off kept layout cells, except the
				# strip tucked under the buffer edge rock.
				assert(front.y > 0.0 and normals[indices[triangle]].y > 0.0)
				assert(not scenery.is_kept_point(centroid.x, centroid.z) or tucked(scenery, centroid.x, centroid.z))
	# Plateau profile: rim at map level, lowland below it, mountains staying near map level.
	var low_sum := 0.0
	var low_count := 0
	var lowland := scenery.lowland_level()
	var peak_ceiling: float = lowland + renderer.out_of_bounds_mountain_height + 0.0001
	for key in tops:
		var x: float = key.x * 0.25
		var z: float = key.y * 0.25
		var distance := scenery.map_distance(x, z)
		var height: float = tops[key]
		var south_blend := z > scenery.south_cut - renderer.out_of_bounds_south_fade
		if distance <= 0.0001 and not south_blend:
			# At the buffer edge the terrain sits just under the rock tops.
			assert(height <= scenery.floor_at(x, z) - OutOfBoundsScenery.RIM_SINK + 0.0001)
		elif distance > renderer.out_of_bounds_rim_width and not south_blend:
			assert(height >= lowland - 0.0001 and height <= peak_ceiling)
			low_sum += height
			low_count += 1
		if z >= scenery.south_cut - 0.001:
			assert(is_equal_approx(height, maxf(scenery.floor_at(x, z) + OutOfBoundsScenery.CLEARANCE, scenery.ground_level)))
	assert(low_count > 1000)
	# The lowland lies clearly below the map: whole mountains are visible from the rim.
	assert(low_sum / low_count < scenery.ground_level - 0.4 * renderer.out_of_bounds_lowland_depth)
	assert(scenery.diagnostics.max_height <= maxf(peak_ceiling, scenery.ground_level + OutOfBoundsScenery.CLEARANCE + 1.0))


## Within one quad of a kept cell's edge that borders a terrain-owned cell.
func tucked(scenery: OutOfBoundsScenery, x: float, z: float) -> bool:
	var cell := Vector2i(floori(x + 0.5), floori(z + 0.5))
	var fx := x + 0.5 - cell.x
	var fz := z + 0.5 - cell.y
	var reach := OutOfBoundsScenery.SPACING + 0.0001
	return (fx < reach and not scenery.kept.has(cell + Vector2i.LEFT)) or (fx > 1.0 - reach and not scenery.kept.has(cell + Vector2i.RIGHT)) \
		or (fz < reach and not scenery.kept.has(cell + Vector2i.UP)) or (fz > 1.0 - reach and not scenery.kept.has(cell + Vector2i.DOWN))


## Vertices hidden under the edge rock (dropped by TUCK_DROP below the surface).
func under_rock(scenery: OutOfBoundsScenery, column: int, row: int) -> bool:
	var point := scenery._grid_point(column, row)
	return scenery._grid_height(column, row) < scenery.height_at(point.x, point.y) - 0.5


func check_smoothness(scenery: OutOfBoundsScenery) -> void:
	# Steepest step between neighbouring visible vertices stays below ~80 degrees: no spikes.
	var steepest := 0.0
	var dropped := 0
	for row in range(scenery._rows):
		for column in range(scenery._columns):
			if under_rock(scenery, column, row):
				dropped += 1
				continue
			var height := scenery._grid_height(column, row)
			if column + 1 < scenery._columns and not under_rock(scenery, column + 1, row): steepest = maxf(steepest, absf(scenery._grid_height(column + 1, row) - height))
			if row + 1 < scenery._rows and not under_rock(scenery, column, row + 1): steepest = maxf(steepest, absf(scenery._grid_height(column, row + 1) - height))
	assert(dropped > 0)
	assert(steepest / OutOfBoundsScenery.SPACING <= tan(deg_to_rad(80.0)))


func check_textures(scenery: OutOfBoundsScenery) -> void:
	var layers: Texture2DArray = scenery.material.get_shader_parameter("rock_layers")
	var macro: Texture2D = scenery.material.get_shader_parameter("macro_noise")
	assert(layers == RockTextureSet.layers and macro == RockTextureSet.macro)
	assert(layers.get_layers() == RockTextureSet.LAYERS and layers.get_width() == RockTextureSet.SIZE and layers.has_mipmaps())
	assert(is_equal_approx(scenery.material.get_shader_parameter("height_low"), scenery.lowland_level()))


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
			assert(not renderer.geometry_diagnostics.get("fallback", false))
			var children := renderer.get_child_count()
			var scenery := renderer.out_of_bounds_scenery
			assert(scenery != null and scenery.get_parent() == renderer and renderer.out_of_bounds_owns_sides())
			# Stones and foliage are separate children with their own checks.
			var terrain_nodes := scenery.get_children().filter(func(child: Node) -> bool: return not (child is OutOfBoundsStones or child is OutOfBoundsFoliage))
			assert(terrain_nodes.size() == scenery.diagnostics.mesh_nodes and scenery.chunks.size() == scenery.diagnostics.mesh_nodes)
			assert(scenery.diagnostics.mesh_nodes > 4 and scenery.diagnostics.mesh_nodes <= 40)
			assert(scenery.diagnostics.triangles > 40000 and scenery.diagnostics.triangles < 140000)
			assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
			assert(scenery.region.position.x == scenery.map_rect.position.x - renderer.out_of_bounds_extent)
			assert(is_equal_approx(scenery.region.end.y, scenery.map_rect.end.y))
			check_ownership(renderer, data)
			check_geometry(scenery, renderer)
			check_smoothness(scenery)
			check_textures(scenery)
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
			# Settings: no depth and no mountains leave a flat plateau at map level.
			renderer.out_of_bounds_lowland_depth = 0.0
			renderer.out_of_bounds_mountain_height = 0.0
			assert(renderer.render_dungeon(data))
			var flat := renderer.out_of_bounds_scenery
			for row in range(flat._rows):
				for column in range(flat._columns):
					if under_rock(flat, column, row): continue
					var point := flat._grid_point(column, row)
					var height := flat._grid_height(column, row)
					var lowest := minf(flat.floor_at(point.x, point.y) - OutOfBoundsScenery.RIM_SINK, flat.ground_level)
					assert(height >= lowest - 0.0001 and height <= maxf(flat.floor_at(point.x, point.y) + OutOfBoundsScenery.CLEARANCE, flat.ground_level) + 0.0001)
			renderer.out_of_bounds_lowland_depth = 2.4
			renderer.out_of_bounds_mountain_height = 2.8
			renderer.out_of_bounds_cast_shadows = false
			renderer.out_of_bounds_extent = 10
			assert(renderer.render_dungeon(data))
			assert(renderer.out_of_bounds_scenery.region.size.x < data.map_bounds.size.x + 44.0 and renderer.out_of_bounds_scenery.diagnostics.triangles > 0)
			for chunk in renderer.out_of_bounds_scenery.chunks: assert(chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			renderer.out_of_bounds_extent = 22
			renderer.out_of_bounds_cast_shadows = true
			# Toggles: disabled terrain restores the full border ground, apron and filler.
			renderer.out_of_bounds_scenery_enabled = false
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery == null and not renderer.out_of_bounds_owns_sides())
			for child in renderer.get_children(): assert(not child is OutOfBoundsScenery)
			var north_records := 0
			for record in renderer.cave_background.records:
				if record.external and record.cell.y < data.map_bounds.end.y: north_records += 1
			assert(north_records > 0 and renderer.cave_background.scenery_apron.mesh.get_faces().size() == 24)
			renderer.out_of_bounds_scenery_enabled = true
			renderer.cave_scenery_border_width = 0
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery == null and not renderer.out_of_bounds_owns_sides())
			renderer.cave_scenery_border_width = 6
			assert(renderer.render_dungeon(data) and signature(renderer.out_of_bounds_scenery) == first)
			assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
	assert(floors.size() == 2 and floors[0] != floors[1])
	# Preserved fixtures never acquire out-of-bounds scenery or lose their filler.
	for data in [BenchmarkDungeonFactory.create(), DemoArenaFactory.create_arena(), TestDungeonFactory.create_elevation_test_dungeon()]:
		assert(renderer.render_dungeon(data, true) and renderer.out_of_bounds_scenery == null and not renderer.out_of_bounds_owns_sides())
	renderer.free()
	camera.free()
	print("PASS: plateau out-of-bounds terrain owns west/north/east beyond the layout outline and its one-tile rock buffer (no border ground, north apron or filler there), rim under the buffer rock with a tucked edge over a lowland of small mountains, crack-free shadowed chunks, smooth slopes, rock texture array, per-floor determinism, shade lift, settings, toggles and fixture exemptions")
	quit()
