extends SceneTree

const Flow = preload("res://scripts/enemies/enemy_flow_map.gd")
const SEED := 5492026
const ORDER_SEED := 82731
const ROUNDS := 16
const REPEATS := 12

func _initialize() -> void:
	call_deferred("benchmark")

func capture_states(data: DungeonData, count: int) -> Array:
	var positions: Array[Vector2i] = []
	positions.assign(data.enemy_spawns.slice(0, count))
	var occupied := {}
	for i in range(count): occupied[positions[i]] = i
	var player := data.player_spawn
	var rng := RandomNumberGenerator.new()
	rng.seed = ORDER_SEED
	var actor := Skeleton.new()
	actor.dungeon_data = data
	var frames := []
	for round_index in range(ROUNDS):
		# Advance the player periodically; other phases represent attacks/waits.
		if round_index > 0 and round_index % 4 == 0:
			var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
			var shift := rng.randi_range(0, 3)
			for i in range(4):
				var next := player + directions[(shift + i) % 4]
				if data.can_traverse(player, next) and not occupied.has(next) and next != data.stairs_position:
					player = next
					break
		var order := range(count)
		for i in range(count - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var temp = order[i]
			order[i] = order[j]
			order[j] = temp
		var actions := []
		for i in order:
			var pos := positions[i]
			if data.can_traverse(pos, player): continue
			actor.grid_position = pos
			var step := actor.next_step_toward(player, occupied)
			actions.append({"position": pos, "occupied": occupied.duplicate(), "expected": step})
			if step != pos and step != player and not occupied.has(step):
				occupied.erase(pos)
				occupied[step] = i
				positions[i] = step
		frames.append({"goal": player, "actions": actions})
	actor.free()
	return frames

func measure(data: DungeonData, frames: Array, use_flow: bool) -> Array[float]:
	var actor := Skeleton.new()
	actor.dungeon_data = data
	var samples: Array[float] = []
	for frame in frames:
		var started := Time.get_ticks_usec()
		var distances: Dictionary = Flow.build(data, frame.goal) if use_flow else {}
		for action in frame.actions:
			actor.grid_position = action.position
			var step: Vector2i = actor.flow_step_toward(frame.goal, action.occupied, distances) if use_flow else actor.next_step_toward(frame.goal, action.occupied)
			assert(step == action.expected, "Path mismatch in generated dungeon")
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	actor.free()
	return samples

func summary(samples: Array[float]) -> Dictionary:
	samples.sort()
	var sum := 0.0
	for value in samples: sum += value
	return {"mean_ms": sum / samples.size(), "median_ms": samples[samples.size() / 2], "p95_ms": samples[ceili(samples.size() * 0.95) - 1]}

func benchmark() -> void:
	TestDungeonFactory.rng.seed = SEED
	var data := TestDungeonFactory.create_test_dungeon()
	assert(data != null and not data.used_fallback and data.enemy_spawns.size() >= 5)
	var tiles: Array[String] = []
	for tile: Vector2i in data.tiles:
		tiles.append("%d,%d:%d:%d" % [tile.x, tile.y, data.get_tile(tile), data.get_elevation(tile)])
	tiles.sort()
	print("DUNGEON ", JSON.stringify({"seed": SEED, "order_seed": ORDER_SEED, "map_bounds": str(data.map_bounds), "tiles": data.tiles.size(), "rooms": data.rooms.size(), "ramps": data.ramp_segments.size(), "fallback": data.used_fallback, "player": str(data.player_spawn), "enemies": data.enemy_spawns.map(func(tile): return str(tile)), "topology_sha256": "|".join(tiles).sha256_text()}))
	for count in [3, 4, 5]:
		var frames := capture_states(data, count)
		measure(data, frames, false)
		measure(data, frames, true)
		var bfs: Array[float] = []
		var flow: Array[float] = []
		for repetition in range(REPEATS):
			if repetition % 2 == 0:
				bfs.append_array(measure(data, frames, false))
				flow.append_array(measure(data, frames, true))
			else:
				flow.append_array(measure(data, frames, true))
				bfs.append_array(measure(data, frames, false))
		print("GENERATED_BENCHMARK ", JSON.stringify({"seed": SEED, "enemies": count, "samples": bfs.size(), "bfs": summary(bfs), "flow": summary(flow)}))
	print("PASS: seeded generated dungeon paired benchmark; all steps match")
	quit()
