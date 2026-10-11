class_name TestDungeonFactory
extends RefCounted

const DUNGEON_DATA_RESOURCE = preload("res://scripts/dungeon/dungeon_data.gd");
const TileType = DUNGEON_DATA_RESOURCE.TileType;
const CORRIDOR_VAL = DUNGEON_DATA_RESOURCE.CORRIDOR_VAL;
const ROWS = 22;
const COLS = 30;

static var grid: Array[Array] = [];
static var room_id_grid: Array[Array] = [];
static var discovered: Array[Array] = [];
static var rng = RandomNumberGenerator.new();

static func create_2D_array(rows: int, cols: int, value) -> Array[Array]:
	var arr_2D: Array[Array] = []
	arr_2D.resize(rows);
	for i in rows:
		arr_2D[i] = [];
		arr_2D[i].resize(cols);
		arr_2D[i].fill(value);
	return arr_2D


static func carve_room(room: Rectangle, id: int) -> void:
	for y in range(room.y, room.y + room.h):
		for x in range(room.x, room.x + room.w):
			TestDungeonFactory.grid[y][x] = TileType.FLOOR;
			TestDungeonFactory.room_id_grid[y][x] = id;


static func center(room: Rectangle) -> Point:
	# Yes, integer division is intentional here...
	@warning_ignore("integer_division")
	return Point.new(room.x + room.w / 2, room.y + room.h / 2);


static func carve(cx: int, cy: int) -> void:
	TestDungeonFactory.grid[cy][cx] = TileType.FLOOR;
	# Preserve RoomID if corridor passes through
	if TestDungeonFactory.room_id_grid[cy][cx] < 0:
		room_id_grid[cy][cx] = CORRIDOR_VAL;


static func carve_corridor(x1: int, y1: int, x2: int, y2: int) -> void:
	var carve_func := func(cx: int, cy: int) -> void:
		TestDungeonFactory.grid[cy][cx] = TileType.FLOOR;
		# Preserve RoomID if corridor passes through
		if TestDungeonFactory.room_id_grid[cy][cx] < 0:
			room_id_grid[cy][cx] = CORRIDOR_VAL;
	
	var x = x1;
	var y = y1;
	while x != x2:
		carve_func.call(x, y);
		x += signi(x2 - x);
	while y != y2:
		carve_func.call(x, y);
		y += signi(y2 - y);
	carve_func.call(x, y);


static func create_test_dungeon(placement_attempts: int = 250) -> DungeonData:
	TestDungeonFactory.grid = create_2D_array(ROWS, COLS, TileType.VOID);
	TestDungeonFactory.room_id_grid = create_2D_array(ROWS, COLS, -2);
	TestDungeonFactory.discovered = create_2D_array(ROWS, COLS, false);
	
	var rooms: Array[Rectangle] = [];
	
	var desired_rooms := rng.randi_range(5, 7);
	for attempts in range(placement_attempts):
		var w := rng.randi_range(4, 7);
		var h := rng.randi_range(4, 6);
		var x := rng.randi_range(1, COLS - w - 2);
		var y := rng.randi_range(1, ROWS - h - 2);
		var candidate := Rectangle.new(x, y, w, h);
		
		if not rooms.any(func(r): return Rectangle.overlaps(r, candidate, 1)):
			rooms.append(candidate);
			carve_room(candidate, len(rooms) - 1);
		
		if len(rooms) >= desired_rooms:
			break;
	# Fewer than the requested rooms is usable, but always provide two rooms.
	if rooms.size() < 2:
		grid = create_2D_array(ROWS, COLS, TileType.VOID)
		room_id_grid = create_2D_array(ROWS, COLS, -2)
		rooms = [Rectangle.new(2, 2, 5, 5), Rectangle.new(20, 13, 5, 5)]
		for i in range(rooms.size()):
			carve_room(rooms[i], i)
	
	for i in range(1, len(rooms)):
		var a := center(rooms[i - 1]);
		var b := center(rooms[i]);
		if (rng.randi() % 2 == 0):
			carve_corridor(a.x, a.y, b.x, a.y);
			carve_corridor(b.x, a.y, b.x, b.y);
		else:
			carve_corridor(a.x, a.y, a.x, b.y);
			carve_corridor(a.x, b.y, b.x, b.y);
	
	# Convert to dictionary representation
	var dungeon := DungeonData.new();
	for row in range(ROWS):
		for col in range(COLS):
			dungeon.set_tile(Vector2i(col, row), grid[row][col], 0);
	
	var spawn_point = center(rooms[0]);
	dungeon.player_spawn = Vector2i(spawn_point.x, spawn_point.y);
	var reachable := reachable_tiles(dungeon)
	for position: Vector2i in dungeon.tiles:
		if dungeon.is_walkable(position) and not reachable.has(position):
			push_error("Procedural dungeon has an unreachable tile: %s" % position)
			return create_fallback_dungeon()
	place_spawns(dungeon, reachable)
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
			if dungeon.is_walkable(neighbor) and not visited.has(neighbor):
				visited[neighbor] = visited[position] + 1
				queue.append(neighbor)
	return visited


static func place_spawns(dungeon: DungeonData, reachable: Dictionary) -> void:
	# Prefer a distant tile in a different room; BFS values are path distances.
	var stairs := dungeon.player_spawn
	var best_distance := -1
	for position: Vector2i in reachable:
		if room_id_grid[position.y][position.x] <= 0:
			continue
		var distance: int = reachable[position]
		if distance > best_distance:
			stairs = position
			best_distance = distance
	if best_distance < 0:
		for position: Vector2i in reachable:
			var distance: int = reachable[position]
			if distance > best_distance:
				stairs = position
				best_distance = distance
	dungeon.stairs_position = stairs
	dungeon.set_tile(stairs, TileType.STAIRS, 0)
	var candidates: Array[Vector2i] = []
	for position: Vector2i in reachable:
		if position != dungeon.player_spawn and position != stairs and room_id_grid[position.y][position.x] >= 0:
			candidates.append(position)
	for i in range(mini(3, candidates.size())):
		var choice := rng.randi_range(0, candidates.size() - 1)
		dungeon.enemy_spawns.append(candidates[choice])
		candidates.remove_at(choice)


static func create_fallback_dungeon() -> DungeonData:
	# Emergency flat floor; do not introduce elevation into procedural mode.
	var dungeon := DungeonData.new()
	for y in range(2, 7):
		for x in range(2, 7):
			dungeon.set_tile(Vector2i(x, y), TileType.FLOOR, 0)
	dungeon.player_spawn = Vector2i(3, 3)
	dungeon.enemy_spawns = [Vector2i(4, 4)]
	dungeon.stairs_position = Vector2i(6, 6)
	dungeon.set_tile(dungeon.stairs_position, TileType.STAIRS, 0)
	return dungeon


static func create_elevation_test_dungeon() -> DungeonData:
	var dungeon := DungeonData.new()
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
