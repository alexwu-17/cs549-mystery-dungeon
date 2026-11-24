extends SceneTree
## Boulders and rubble on the out-of-bounds terrain: placement band, rim height,
## shared shading, per-stone tint, determinism, settings and rendering-only.
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("validate")


func stones_of(renderer: DungeonRenderer) -> OutOfBoundsStones:
	if renderer.out_of_bounds_scenery == null: return null
	for child in renderer.out_of_bounds_scenery.get_children():
		if child is OutOfBoundsStones: return child
	return null


func signature(stones: OutOfBoundsStones) -> Array:
	return [stones.placements.size(), stones.placements[0], stones.placements[stones.placements.size() - 1]]


func validate() -> void:
	TestDungeonFactory.rng.seed = 7
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.regular_enemies_enabled = false
	root.add_child(main)
	Helper.complete_introduction(main)
	var renderer: DungeonRenderer = main.dungeon_renderer
	var data: DungeonData = main.dungeon
	var scenery := renderer.out_of_bounds_scenery
	var stones := stones_of(renderer)
	assert(stones != null and stones.counts.boulders > 50 and stones.counts.rubble > stones.counts.boulders)
	assert(scenery.diagnostics.stones == stones.counts)
	var tints: Dictionary = {}
	for node: MultiMeshInstance3D in stones.get_children():
		# Shared terrain material, so stones follow the ground's fog shade.
		assert(node.material_override == scenery.material and node.multimesh.use_colors)
	var instances := 0
	for node: MultiMeshInstance3D in stones.get_children(): instances += node.multimesh.instance_count
	assert(instances == stones.placements.size() and instances == stones.counts.boulders + stones.counts.rubble)
	for placement in stones.placements:
		var t: Transform3D = placement[0]
		var distance := scenery.map_distance(t.origin.x, t.origin.z)
		assert(distance >= OutOfBoundsStones.NEAR * 0.8 - 0.001 and distance <= OutOfBoundsStones.FAR + 0.5)
		if distance < 2.5:
			var mesh: Mesh = stones.get_child(0).multimesh.mesh
			for node: MultiMeshInstance3D in stones.get_children():
				if node.name == "Stones_%d" % placement[2]: mesh = node.multimesh.mesh
			var top := -INF
			for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: top = maxf(top, (t * vertex).y)
			assert(top <= scenery.ground_level - 0.04 + 0.001)
		var tint: Color = placement[1]
		assert(tint.g > 0.6 and tint.g < 1.5)
		tints[snappedf(tint.g, 0.01)] = true
	assert(tints.size() > 10)
	# Same floor, same stones; rendering never touches gameplay data or generation RNG.
	var first := signature(stones)
	var boulders: int = stones.counts.boulders
	var tiles: Dictionary = data.tiles.duplicate()
	var state: int = TestDungeonFactory.rng.state
	assert(renderer.render_dungeon(data) and signature(stones_of(renderer)) == first)
	# Settings: density scales the count, zero density places none, disabled removes the node.
	renderer.out_of_bounds_stone_density = 2.0
	assert(renderer.render_dungeon(data) and stones_of(renderer).counts.boulders > boulders)
	renderer.out_of_bounds_stone_density = 0.0
	assert(renderer.render_dungeon(data) and stones_of(renderer).counts.boulders == 0)
	renderer.out_of_bounds_stone_density = 1.0
	renderer.out_of_bounds_stones_enabled = false
	assert(renderer.render_dungeon(data) and stones_of(renderer) == null)
	assert(data.tiles == tiles and TestDungeonFactory.rng.state == state)
	print("PASS: out-of-bounds stones stay in the visible band and below map level near the rim, share the terrain material with per-stone tints, are deterministic, follow density/enable settings and leave gameplay data untouched")
	quit()
