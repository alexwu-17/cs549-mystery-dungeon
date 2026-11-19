extends SceneTree

const Flow = preload("res://scripts/enemies/enemy_flow_map.gd")
const MAX_ROUNDS := 30
const STARTS: Array[Vector2i] = [Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 4), Vector2i(0, 2), Vector2i(0, 4)]
const GOAL := Vector2i(9, 3)

func _initialize() -> void:
	call_deferred("compare")

func make_map(kind: String) -> DungeonData:
	var data := DungeonData.new()
	for y in range(7):
		for x in range(11):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)
	if kind == "obstacles":
		for y in [1, 2, 3, 4, 5]:
			if y != 1 and y != 5:
				data.set_tile(Vector2i(5, y), DungeonData.TileType.VOID)
	elif kind == "chokepoint":
		for y in range(7):
			if y != 3:
				data.set_tile(Vector2i(5, y), DungeonData.TileType.VOID)
	return data

func simulate(data: DungeonData, count: int, use_flow: bool) -> Dictionary:
	var positions: Array[Vector2i] = []
	var paths: Array = []
	var moves: Array[int] = []
	var arrival: Array[int] = []
	var actors: Array[Skeleton] = []
	var occupied := {}
	for i in range(count):
		positions.append(STARTS[i])
		paths.append([STARTS[i]])
		moves.append(0)
		arrival.append(-1)
		occupied[STARTS[i]] = i
		var actor := Skeleton.new()
		actor.dungeon_data = data
		actors.append(actor)
	var elapsed_usec := 0
	var rounds := 0
	for round_index in range(MAX_ROUNDS):
		rounds += 1
		var started := Time.get_ticks_usec()
		var distances: Dictionary = Flow.build(data, GOAL) if use_flow else {}
		elapsed_usec += Time.get_ticks_usec() - started
		var moved := false
		for offset in range(count):
			# Same deterministic, rotating sequential order for both methods.
			var i := (round_index + offset) % count
			var current := positions[i]
			if data.can_traverse(current, GOAL):
				if arrival[i] < 0: arrival[i] = round_index
				continue
			actors[i].grid_position = current
			started = Time.get_ticks_usec()
			var next: Vector2i = actors[i].flow_step_toward(GOAL, occupied, distances) if use_flow else actors[i].next_step_toward(GOAL, occupied)
			elapsed_usec += Time.get_ticks_usec() - started
			assert(next == current or (data.can_traverse(current, next) and next != GOAL and not occupied.has(next)))
			if next != current:
				occupied.erase(current)
				occupied[next] = i
				positions[i] = next
				paths[i].append(next)
				moves[i] += 1
				moved = true
				if data.can_traverse(next, GOAL) and arrival[i] < 0: arrival[i] = round_index + 1
		if not moved: break
	for actor in actors: actor.free()
	var reached := 0
	var first := -1
	var total_moves := 0
	for i in range(count):
		total_moves += moves[i]
		if arrival[i] >= 0:
			reached += 1
			if first < 0 or arrival[i] < first: first = arrival[i]
	return {"moves": total_moves, "moves_by_enemy": moves, "reached": reached, "first_round": first, "arrival_rounds": arrival, "rounds": rounds, "paths": paths, "search_us": elapsed_usec}

func compare() -> void:
	for kind in ["open", "obstacles", "chokepoint"]:
		var data := make_map(kind)
		for count in range(1, 6):
			var bfs := simulate(data, count, false)
			var flow := simulate(data, count, true)
			var differences: Array = []
			for i in range(count):
				if bfs.paths[i] != flow.paths[i]:
					differences.append({"enemy": i + 1, "bfs": bfs.paths[i], "flow": flow.paths[i]})
			print("COMPARISON ", JSON.stringify({"scenario": kind, "count": count, "bfs": bfs, "flow": flow, "differences": differences}))
			assert(differences.is_empty(), "Flow pursuit diverged from BFS in %s with %d enemies" % [kind, count])
			assert(bfs.arrival_rounds == flow.arrival_rounds and bfs.moves == flow.moves)
	print("PASS: deterministic BFS versus shared flow map, one through five enemies")
	quit()
