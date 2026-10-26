extends RefCounted

# All candidate work is local. Only commit() mutates the accepted floor.
const DIRECTIONS = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const MAX_FOOTPRINT_ATTEMPTS = 160


static func inside(tile: Vector2i, size: Vector2i) -> bool:
	return tile.x > 0 and tile.y > 0 and tile.x < size.x - 1 and tile.y < size.y - 1


static func compatible(tile: Vector2i, height: int, data: DungeonData, proposed: Dictionary, size: Vector2i) -> bool:
	if not inside(tile, size):
		return false
	if proposed.has(tile) and proposed[tile] != height:
		return false
	if data.is_walkable(tile) and (data.get_elevation(tile) != height or data.get_tile(tile) == DungeonData.TileType.RAMP):
		return false
	for neighbor: Vector2i in [tile, tile + Vector2i.RIGHT, tile + Vector2i.LEFT, tile + Vector2i.UP, tile + Vector2i.DOWN]:
		if proposed.has(neighbor) and proposed[neighbor] != height:
			return false
		if data.reserved_transitions.has(neighbor):
			var segment: Dictionary = data.ramp_segments[data.reserved_transitions[neighbor]]
			var lower: Vector2i = segment.lower_buffer
			var direction: Vector2i = segment.direction
			# Only the straight approach cells may touch a reserved footprint.
			if not ((tile == lower - direction and height == segment.lower) or (tile == lower + direction * 5 and height == segment.lower + 1)):
				return false
		elif data.is_walkable(neighbor) and data.get_elevation(neighbor) != height:
			return false
	return true


static func l_path(start: Vector2i, goal: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = [start]
	var current := start
	var bend := Vector2i(goal.x, start.y) if horizontal_first else Vector2i(start.x, goal.y)
	for endpoint: Vector2i in [bend, goal]:
		while current != endpoint:
			var delta := endpoint - current
			current += Vector2i(signi(delta.x), signi(delta.y))
			result.append(current)
	return result


static func flat_connection(start: Vector2i, goal: Vector2i, height: int, data: DungeonData, size: Vector2i, horizontal_first: bool) -> bool:
	# Retain the existing two L-shaped choices; no ramp constraints on flat paths.
	for order: bool in [horizontal_first, not horizontal_first]:
		var path := l_path(start, goal, order)
		var valid := true
		for tile in path:
			if not compatible(tile, height, data, {}, size):
				valid = false
				break
		if valid:
			var proposed: Dictionary = {}
			for tile in path:
				proposed[tile] = height
			commit(data, proposed)
			return true
	return false


static func find_path(start: Vector2i, goal: Vector2i, height: int, data: DungeonData, proposed: Dictionary, forbidden: Dictionary, size: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		if current == goal:
			var path: Array[Vector2i] = [goal]
			while path[-1] != start:
				path.append(previous[path[-1]])
			path.reverse()
			return path
		for direction: Vector2i in DIRECTIONS:
			var next := current + direction
			if previous.has(next) or forbidden.has(next) or not compatible(next, height, data, proposed, size):
				continue
			previous[next] = current
			queue.append(next)
	return []


static func elevated_connection(low_center: Vector2i, high_center: Vector2i, lower_height: int, data: DungeonData, size: Vector2i, rng: RandomNumberGenerator, forbidden_uphill: Vector2i = Vector2i.ZERO) -> int:
	var candidates: Array[Dictionary] = []
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			for direction: Vector2i in DIRECTIONS:
				if direction == forbidden_uphill:
					continue
				var lower := Vector2i(x, y)
				var blocked: Dictionary = {}
				var valid := true
				for index in range(5):
					var tile := lower + direction * index
					if not inside(tile, size) or data.is_walkable(tile):
						valid = false
						break
					blocked[tile] = true
					for side: Vector2i in [Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)]:
						blocked[tile + side] = true
						if data.is_walkable(tile + side):
							valid = false
							break
				if not valid:
					continue
				var before := lower - direction
				var after := lower + direction * 5
				if not compatible(before, lower_height, data, {}, size) or not compatible(after, lower_height + 1, data, {}, size):
					continue
				var distance := absi(before.x - low_center.x) + absi(before.y - low_center.y) + absi(after.x - high_center.x) + absi(after.y - high_center.y)
				candidates.append({"lower": lower, "direction": direction, "blocked": blocked, "score": distance + rng.randf() * 3.0})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score < b.score)
	var attempts := 0
	for candidate in candidates:
		attempts += 1
		if attempts > MAX_FOOTPRINT_ATTEMPTS:
			break
		var lower: Vector2i = candidate.lower
		var direction: Vector2i = candidate.direction
		var proposed: Dictionary = {}
		var low_path := find_path(low_center, lower - direction, lower_height, data, proposed, candidate.blocked, size)
		if low_path.is_empty():
			continue
		for tile in low_path:
			proposed[tile] = lower_height
		var high_path := find_path(high_center, lower + direction * 5, lower_height + 1, data, proposed, candidate.blocked, size)
		if high_path.is_empty():
			continue
		for tile in high_path:
			proposed[tile] = lower_height + 1
		# Check approaches have not bent into the footprint or its side halo.
		var valid := true
		for index in range(5):
			var tile := lower + direction * index
			for side: Vector2i in [Vector2i(-direction.y, direction.x), Vector2i(direction.y, -direction.x)]:
				if proposed.has(tile + side):
					valid = false
		if not valid:
			continue
		commit(data, proposed)
		data.add_ramp(lower, direction, lower_height)
		data.routing_attempts += attempts
		return attempts
	data.routing_attempts += mini(attempts, MAX_FOOTPRINT_ATTEMPTS)
	return -1


static func commit(data: DungeonData, proposed: Dictionary) -> void:
	for tile: Vector2i in proposed:
		if not data.is_walkable(tile):
			data.set_tile(tile, DungeonData.TileType.CORRIDOR, proposed[tile])
