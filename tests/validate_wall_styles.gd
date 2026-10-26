extends SceneTree
const Snapshots = preload("res://tests/validate_terraces.gd")

func _initialize() -> void: call_deferred("validate")

func appearance(renderer: DungeonRenderer, upper_only: bool = false) -> Array:
	var result := []
	for visual in renderer.fog_visuals:
		var tile: Vector2i = visual.tiles[0]
		if upper_only and renderer.dungeon_data.get_elevation(tile) != 1 and visual.purpose != "ramp": continue
		if upper_only and visual.purpose == EnvironmentGeometryPlan.BOUNDARY: continue
		result.append([visual.tiles, visual.purpose, visual.mesh.transform, visual.mesh.get_aabb(), visual.materials])
	return result

func validate() -> void:
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	var config: DungeonGenerationConfig = TestDungeonFactory.get_default_config().duplicate()
	config.map_size = Vector2i(42, 32)
	var rotations := {}
	var tints := {}
	for seed_value in range(12):
		TestDungeonFactory.rng.seed = seed_value
		var data := TestDungeonFactory.create_configured_dungeon(config)
		data.update_fog(data.player_spawn)
		var snapshot := Snapshots.snapshot(data)
		var state: int = TestDungeonFactory.rng.state
		var walls: Dictionary = {}
		var upper: Array = []
		for ratio in [1.0, 0.75, 0.5]:
			renderer.conventional_wall_height_scale = ratio
			assert(renderer.render_dungeon(data))
			assert(renderer.geometry_diagnostics.validated)
			if ratio == 1.0: upper = appearance(renderer, true)
			else: assert(appearance(renderer, true) == upper)
			var index := 0
			for visual in renderer.fog_visuals:
				var tile: Vector2i = visual.tiles[0]
				var mesh: MeshInstance3D = visual.mesh
				var bounds: AABB = mesh.transform * mesh.get_aabb()
				if visual.wall and data.get_elevation(tile) == 0:
					if ratio == 1.0: walls[index] = bounds
					else:
						var full: AABB = walls[index]
						assert(is_equal_approx(bounds.size.y, full.size.y * ratio))
						assert(is_equal_approx(bounds.end.y - 0.1, (full.end.y - 0.1) * ratio))
						assert(is_equal_approx(bounds.position.x, full.position.x) and is_equal_approx(bounds.position.z, full.position.z))
						assert(is_equal_approx(bounds.size.x, full.size.x) and is_equal_approx(bounds.size.z, full.size.z))
					assert(bounds.position.y <= 0.1) # No floating wall base.
					index += 1
				elif visual.purpose == "floor":
					assert(is_equal_approx(bounds.end.y, data.get_elevation(tile) * DungeonData.ELEVATION_HEIGHT + 0.1))
					assert(is_equal_approx(bounds.size.x, 1.0) and is_equal_approx(bounds.size.z, 1.0))
					if renderer.can_vary_floor(tile):
						tints[visual.materials[0][0].albedo_color] = true
						rotations[posmod(renderer.floor_hash(tile), 4)] = true
						assert(visual.materials[0][0].albedo_color.r >= ModularDungeonVisuals.FLOOR_COLOR.r * 0.96 - 0.001)
						assert(visual.materials[0][0].albedo_color.r <= ModularDungeonVisuals.FLOOR_COLOR.r * 1.04 + 0.001)
				elif visual.purpose == EnvironmentGeometryPlan.BOUNDARY:
					var varied: bool = renderer.geometry_plan.elements.any(func(entry): return entry.id == visual.plan_id and entry.get("ground_variation",false))
					if varied:
						assert(is_equal_approx(bounds.end.y,CaveTerrainBackdrop.varied_top(tile,renderer.floor_visual_seed)))
					else:
						assert(is_equal_approx(bounds.end.y, TerrainFillVisuals.wall_top_offset(0.1, ratio)))
			assert(index > 0)
			renderer.apply_fog(0)
			for visual in renderer.fog_visuals:
				if visual.asset: assert(visual.mesh.get_surface_override_material(0) == visual.materials[0][visual.fog_state])
			assert(Snapshots.snapshot(data) == snapshot and state == TestDungeonFactory.rng.state)
		# Repeat appearance exactly; changing only the visual seed cannot touch data.
		var first := appearance(renderer)
		assert(renderer.render_dungeon(data) and appearance(renderer) == first)
		renderer.floor_visual_seed = 17
		assert(renderer.render_dungeon(data))
		assert(Snapshots.snapshot(data) == snapshot and state == TestDungeonFactory.rng.state)
		renderer.floor_visual_seed = 0
	assert(rotations.size() == 4 and tints.size() > 1)
	# The original asset path is fully reversible. Floor-wall and corner floor
	# surfaces preserve their authored orientation at every height setting.
	var data := DungeonData.new()
	data.rooms = [Rect2i(0, 0, 5, 5)]
	for y in range(5):
		for x in range(5): data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	renderer.floor_variation_enabled = false
	renderer.conventional_wall_height_scale = 1.0
	assert(renderer.render_dungeon(data))
	var old := appearance(renderer)
	renderer.floor_variation_enabled = true
	renderer.floor_quarter_turns_enabled = false
	renderer.floor_color_variation = 0.0
	assert(renderer.render_dungeon(data) and appearance(renderer) == old)
	renderer.free()
	print("PASS: 12 seeded floors, wall scales/anchors/corners, filler caps, unchanged upper geometry/data/RNG, four deterministic rotations, subtle tints/fog and rollback")
	quit()
