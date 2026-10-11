class_name TestDungeonFactory
extends RefCounted

const Router = preload("res://scripts/dungeon/corridor_router.gd")
const TileType = DungeonData.TileType
const CORRIDOR_VAL = DungeonData.CORRIDOR_VAL
const ROWS = 22
const COLS = 30
const MAX_LAYOUT_ATTEMPTS = 32

static var grid: Array[Array] = []
static var room_id_grid: Array[Array] = []
static var discovered: Array[Array] = []
static var rng = RandomNumberGenerator.new()
static var last_statistics: Dictionary = {}


static func create_2D_array(rows: int, cols: int, value) -> Array[Array]:
	var result: Array[Array] = []
	for row in range(rows):
		var cells: Array = []
		cells.resize(cols)
		cells.fill(value)
		result.append(cells)
	return result


static func change_probability(same_connections: int) -> int:
	return mini(10 + 30 * same_connections, 100)


static func assign_heights(count: int) -> Array[int]:
	var result: Array[int] = [0]
	var same := 0
	for index in range(1, count):
		var height := result[-1]
		if rng.randi_range(0, 99) < change_probability(same):
			if height == 1:
				height = 0
			elif height == -1:
				height = 0
			else:
				height = -1 if rng.randi_range(0, 1) == 0 else 1
			same = 0
		else:
			same += 1
		result.append(height)
	return result


static func create_test_dungeon(placement_attempts: int = 250, map_size: Vector2i = Vector2i(COLS, ROWS)) -> DungeonData:
	var routing_attempts := 0
	for attempt in range(MAX_LAYOUT_ATTEMPTS):
		var dungeon := try_layout(placement_attempts, map_size)
		routing_attempts += dungeon.routing_attempts
		if not dungeon.connections.is_empty() and validate_floor(dungeon):
			dungeon.generation_attempts = attempt + 1
			dungeon.routing_attempts = routing_attempts
			finish_spawns(dungeon, map_size)
			last_statistics = {"layouts": attempt + 1, "routes": routing_attempts, "fallback": false, "size": map_size}
			return dungeon
	push_warning("Elevation generation exhausted %d layouts at %s; using known-valid elevated fallback." % [MAX_LAYOUT_ATTEMPTS, map_size])
	var fallback := create_fallback_dungeon()
	fallback.generation_attempts = MAX_LAYOUT_ATTEMPTS
	fallback.routing_attempts = routing_attempts
	finish_spawns(fallback, map_size)
	last_statistics = {"layouts": MAX_LAYOUT_ATTEMPTS, "routes": routing_attempts, "fallback": true, "size": map_size}
	return fallback


static func try_layout(placement_attempts: int, size: Vector2i) -> DungeonData:
	var dungeon := DungeonData.new()
	var desired_rooms := rng.randi_range(5, 7)
	for attempt in range(placement_attempts):
		var w := rng.randi_range(4, 7)
		var h := rng.randi_range(4, 6)
		var room := Rect2i(rng.randi_range(1, size.x - w - 2), rng.randi_range(1, size.y - h - 2), w, h)
		if not dungeon.rooms.any(func(other: Rect2i) -> bool: return other.grow(1).intersects(room)):
			dungeon.rooms.append(room)
		if dungeon.rooms.size() >= desired_rooms:
			break
	if dungeon.rooms.size() < 2:
		return dungeon
	dungeon.room_elevations = assign_heights(dungeon.rooms.size())
	for id in range(dungeon.rooms.size()):
		var room := dungeon.rooms[id]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				dungeon.set_tile(Vector2i(x, y), TileType.FLOOR, dungeon.room_elevations[id])
	dungeon.player_spawn = dungeon.rooms[0].get_center()
	for id in range(1, dungeon.rooms.size()):
		var a := dungeon.rooms[id - 1].get_center()
		var b := dungeon.rooms[id].get_center()
		var ha := dungeon.room_elevations[id - 1]
		var hb := dungeon.room_elevations[id]
		var success: bool
		if ha == hb:
			success = Router.flat_connection(a, b, ha, dungeon, size, rng.randi_range(0, 1) == 0)
		else:
			success = Router.elevated_connection(a if ha < hb else b, b if ha < hb else a, mini(ha, hb), dungeon, size, rng) >= 0
		if not success:
			dungeon.connections.clear()
			return dungeon
		dungeon.connections.append(Vector2i(id - 1, id))
	return dungeon


static func validate_floor(dungeon: DungeonData) -> bool:
	if dungeon.rooms.is_empty() or dungeon.room_elevations[0] != 0:
		return false
	for id in range(dungeon.rooms.size()):
		if dungeon.room_elevations[id] not in [-1, 0, 1]:
			return false
		var room := dungeon.rooms[id]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				if dungeon.get_elevation(Vector2i(x, y)) != dungeon.room_elevations[id]:
					return false
	var reachable := reachable_tiles(dungeon)
	for tile: Vector2i in dungeon.tiles:
		if dungeon.is_walkable(tile) and not reachable.has(tile):
			return false
		for direction: Vector2i in DungeonData.CARDINALS:
			if dungeon.is_walkable(tile + direction) and not dungeon.can_traverse(tile, tile + direction):
				return false
	for segment in dungeon.ramp_segments:
		for index in range(5):
			var tile: Vector2i = segment.lower_buffer + segment.direction * index
			for room in dungeon.rooms:
				if room.has_point(tile):
					return false
	return true


static func finish_spawns(dungeon: DungeonData, size: Vector2i) -> void:
	grid = create_2D_array(size.y, size.x, TileType.VOID)
	room_id_grid = create_2D_array(size.y, size.x, -2)
	discovered = create_2D_array(size.y, size.x, false)
	for tile: Vector2i in dungeon.tiles:
		grid[tile.y][tile.x] = dungeon.get_tile(tile)
		room_id_grid[tile.y][tile.x] = CORRIDOR_VAL
	for id in range(dungeon.rooms.size()):
		var room := dungeon.rooms[id]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				room_id_grid[y][x] = id
	place_spawns(dungeon, reachable_tiles(dungeon))
	grid[dungeon.stairs_position.y][dungeon.stairs_position.x] = TileType.STAIRS


static func create_fallback_dungeon() -> DungeonData:
	# Two flat rooms separated by exactly one reserved three-tile slope.
	var dungeon := DungeonData.new()
	dungeon.used_fallback = true
	dungeon.rooms = [Rect2i(2, 2, 4, 4), Rect2i(11, 2, 4, 4)]
	dungeon.room_elevations = [0, 1]
	dungeon.connections = [Vector2i(0, 1)]
	for id in range(2):
		var room := dungeon.rooms[id]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				dungeon.set_tile(Vector2i(x, y), TileType.FLOOR, id)
	dungeon.add_ramp(Vector2i(6, 3), Vector2i.RIGHT, 0)
	dungeon.player_spawn = Vector2i(3, 3)
	return dungeon


static func reachable_tiles(dungeon: DungeonData) -> Dictionary:
	var visited: Dictionary = {}
	if not dungeon.is_walkable(dungeon.player_spawn):
		return visited
	var queue: Array[Vector2i] = [dungeon.player_spawn]
	visited[dungeon.player_spawn] = 0
	var index := 0
	while index < queue.size():
		var position := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := position + direction
			if dungeon.can_traverse(position, neighbor) and not visited.has(neighbor):
				visited[neighbor] = visited[position] + 1
				queue.append(neighbor)
	return visited


static func place_spawns(dungeon: DungeonData, reachable: Dictionary) -> void:
	# Any reachable room tile is eligible, including the starting room.
	# Keep the standardized ramp and its buffers intact.
	var stair_candidates: Array[Vector2i] = []
	for position: Vector2i in reachable:
		if position != dungeon.player_spawn and room_id_grid[position.y][position.x] >= 0 and not dungeon.reserved_transitions.has(position) and dungeon.get_tile(position) != TileType.RAMP:
			stair_candidates.append(position)
	var stairs := stair_candidates[rng.randi_range(0, stair_candidates.size() - 1)]
	dungeon.stairs_position = stairs
	dungeon.set_tile(stairs, TileType.STAIRS, dungeon.get_elevation(stairs))
	var candidates: Array[Vector2i] = []
	for position: Vector2i in reachable:
		if position != dungeon.player_spawn and position != stairs and room_id_grid[position.y][position.x] >= 0:
			candidates.append(position)
	for i in range(mini(3, candidates.size())):
		var choice := rng.randi_range(0, candidates.size() - 1)
		dungeon.enemy_spawns.append(candidates[choice])
		candidates.remove_at(choice)


static func create_elevation_test_dungeon() -> DungeonData:
	var dungeon := DungeonData.new()
	dungeon.legacy_ramp = true
	dungeon.rooms = [Rect2i(0, 0, 5, 5), Rect2i(8, 0, 5, 5)]
	dungeon.room_elevations = [0, 1]
	for x in range(0, 5):
		for y in range(0, 5):
			dungeon.set_tile(Vector2i(x, y), TileType.FLOOR, 0)
	for x in range(5, 7):
		dungeon.set_tile(Vector2i(x, 2), TileType.CORRIDOR, 0)
	dungeon.set_tile(Vector2i(7, 2), TileType.RAMP, 0)
	for x in range(8, 13):
		for y in range(0, 5):
			dungeon.set_tile(Vector2i(x, y), TileType.FLOOR, 1)
	dungeon.player_spawn = Vector2i(2, 2)
	dungeon.enemy_spawns = [Vector2i(10, 2)]
	dungeon.stairs_position = Vector2i(11, 3)
	dungeon.set_tile(dungeon.stairs_position, TileType.STAIRS, 1)
	return dungeon
