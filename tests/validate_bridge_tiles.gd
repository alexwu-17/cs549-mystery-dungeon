extends SceneTree
## Bridge tiles on straight elevated corridors and the broken-bridge ratio.
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("validate")


func rails_per_tile(renderer: DungeonRenderer) -> Dictionary:
	var result: Dictionary = {}
	for visual in renderer.fog_visuals:
		if visual.purpose == EnvironmentGeometryPlan.BRIDGE_RAIL:
			result[visual.owner] = int(result.get(visual.owner, 0)) + 1
	return result


func validate() -> void:
	var normal_rails := ModularDungeonVisuals.BRIDGE.get_surface_count() - 1
	var broken_rails := ModularDungeonVisuals.BRIDGE_BROKEN.get_surface_count() - 1
	assert(broken_rails != normal_rails)
	assert(is_equal_approx(ModularDungeonVisuals.bridge_deck_top(ModularDungeonVisuals.BRIDGE), ModularDungeonVisuals.bridge_deck_top(ModularDungeonVisuals.BRIDGE_BROKEN)))
	TestDungeonFactory.rng.seed = 3
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.regular_enemies_enabled = false
	root.add_child(main)
	Helper.complete_introduction(main)
	var renderer: DungeonRenderer = main.dungeon_renderer
	var data: DungeonData = main.dungeon
	var bridges: Array[Vector2i] = []
	for tile: Vector2i in data.tiles:
		if EnvironmentGeometryPlan.bridge_tile(data, tile): bridges.append(tile)
	assert(bridges.size() >= 10)
	var tiles_before: Dictionary = data.tiles.duplicate()
	var rng_state: int = TestDungeonFactory.rng.state
	for ratio in [0.0, 1.0, renderer.upper_corridor_broken_bridge_ratio]:
		renderer.upper_corridor_broken_bridge_ratio = ratio
		assert(renderer.render_dungeon(data) and renderer.geometry_diagnostics.validated)
		var rails := rails_per_tile(renderer)
		var broken := 0
		for tile in bridges:
			# Every bridge tile: one deck on the floor plane, rails, no stone walkway support.
			assert(rails.get(tile, 0) == (broken_rails if renderer.is_broken_bridge(tile) else normal_rails))
			if renderer.is_broken_bridge(tile): broken += 1
			var decks := 0
			for visual in renderer.fog_visuals:
				if visual.owner != tile: continue
				assert(visual.purpose != EnvironmentGeometryPlan.WALKWAY)
				if visual.purpose == "floor":
					decks += 1
					var top: float = (visual.mesh.transform * visual.mesh.get_aabb()).end.y
					assert(is_equal_approx(top, data.get_elevation(tile) * DungeonData.ELEVATION_HEIGHT + 0.1))
			assert(decks == 1)
		if ratio == 0.0: assert(broken == 0)
		if ratio == 1.0: assert(broken == bridges.size())
	# Default share over many coordinates stays near the setting and is stable.
	var hits := 0
	for x in range(100):
		for y in range(100):
			if renderer.is_broken_bridge(Vector2i(x, y)): hits += 1
			assert(renderer.is_broken_bridge(Vector2i(x, y)) == renderer.is_broken_bridge(Vector2i(x, y)))
	assert(absf(hits / 10000.0 - renderer.upper_corridor_broken_bridge_ratio) < 0.02)
	# Broken tiles face either way about half the time each.
	var flipped := 0
	var counted := 0
	for x in range(100):
		for y in range(100):
			if not renderer.is_broken_bridge(Vector2i(x, y)): continue
			counted += 1
			if renderer.is_flipped_bridge(Vector2i(x, y)): flipped += 1
	assert(absf(float(flipped) / counted - 0.5) < 0.1)
	# Rendering only: topology and generation RNG untouched.
	assert(data.tiles == tiles_before and TestDungeonFactory.rng.state == rng_state)
	# Plank decks: vertex-colored boards; the flat model deck returns when turned off.
	renderer.upper_corridor_broken_bridge_ratio = 0.5
	for planks in [true, false]:
		renderer.bridge_planks_enabled = planks
		assert(renderer.render_dungeon(data) and renderer.geometry_diagnostics.validated)
		for visual in renderer.fog_visuals:
			if visual.purpose != "floor" or not bridges.has(visual.owner): continue
			var mesh: Mesh = visual.mesh.mesh
			assert(mesh.surface_get_material(0).vertex_color_use_as_albedo == planks)
			assert(is_equal_approx((visual.mesh.transform * visual.mesh.get_aabb()).end.y, DungeonData.ELEVATION_HEIGHT + 0.1))
	renderer.upper_corridor_bridges_enabled = false
	assert(renderer.render_dungeon(data) and rails_per_tile(renderer).is_empty())
	print("PASS: straight elevated corridors draw bridge decks on the floor plane without walkway supports; broken share none/all/default " + str(snappedf(hits / 10000.0, 0.001)) + " matches the ratio, flipped " + str(snappedf(float(flipped) / counted, 0.01)) + " of broken, deterministic, rendering only")
	quit()
