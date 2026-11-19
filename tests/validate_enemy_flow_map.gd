extends SceneTree

const Flow = preload("res://scripts/enemies/enemy_flow_map.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var data := DungeonData.new()
	for y in range(3):
		for x in range(5):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)
	var goal := Vector2i(4, 1)
	var distances: Dictionary = Flow.build(data, goal)
	assert(distances[goal] == 0 and distances[Vector2i(0, 1)] == 4)
	var enemy := Skeleton.new()
	enemy.dungeon_data = data
	enemy.grid_position = Vector2i(0, 1)
	assert(enemy.flow_step_toward(goal, {}, distances) == Vector2i(1, 1))
	# Occupied shortest route must choose the shortest available detour.
	var occupied := {Vector2i(1, 1): true}
	assert(enemy.flow_step_toward(goal, occupied, distances) == Vector2i(0, 2))
	assert(enemy.flow_step_toward(goal, occupied, distances) == enemy.next_step_toward(goal, occupied))
	# A later blocker must keep the enemy on its detour on subsequent turns.
	enemy.grid_position = Vector2i(1, 0)
	occupied = {Vector2i(3, 0): true, Vector2i(2, 1): true}
	assert(enemy.flow_step_toward(goal, occupied, distances) == enemy.next_step_toward(goal, occupied))
	enemy.grid_position = Vector2i(0, 1)
	occupied = {Vector2i(1, 1): true}
	occupied[Vector2i(0, 0)] = true
	occupied[Vector2i(0, 2)] = true
	assert(enemy.flow_step_toward(goal, occupied, distances) == enemy.grid_position)
	# Disconnected tiles and the reverse direction across a standard ramp.
	data.set_tile(Vector2i(10, 10), DungeonData.TileType.FLOOR, 0)
	assert(not Flow.build(data, goal).has(Vector2i(10, 10)))
	var ramp := DungeonData.new()
	ramp.add_ramp(Vector2i.ZERO, Vector2i.RIGHT, 0)
	var ramp_distances: Dictionary = Flow.build(ramp, Vector2i(4, 0))
	assert(ramp_distances[Vector2i.ZERO] == 4)
	assert(not ramp.can_traverse(Vector2i(1, 0), Vector2i(1, 1)))
	# Rebuilding after a topology change must not retain old paths.
	data.set_tile(Vector2i(1, 1), DungeonData.TileType.VOID)
	assert(Flow.build(data, goal)[Vector2i(0, 1)] == 6)
	# Exercise route selection and tie-breaking across varied live occupancy.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8217
	var open := DungeonData.new()
	for y in range(8):
		for x in range(8): open.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)
	for trial in range(200):
		var target := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 7))
		enemy.grid_position = Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 7))
		enemy.dungeon_data = open
		var blockers := {}
		for unused in range(12):
			var tile := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 7))
			if tile != target and tile != enemy.grid_position: blockers[tile] = true
		var map: Dictionary = Flow.build(open, target)
		assert(enemy.flow_step_toward(target, blockers, map) == enemy.next_step_toward(target, blockers))
	enemy.free()
	print("PASS: shared flow distances, blocked detours, no path, ramps and topology changes")
	quit()
