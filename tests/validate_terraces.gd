extends SceneTree

func _initialize() -> void: call_deferred("validate")

static func snapshot(data: DungeonData) -> Dictionary:
	var result := {}
	for property in data.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var value: Variant = data.get(property.name)
		result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

static func signature(renderer: DungeonRenderer) -> Array:
	var result := []
	for visual in renderer.fog_visuals:
		result.append([visual.tiles, visual.wall, visual.filler, visual.mesh.mesh.get_aabb(), visual.mesh.transform, visual.get("fill_owner", Vector2i.ZERO)])
	return result

static func blocks_sampled_sprite(bounds: AABB, data: DungeonData, lower: Array[Vector2i]) -> bool:
	# Independent perspective segment checks against actual rendered bounds.
	var pitch := deg_to_rad(35.0)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * Vector3(0, 10, 8).length()
	var up := Vector3(0, cos(pitch), -sin(pitch))
	for tile in lower:
		if absf(bounds.get_center().x - tile.x) > 1.5 or bounds.end.z < tile.y - 1.5 or bounds.position.z > tile.y + offset.z: continue
		var feet := Vector3(tile.x, data.surface_elevation(tile) * DungeonData.ELEVATION_HEIGHT + DungeonRenderer.FLOOR_THICKNESS / 2.0, tile.y)
		for height in [0.15, 0.8, 1.5]:
			for side in [-0.4, 0.0, 0.4]:
				if bounds.intersects_segment(feet + offset, feet + up * height + Vector3(side, 0, 0)) != null: return true
	return false

static func counts(renderer: DungeonRenderer, data: DungeonData) -> Dictionary:
	var result := {"upper": 0, "decorative": 0, "ground": 0, "overlap": 0,
		"ray_overlap": 0, "exposed_edges": 0, "skirts": 0}
	var backing: Dictionary = {}
	var skirts: Dictionary = {}
	var lower: Array[Vector2i] = []
	for tile: Vector2i in data.tiles:
		if data.is_walkable(tile) and data.get_elevation(tile) == 0: lower.append(tile)
	for visual in renderer.fog_visuals:
		if not visual.filler: continue
		var actual_bounds: AABB = visual.mesh.global_transform * visual.mesh.get_aabb()
		if visual.get("platform_edge", false):
			skirts[Vector3i(visual.fill_owner.x, visual.fill_owner.y, DungeonData.CARDINALS.find(visual.edge_direction))] = true
		else: backing[visual.tiles[0]] = actual_bounds.end.y
		var owner: Vector2i = visual.fill_owner
		if data.get_elevation(owner) != 1 or data.get_room_id(owner) < 0: continue
		var bounds: AABB = visual.mesh.global_transform * visual.mesh.get_aabb()
		var top := bounds.end.y
		if visual.get("platform_edge", false):
			result.skirts += 1
		else:
			result.upper += int(top > 0.11)
			result.decorative += int(top > 0.11 and top < 3.0)
			result.ground += int(top <= 0.11)
		if top > 0.11 and UpperTerrainVisuals.camera_risk(visual.tiles[0], top, lower, 35.0):
			result.overlap += 1
		if top > 0.11 and blocks_sampled_sprite(bounds, data, lower): result.ray_overlap += 1
	var underside := DungeonData.ELEVATION_HEIGHT + 0.1 + (ModularDungeonVisuals.FLOOR.get_aabb().position.y - ModularDungeonVisuals.FLOOR_TOP) * ModularDungeonVisuals.SOURCE_SCALE
	for tile: Vector2i in data.tiles:
		if not data.is_walkable(tile) or data.get_elevation(tile) != 1 or data.get_room_id(tile) < 0: continue
		for direction: Vector2i in DungeonData.CARDINALS:
			var next := tile + direction
			if data.is_walkable(next): continue
			if backing.get(next, -INF) >= underside - 0.001: continue
			if skirts.has(Vector3i(tile.x, tile.y, DungeonData.CARDINALS.find(direction))): continue
			result.exposed_edges += 1
	return result

func check_fog_restoration(renderer: DungeonRenderer, data: DungeonData) -> void:
	for visual in renderer.fog_visuals:
		if not visual.filler or visual.get("platform_edge", false): continue
		var tile: Vector2i = visual.tiles[0]
		if not renderer.terrain_fill_cells[tile].get("terrace", false): continue
		var mesh: MeshInstance3D = visual.mesh
		var center := mesh.global_transform * mesh.get_aabb().get_center()
		var owner: Vector2i = visual.fill_owner
		var outward := center - renderer.get_entity_world_position(owner)
		outward.y = 0
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = center + outward.normalized() * 8.0 + Vector3.UP * 6.0
		var points: Array[Vector3] = [center - (camera.position - center).normalized() * 3.0]
		camera.look_at(points[0])
		var before := snapshot(data)
		renderer.update_occlusion(camera, owner, points)
		assert(visual.occluded and mesh.visible and is_equal_approx(mesh.transparency, 0.8))
		assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		renderer.apply_fog(1)
		assert(visual.occluded and is_equal_approx(mesh.transparency, 0.8))
		renderer.update_occlusion(camera, owner, [])
		assert(not visual.occluded and mesh.transparency == 0.0 and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		assert(snapshot(data) == before)
		camera.free()
		return
	assert(false, "Need a visible terrace fixture to test presentation restoration")

func validate() -> void:
	var config: DungeonGenerationConfig = TestDungeonFactory.get_default_config().duplicate()
	config.map_size = Vector2i(42, 32)
	var renderer := DungeonRenderer.new()
	renderer.geometry_validation_enabled = false # Historical terrace-only comparison.
	root.add_child(renderer)
	var totals: Array[Dictionary] = []
	for index in range(3): totals.append({"upper": 0, "decorative": 0, "ground": 0, "overlap": 0, "ray_overlap": 0, "exposed_edges": 0, "skirts": 0})
	for seed_value in range(30):
		TestDungeonFactory.rng.seed = seed_value
		var data := TestDungeonFactory.create_configured_dungeon(config)
		data.update_fog(data.player_spawn)
		var before := snapshot(data)
		var state: int = TestDungeonFactory.rng.state
		var original := TerrainFillVisuals.layout(data, renderer.terrain_fill_margin)
		var lower_signature: Array = []
		for mode in range(3):
			renderer.upper_terrain_mode = mode
			renderer.render_dungeon(data)
			renderer.apply_fog(data.get_elevation(data.player_spawn))
			assert(snapshot(data) == before and TestDungeonFactory.rng.state == state)
			var actual_lower: Array = []
			for visual in renderer.fog_visuals:
				if visual.filler:
					if data.get_elevation(visual.fill_owner) == 0:
						actual_lower.append([visual.tiles, visual.mesh.mesh.get_aabb(), visual.mesh.transform, visual.materials])
				elif data.get_elevation(visual.tiles[0]) == 0:
					actual_lower.append([visual.tiles, visual.mesh.mesh.get_aabb(), visual.mesh.transform, visual.materials])
			if mode == 0: lower_signature = actual_lower
			else: assert(actual_lower == lower_signature)
			var measured := counts(renderer, data)
			for key in measured: totals[mode][key] += measured[key]
			if mode > 0:
				assert(measured.overlap == 0 and measured.ray_overlap == 0)
				for tile: Vector2i in renderer.terrain_fill_cells:
					var entry: Dictionary = renderer.terrain_fill_cells[tile]
					assert(not data.is_walkable(tile))
					if entry.get("decorative", false):
						assert(not data.reserved_transitions.has(tile))
						assert(entry.top <= 3.1)
						if entry.top > 0.11: assert(entry.distance <= renderer.upper_filler_max_distance)
				# Entire helper output is replayable and its input layout is immutable.
				var saved := original.duplicate(true)
				var a := UpperTerrainVisuals.prepare(data, original, mode, 3, 1, true, 1, 35)
				var b := UpperTerrainVisuals.prepare(data, original, mode, 3, 1, true, 1, 35)
				assert(a == b and original == saved)
				for visual in renderer.fog_visuals:
					if not visual.filler: continue
					assert(visual.mesh.get_surface_override_material(0) == visual.materials[0][visual.fog_state])
		# New terrain is never interactive: the original traversal graph is intact.
		assert(TestDungeonFactory.validate_floor(data))
		if seed_value == 0: check_fog_restoration(renderer, data)
		if (seed_value + 1) % 10 == 0: print("TERRACE PROGRESS ", seed_value + 1, "/30")
	# No changes to exempt presentations, including an explicitly preserved floor.
	for data: DungeonData in [BenchmarkDungeonFactory.create(), DemoArenaFactory.create_arena(), TestDungeonFactory.create_elevation_test_dungeon()]:
		renderer.upper_terrain_mode = UpperTerrainVisuals.Mode.UNLIMITED
		renderer.render_dungeon(data)
		var old := signature(renderer)
		renderer.upper_terrain_mode = UpperTerrainVisuals.Mode.TERRACES
		renderer.render_dungeon(data)
		assert(signature(renderer) == old)
	var data := TestDungeonFactory.create_fallback_dungeon()
	renderer.upper_terrain_mode = UpperTerrainVisuals.Mode.UNLIMITED
	renderer.render_dungeon(data)
	var old := signature(renderer)
	renderer.upper_terrain_mode = UpperTerrainVisuals.Mode.TERRACES
	renderer.render_dungeon(data, true)
	assert(signature(renderer) == old)
	# Independent bound, width, and irregularity controls.
	var original := TerrainFillVisuals.layout(data, 3)
	for maximum in [0, 1, 2, 4]:
		var bounded := UpperTerrainVisuals.prepare(data, original, UpperTerrainVisuals.Mode.TERRACES, maximum, 1, false, 1, 35)
		for entry in bounded.cells.values():
			if entry.get("decorative", false) and entry.top > 0.11: assert(entry.distance <= maximum)
	var upper_only := DungeonData.new()
	upper_only.rooms = [Rect2i(4, 4, 5, 5)]
	upper_only.room_elevations = [1]
	for y in range(4, 9):
		for x in range(4, 9): upper_only.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 1)
	renderer.render_dungeon(upper_only)
	for visual in renderer.fog_visuals: assert(visual.mesh.get_aabb().size.y > 0)
	print("TERRACE METRICS seeds=30 size=42x32 modes=[unlimited,bounded,terraces] ", JSON.stringify(totals))
	var file := FileAccess.open("res://.godot/quality_diagnostics/terrace_metrics.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"seeds": 30, "size": [42, 32], "modes": ["unlimited", "bounded", "terraces"], "totals": totals}, "\t"))
	file.close()
	renderer.free()
	print("PASS: all gameplay properties/RNG and lower visuals unchanged, bounded bands, safety proxy, fog materials, deterministic replay, fixture preservation")
	quit()
