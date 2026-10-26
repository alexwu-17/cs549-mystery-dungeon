extends SceneTree
const Snapshots = preload("res://tests/validate_terraces.gd")

class MissingFloorOnce extends DungeonRenderer:
	var omit_once := true
	func create_floor_tile(tile: Vector2i) -> void:
		if omit_once:
			omit_once = false
			return
		super.create_floor_tile(tile)

func _initialize() -> void: call_deferred("validate")

func inject_plan_defects(renderer: DungeonRenderer, data: DungeonData) -> void:
	var plan := renderer.geometry_plan.duplicate(true)
	var original := plan.duplicate(true)
	for index in range(plan.elements.size()):
		if plan.elements[index].purpose == EnvironmentGeometryPlan.FOUNDATION:
			plan.elements.remove_at(index)
			break
	for record in plan.elements:
		if record.purpose == EnvironmentGeometryPlan.WALKWAY:
			record.bounds.size.y = 3.0
			break
	var orphan := EnvironmentGeometryPlan.box_record(EnvironmentGeometryPlan.TERRACE, Vector2i(1000, 1000), Vector2i(-99, -99), 1.0, 2.0)
	orphan["distance"] = 1
	orphan["parent"] = Vector2i(999, 1000)
	plan.elements.append(orphan)
	var before := Snapshots.snapshot(data)
	var state: int = TestDungeonFactory.rng.state
	var repaired := EnvironmentGeometryPlan.repair(plan, data, TerrainFillVisuals.layout(data, renderer.terrain_fill_margin))
	assert(not repaired.repairs.is_empty() and repaired.unresolved.is_empty())
	assert(repaired.plan == original)
	assert(before == Snapshots.snapshot(data) and state == TestDungeonFactory.rng.state)

func inject_instance_defects(renderer: DungeonRenderer) -> void:
	var removed := false
	var shifted := false
	for visual in renderer.fog_visuals:
		if visual.purpose != EnvironmentGeometryPlan.FOUNDATION: continue
		if not removed:
			visual.mesh.free() # Retain the stale registry entry to test safe recovery.
			removed = true
		elif not shifted:
			visual.mesh.position.y += 0.25
			shifted = true
			break
	var orphan := EnvironmentGeometryPlan.box_record(EnvironmentGeometryPlan.TERRACE, Vector2i(1000, 1000), Vector2i(-99, -99), 1.0, 2.0)
	renderer.create_planned_element(orphan)
	var unregistered := MeshInstance3D.new()
	unregistered.mesh = BoxMesh.new()
	unregistered.position = Vector3(999, 4, 999)
	renderer.add_child(unregistered)
	assert(renderer.verify_environment_geometry())
	assert(not is_instance_valid(unregistered) and renderer.geometry_diagnostics.repairs.size() >= 4)
	assert(EnvironmentGeometryPlan.inspect_instances(renderer.geometry_plan, renderer.dungeon_data, renderer.fog_visuals).is_empty())

func check_fading(renderer: DungeonRenderer, data: DungeonData) -> void:
	var chosen: Dictionary
	for visual in renderer.fog_visuals:
		if visual.purpose == EnvironmentGeometryPlan.FOUNDATION:
			chosen = visual
			break
	assert(not chosen.is_empty())
	var center: Vector3 = chosen.mesh.global_position
	var direction := center - renderer.get_entity_world_position(data.player_spawn)
	direction.y = 0.0
	if direction.length_squared() < 0.01: direction = Vector3.BACK
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = center + direction.normalized() * 10 + Vector3.UP * 6
	var points: Array[Vector3] = [center - (camera.position - center).normalized() * 3]
	camera.look_at(points[0])
	renderer.update_occlusion(camera, data.player_spawn, points)
	assert(chosen.occluded and chosen.mesh.visible and is_equal_approx(chosen.mesh.transparency, 0.8))
	assert(chosen.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	renderer.apply_fog(data.get_elevation(data.player_spawn))
	assert(is_equal_approx(chosen.mesh.transparency, 0.8))
	renderer.update_occlusion(camera, data.player_spawn, [])
	assert(not chosen.occluded and chosen.mesh.transparency == 0.0)
	assert(chosen.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	camera.free()

func validate() -> void:
	var renderer := DungeonRenderer.new()
	renderer.cave_fill_enabled = false # Historical foundation/filler geometry comparison.
	root.add_child(renderer)
	var config: DungeonGenerationConfig = TestDungeonFactory.get_default_config().duplicate()
	config.map_size = Vector2i(42, 32)
	var totals := {"floors": 0, "before_exposed_edges": 0, "after_missing_foundations": 0,
		"foundations": 0, "walkway_supports": 0, "terraces": 0, "ramp_owned_filler_removed": 0,
		"unexpected_fallbacks": 0, "unresolved": 0, "injected_repairs": 0}
	for seed_value in range(30):
		TestDungeonFactory.rng.seed = seed_value
		var data := TestDungeonFactory.create_configured_dungeon(config)
		data.update_fog(data.player_spawn)
		var snapshot := Snapshots.snapshot(data)
		var rng_state: int = TestDungeonFactory.rng.state
		renderer.geometry_validation_enabled = false
		assert(renderer.render_dungeon(data))
		var before := Snapshots.counts(renderer, data)
		totals.before_exposed_edges += before.exposed_edges
		var lower: Array = []
		for visual in renderer.fog_visuals:
			if visual.filler and data.get_tile(visual.fill_owner) == DungeonData.TileType.RAMP:
				totals.ramp_owned_filler_removed += 1
			if visual.filler and data.get_elevation(visual.fill_owner) == 0 and data.get_tile(visual.fill_owner) != DungeonData.TileType.RAMP:
				lower.append([visual.tiles, visual.mesh.get_aabb(), visual.mesh.transform])
		renderer.geometry_validation_enabled = true
		assert(renderer.render_dungeon(data))
		assert(renderer.validated_geometry_active and renderer.geometry_diagnostics.validated)
		assert(renderer.geometry_diagnostics.unresolved.is_empty())
		assert(EnvironmentGeometryPlan.validate(renderer.geometry_plan, data).is_empty())
		assert(EnvironmentGeometryPlan.inspect_instances(renderer.geometry_plan, data, renderer.fog_visuals).is_empty())
		var actual_lower: Array = []
		var columns: Dictionary = {}
		var terrace_cells: Dictionary = {}
		for visual in renderer.fog_visuals:
			assert(visual.mesh.has_meta("geometry_owner") and visual.mesh.has_meta("geometry_purpose"))
			if visual.purpose == EnvironmentGeometryPlan.BOUNDARY:
				actual_lower.append([visual.tiles, visual.mesh.get_aabb(), visual.mesh.transform])
			elif visual.purpose == EnvironmentGeometryPlan.FOUNDATION:
				totals.foundations += 1
				var tile: Vector2i = visual.owner
				columns[tile] = int(columns.get(tile, 0)) + 1
			elif visual.purpose == EnvironmentGeometryPlan.WALKWAY:
				totals.walkway_supports += 1
				assert(visual.mesh.get_aabb().size.y <= 1.001)
			elif visual.purpose == EnvironmentGeometryPlan.TERRACE:
				totals.terraces += 1
				terrace_cells[visual.tiles[0]] = true
		assert(actual_lower.size() == lower.size())
		for index in range(lower.size()):
			assert(actual_lower[index][0] == lower[index][0])
			assert(EnvironmentGeometryPlan.same_bounds(actual_lower[index][1], lower[index][1]))
			assert(actual_lower[index][2].is_equal_approx(lower[index][2]))
		for tile: Vector2i in data.tiles:
			if EnvironmentGeometryPlan.upper_room(data, tile): assert(columns.get(tile, 0) == 3)
		for record in renderer.geometry_plan.elements:
			if record.purpose != EnvironmentGeometryPlan.TERRACE: continue
			assert(record.parent == record.owner or terrace_cells.has(record.parent))
		assert(snapshot == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
		renderer.apply_fog(data.get_elevation(data.player_spawn))
		assert(snapshot == Snapshots.snapshot(data))
		if seed_value == 0:
			inject_plan_defects(renderer, data)
			inject_instance_defects(renderer)
			check_fading(renderer, data)
			totals.injected_repairs += renderer.geometry_diagnostics.repairs.size()
		# Replay plan output is identical, including source/owner metadata.
		var replay := EnvironmentGeometryPlan.build(data, TerrainFillVisuals.layout(data, renderer.terrain_fill_margin), renderer.geometry_plan.options)
		assert(replay == renderer.geometry_plan)
		totals.floors += 1
		totals.unexpected_fallbacks += int(renderer.geometry_diagnostics.fallback)
		totals.unresolved += renderer.geometry_diagnostics.unresolved.size()
		if (seed_value + 1) % 10 == 0: print("ENVIRONMENT PROGRESS ", seed_value + 1, "/30")
	# Bounded, structure-only fallback and explicitly preserved visual fixtures.
	var data := TestDungeonFactory.create_fallback_dungeon()
	assert(renderer.render_dungeon(data, false, true))
	assert(renderer.geometry_diagnostics.fallback and renderer.geometry_diagnostics.validated)
	for record in renderer.geometry_plan.elements: assert(record.purpose != EnvironmentGeometryPlan.TERRACE)
	var fallback_renderer := MissingFloorOnce.new()
	root.add_child(fallback_renderer)
	assert(fallback_renderer.render_dungeon(data))
	assert(fallback_renderer.geometry_diagnostics.fallback and fallback_renderer.geometry_diagnostics.validated)
	assert(not fallback_renderer.geometry_diagnostics.fallback_reasons.is_empty())
	fallback_renderer.free()
	for fixture: DungeonData in [BenchmarkDungeonFactory.create(), DemoArenaFactory.create_arena(), TestDungeonFactory.create_elevation_test_dungeon()]:
		renderer.geometry_validation_enabled = false
		assert(renderer.render_dungeon(fixture))
		var old := Snapshots.signature(renderer)
		renderer.geometry_validation_enabled = true
		assert(renderer.render_dungeon(fixture, true))
		assert(not renderer.validated_geometry_active and Snapshots.signature(renderer) == old)
	var output := "res://.godot/quality_diagnostics/environment_geometry.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(totals, "\t"))
	file.close()
	print("ENVIRONMENT METRICS ", JSON.stringify(totals))
	renderer.free()
	print("PASS: 30 identical layouts, complete three-layer foundations, shallow walkways, connected terraces, lower backing, plan/instance repair, fade restoration, fallback and fixture exemptions")
	quit()
