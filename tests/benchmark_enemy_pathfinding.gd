extends SceneTree

const Flow = preload("res://scripts/enemies/enemy_flow_map.gd")
const GOAL := Vector2i(22, 8)
const ROUNDS := 12
const REPEATS := 12
const COUNTS := [3, 4, 5, 10, 15]

func _initialize() -> void:
	call_deferred("benchmark")

func make_map(kind: String) -> DungeonData:
	var data := DungeonData.new()
	for y in range(17):
		for x in range(24):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)
	if kind != "open":
		for x in [7, 15]:
			for y in range(17):
				var gap := y == 8 or (kind == "two_passages" and y == 3)
				if not gap: data.set_tile(Vector2i(x, y), DungeonData.TileType.VOID)
	return data

func snapshots(data: DungeonData, count: int) -> Array:
	var positions: Array[Vector2i] = []
	var occupied := {}
	for i in range(count):
		var tile := Vector2i(1 + i % 3, 4 + i / 3)
		positions.append(tile)
		occupied[tile] = i
	var actor := Skeleton.new()
	actor.dungeon_data = data
	var frames := []
	for round_index in range(ROUNDS):
		var actions := []
		for offset in range(count):
			var i := (round_index + offset) % count
			var pos := positions[i]
			if data.can_traverse(pos, GOAL): continue
			actor.grid_position = pos
			var step := actor.next_step_toward(GOAL, occupied)
			actions.append({"position": pos, "occupied": occupied.duplicate(), "expected": step})
			if step != pos and step != GOAL and not occupied.has(step):
				occupied.erase(pos)
				occupied[step] = i
				positions[i] = step
		frames.append(actions)
	actor.free()
	return frames

func measure(data: DungeonData, frames: Array, use_flow: bool) -> Array[float]:
	var actor := Skeleton.new()
	actor.dungeon_data = data
	var samples: Array[float] = []
	for actions in frames:
		var start := Time.get_ticks_usec()
		var distances: Dictionary = Flow.build(data, GOAL) if use_flow else {}
		for action in actions:
			actor.grid_position = action.position
			var step: Vector2i = actor.flow_step_toward(GOAL, action.occupied, distances) if use_flow else actor.next_step_toward(GOAL, action.occupied)
			assert(step == action.expected, "Path mismatch during paired benchmark")
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
	actor.free()
	return samples

func summary(samples: Array[float]) -> Dictionary:
	samples.sort()
	var sum := 0.0
	for value in samples: sum += value
	return {"mean_ms": sum / samples.size(), "median_ms": samples[samples.size() / 2], "p95_ms": samples[ceili(samples.size() * 0.95) - 1]}

func benchmark() -> void:
	for kind in ["open", "two_passages", "chokepoints"]:
		var data := make_map(kind)
		for count in COUNTS:
			var frames := snapshots(data, count)
			measure(data, frames, false)
			measure(data, frames, true)
			var bfs: Array[float] = []
			var flow: Array[float] = []
			for repetition in range(REPEATS):
				# Alternate execution order to reduce systematic ordering bias.
				if repetition % 2 == 0:
					bfs.append_array(measure(data, frames, false))
					flow.append_array(measure(data, frames, true))
				else:
					flow.append_array(measure(data, frames, true))
					bfs.append_array(measure(data, frames, false))
			print("BENCHMARK ", JSON.stringify({"map": kind, "enemies": count, "samples": bfs.size(), "bfs": summary(bfs), "flow": summary(flow)}))
	print("PASS: paired BFS and flow-map benchmark; all steps match")
	quit()
