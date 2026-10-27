extends SceneTree
const Snapshots = preload("res://tests/validate_terraces.gd")

func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	for shade in [Color.WHITE, Color(0.22, 0.22, 0.22), Color(0.07, 0.07, 0.07)]:
		var base := ModularDungeonVisuals.FILL_COLOR.srgb_to_linear()
		var expected: Color = (ModularDungeonVisuals.FILL_COLOR * shade).srgb_to_linear()
		assert((base * CaveTerrainBackdrop.instance_color(shade, 1.0)).is_equal_approx(expected))
	var config: DungeonGenerationConfig = TestDungeonFactory.get_default_config().duplicate()
	var renderer := DungeonRenderer.new()
	renderer.cave_continuous_ground_enabled = false
	renderer.cave_stone_mapping_enabled = false
	renderer.cave_scenery_border_width = 0 # This suite isolates the original logical footprint.
	root.add_child(renderer)
	var totals := {"floors": 0, "nonwalkable": 0, "existing": 0, "protected_voids": 0, "background": 0, "new_mesh_nodes": 0, "unresolved": 0}
	var rotations: Dictionary = {}
	var tints: Dictionary = {}
	for seed_value in range(20):
		TestDungeonFactory.rng.seed = seed_value
		var data := TestDungeonFactory.create_configured_dungeon(config)
		assert(data.map_bounds == Rect2i(0, 0, 42, 32))
		data.update_fog(data.player_spawn)
		var before := Snapshots.snapshot(data)
		var state: int = TestDungeonFactory.rng.state
		renderer.cave_fill_enabled = false
		assert(renderer.render_dungeon(data))
		var original_upper: Array = []
		for visual in renderer.fog_visuals:
			if visual.purpose in [EnvironmentGeometryPlan.FOUNDATION, EnvironmentGeometryPlan.WALKWAY, "ramp"]:
				original_upper.append([visual.tiles, visual.purpose, visual.mesh.get_aabb(), visual.mesh.transform, visual.materials])
		renderer.cave_fill_enabled = true
		assert(renderer.render_dungeon(data))
		assert(is_instance_valid(renderer.cave_background))
		var backdrop: CaveTerrainBackdrop = renderer.cave_background
		var info := backdrop.diagnostics
		assert(info.violations.is_empty())
		assert(info.nonwalkable == info.existing_terrain + info.protected_voids + info.background_cells)
		assert(backdrop.get_child_count() == info.mesh_nodes and info.mesh_nodes <= 48)
		var instances := 0
		for group in backdrop.batches: instances += group.caps.multimesh.instance_count
		assert(backdrop.records.size() == instances)
		var seen: Dictionary = {}
		for record in backdrop.records:
			assert(data.map_bounds.has_point(record.cell) and (not data.is_walkable(record.cell) or record.underlay) and not seen.has(record.cell))
			seen[record.cell] = true
			assert(not data.reserved_transitions.has(record.cell) or record.underlay)
			var cap: AABB = record.cap_transform * backdrop.caps.multimesh.mesh.get_aabb()
			var body: AABB = record.body_transform * backdrop.bodies.multimesh.mesh.get_aabb()
			assert(is_equal_approx(cap.end.y, record.top))
			assert(record.top <= (TerrainFillVisuals.wall_top_offset(0.1, 1.0) if record.varied else 0.1) + 0.001)
			assert(is_equal_approx(body.position.y, CaveTerrainBackdrop.GROUND_BASE))
			assert(body.end.y <= cap.end.y and body.end.y >= cap.position.y)
			assert(is_equal_approx(cap.size.x, 1) and is_equal_approx(cap.size.z, 1))
			rotations[posmod(renderer.floor_hash(record.cell), 4)] = true
			tints[record.tint] = true
		# Every in-bounds ground void is covered; former safety halos stay low.
		for y in range(data.map_bounds.position.y, data.map_bounds.end.y):
			for x in range(data.map_bounds.position.x, data.map_bounds.end.x):
				var cell := Vector2i(x,y)
				if data.is_walkable(cell): continue
				assert(seen.has(cell) or renderer.geometry_plan.elements.any(func(entry): return entry.cell == cell and entry.purpose == EnvironmentGeometryPlan.BOUNDARY))
		var covered: Dictionary = {}
		for entry in renderer.geometry_plan.elements:
			if entry.purpose in [EnvironmentGeometryPlan.BOUNDARY,EnvironmentGeometryPlan.TERRACE]: covered[entry.cell] = entry
		var rules := CaveTerrainBackdrop.ground_rules(data, covered)
		for record in backdrop.records:
			if record.varied:
				assert(rules.distance[record.cell] > 2 and not rules.protected.has(record.cell) and not record.structural)
				assert(record.top in [TerrainFillVisuals.wall_top_offset(0.1,1.0),TerrainFillVisuals.wall_top_offset(0.1,0.5)])
			if record.underlay or rules.protected.has(record.cell): assert(record.top <= 0.0)
			if covered.has(record.cell) and covered[record.cell].purpose == EnvironmentGeometryPlan.TERRACE:
				assert(is_equal_approx(record.top, covered[record.cell].bounds.position.y))
		var actual_upper: Array = []
		for visual in renderer.fog_visuals:
			if visual.purpose in [EnvironmentGeometryPlan.FOUNDATION, EnvironmentGeometryPlan.WALKWAY, "ramp"]:
				actual_upper.append([visual.tiles, visual.purpose, visual.mesh.get_aabb(), visual.mesh.transform, visual.materials])
			if visual.purpose == EnvironmentGeometryPlan.BOUNDARY:
				assert(visual.mesh.mesh.get_surface_count() == 2)
				assert(visual.materials.size() == 2)
		assert(actual_upper == original_upper)
		renderer.apply_fog(0)
		for record in backdrop.records:
			var bright: bool = data.is_bright(record.cell) or (record.adjacent and data.is_bright(record.owner))
			assert(record.shade == (Color.WHITE if bright else renderer.dim_material.albedo_color))
		renderer.apply_fog(1)
		for record in backdrop.records:
			var bright: bool = data.is_bright(record.cell) or (record.adjacent and data.is_bright(record.owner))
			assert(record.shade == (Color.WHITE if bright else renderer.other_elevation_material.albedo_color))
		assert(before == Snapshots.snapshot(data) and TestDungeonFactory.rng.state == state)
		var transforms: Array = []
		for record in backdrop.records: transforms.append(record.cap_transform)
		assert(renderer.render_dungeon(data))
		for index in range(transforms.size()): assert(transforms[index] == renderer.cave_background.records[index].cap_transform)
		totals.floors += 1
		totals.nonwalkable += info.nonwalkable
		totals.existing += info.existing_terrain
		totals.protected_voids += info.protected_voids
		totals.background += info.background_cells
		totals.new_mesh_nodes += info.mesh_nodes
	assert(rotations.size() == 4 and tints.size() > 1)
	# The hash implements a probability, not an exact quota on each small map.
	var full := 0
	var changed := 0
	for y in range(100):
		for x in range(100):
			var cell := Vector2i(x,y)
			if is_equal_approx(CaveTerrainBackdrop.varied_top(cell,0), TerrainFillVisuals.wall_top_offset(0.1,1.0)): full += 1
			if CaveTerrainBackdrop.varied_top(cell,0) != CaveTerrainBackdrop.varied_top(cell,1): changed += 1
	assert(full > 3800 and full < 4200 and changed > 3000)
	# Flat configured maps also fill their explicit footprint, not just room bounds.
	var flat := DungeonData.new()
	flat.map_bounds = Rect2i(0,0,12,12)
	flat.rooms = [Rect2i(4,4,3,3)]
	flat.room_elevations = [0]
	for y in range(4,7):
		for x in range(4,7): flat.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR)
	assert(renderer.render_dungeon(flat) and is_instance_valid(renderer.cave_background))
	assert(renderer.cave_background.diagnostics.protected_voids == 0)
	for y in range(12):
		for x in range(12):
			var cell := Vector2i(x,y)
			assert(flat.is_walkable(cell) or renderer.terrain_fill_cells.has(cell) or renderer.cave_background.records.any(func(record): return record.cell == cell))
	# Explicit exemptions and reversible new background/cap variation controls.
	for fixture: DungeonData in [BenchmarkDungeonFactory.create(), DemoArenaFactory.create_arena(), TestDungeonFactory.create_elevation_test_dungeon()]:
		assert(renderer.render_dungeon(fixture, true))
		assert(not renderer.cave_fill_active and renderer.cave_background == null)
	TestDungeonFactory.rng.seed = 4
	var data := TestDungeonFactory.create_configured_dungeon(config)
	renderer.cave_ceiling_variation_enabled = false
	assert(renderer.render_dungeon(data))
	for record in renderer.cave_background.records:
		assert(record.cap_transform.basis.is_equal_approx(Basis.from_scale(Vector3.ONE * 0.5)) and record.tint == 1.0)
	var file := FileAccess.open("res://.godot/quality_diagnostics/cave_background.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(totals, "\t"))
	file.close()
	print("CAVE METRICS ", JSON.stringify(totals))
	renderer.free()
	print("PASS: 20 identical floors, full ground coverage/low protected underlays, terrace joins, bounded batches, height eligibility, unchanged upper structures/data/RNG, fog, determinism and exemptions")
	quit()
