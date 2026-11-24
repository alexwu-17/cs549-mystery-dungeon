extends SceneTree
## Out-of-bounds foliage: seasons per floor (summer kinds and meadow paint,
## winter snow, none), placement band and rim height, shade following the
## terrain, determinism, settings and rendering-only.
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("validate")


func foliage_of(renderer: DungeonRenderer) -> OutOfBoundsFoliage:
	if renderer.out_of_bounds_scenery == null: return null
	for child in renderer.out_of_bounds_scenery.get_children():
		if child is OutOfBoundsFoliage: return child
	return null


func signature(foliage: OutOfBoundsFoliage) -> Array:
	return [foliage.counts.duplicate(), foliage.placements[0], foliage.placements[foliage.placements.size() - 1]]


func render(renderer: DungeonRenderer, data: DungeonData, floor_number: int) -> OutOfBoundsFoliage:
	renderer.floor_number = floor_number
	assert(renderer.render_dungeon(data))
	return foliage_of(renderer)


func validate() -> void:
	TestDungeonFactory.rng.seed = 7
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.regular_enemies_enabled = false
	root.add_child(main)
	Helper.complete_introduction(main)
	var renderer: DungeonRenderer = main.dungeon_renderer
	var data: DungeonData = main.dungeon
	var tiles: Dictionary = data.tiles.duplicate()
	var state: int = TestDungeonFactory.rng.state
	# Floor 1 (Main sets the floor number): summer foliage and meadow paint.
	assert(renderer.floor_number == 1 and renderer.floor_season() == OutOfBoundsFoliage.Season.SUMMER_SPRING)
	var foliage := foliage_of(renderer)
	var scenery := renderer.out_of_bounds_scenery
	assert(foliage != null and scenery.diagnostics.foliage == foliage.counts)
	for kind in ["trees", "bushes", "plants", "flowers", "grass"]: assert(foliage.counts[kind] > 50)
	assert(foliage.counts.logs > 0 and foliage.counts.stumps > 0)
	assert(scenery.material.get_shader_parameter("grass_amount") == 1.0 and scenery.material.get_shader_parameter("snow_amount") == 0.0)
	var instances := 0
	for node: MultiMeshInstance3D in foliage.get_children(): instances += node.multimesh.instance_count
	assert(instances == foliage.placements.size())
	for placement in foliage.placements:
		var t: Transform3D = placement[2]
		var distance := scenery.map_distance(t.origin.x, t.origin.z)
		assert(distance >= OutOfBoundsFoliage.NEAR - 0.001 and distance <= OutOfBoundsFoliage.FAR + 0.5)
		# Near the rim nothing (trees: barely anything) rises above map level.
		if distance < 3.0 and placement[0] != "grass" and placement[0] != "logs":
			var top: float = t.origin.y + 0.04 + foliage._mesh(placement[1]).get_aabb().end.y * t.basis.get_scale().y
			assert(top <= scenery.ground_level + (0.25 if placement[0] == "trees" else 0.0) + 0.01)
	# Stones never take the meadow paint.
	for child in scenery.get_children():
		if child is OutOfBoundsStones:
			for stone in child.placements: assert(stone[1].a == 0.0)
	# Foliage follows the terrain shade (it changes with the player's elevation).
	scenery.apply_shade(Color(0.3, 0.4, 0.5))
	var shade := scenery.current_shade()
	assert(foliage._grass_materials[0].get_shader_parameter("shade").is_equal_approx(Color(shade.r, shade.g, shade.b)))
	var entry: Array = foliage._materials[0]
	assert(entry[0].albedo_color.is_equal_approx(Color(entry[1].r * shade.r, entry[1].g * shade.g, entry[1].b * shade.b, 1.0)))
	# Same floor, same foliage; rendering never touches gameplay data or generation RNG.
	var first := signature(foliage)
	assert(signature(render(renderer, data, 1)) == first)
	assert(data.tiles == tiles and TestDungeonFactory.rng.state == state)
	# Floor 2: winter (snowy kinds only, snow instead of meadow paint).
	foliage = render(renderer, data, 2)
	scenery = renderer.out_of_bounds_scenery
	assert(foliage.season == OutOfBoundsFoliage.Season.WINTER and foliage.counts.trees > 50)
	for kind in ["plants", "flowers", "grass"]: assert(foliage.counts[kind] == 0)
	for placement in foliage.placements: assert("Snow" in placement[1])
	assert(scenery.material.get_shader_parameter("grass_amount") == 0.0 and scenery.material.get_shader_parameter("snow_amount") == 0.85)
	# Floor 3: none (bare terrain); floor 4 repeats the list (summer).
	assert(render(renderer, data, 3) == null)
	assert(renderer.out_of_bounds_scenery.material.get_shader_parameter("grass_amount") in [null, 0.0])
	assert(render(renderer, data, 4).season == OutOfBoundsFoliage.Season.SUMMER_SPRING)
	# Settings: density 0 removes a kind; disabled removes the node.
	renderer.out_of_bounds_grass_density = 0.0
	foliage = render(renderer, data, 1)
	assert(foliage.counts.grass == 0 and foliage.counts.trees > 50)
	renderer.out_of_bounds_grass_density = 1.0
	renderer.out_of_bounds_foliage_enabled = false
	assert(render(renderer, data, 1) == null)
	renderer.out_of_bounds_foliage_enabled = true
	assert(data.tiles == tiles and TestDungeonFactory.rng.state == state)
	print("OUT OF BOUNDS FOLIAGE VALIDATION PASS")
	quit()
