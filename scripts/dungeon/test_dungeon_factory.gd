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
	# Yes, integer division is intentional here, not sure why it triggers a warning!
	#warning-ignore:integer_division
	return Point.new(room.x + room.w / 2, room.y + room.h / 2);
	
static func carve(cx: int, cy: int) -> void:
	TestDungeonFactory.grid[cy][cx] = TileType.FLOOR;
	# Preserve RoomID if corridor passes through
	if TestDungeonFactory.room_id_grid[cy][cx] < 0:
		room_id_grid[cy][cx] = CORRIDOR_VAL;


static func carve_corridor(x1: int, y1: int, x2: int, y2: int) -> void:
	var x = x1;
	var y = y1;
	while x != x2:
		TestDungeonFactory.carve(x, y);
		x += signi(x2 - x);
	while y != y2:
		carve(x, y);
		y += signi(y2 - y);
	carve(x, y);

static func create_test_dungeon() -> DungeonData:
	var rng = RandomNumberGenerator.new();
	
	TestDungeonFactory.grid = create_2D_array(ROWS, COLS, TileType.VOID);
	TestDungeonFactory.room_id_grid = create_2D_array(ROWS, COLS, -2);
	TestDungeonFactory.discovered = create_2D_array(ROWS, COLS, false);
	
	var rooms: Array[Rectangle] = [];
	
	var desired_rooms := rng.randi_range(5, 7);
	for attempts in range(250):
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
	# Make sure to add the guard class for len(rooms) < 4
	
	for i in range(1, len(rooms)):
		var a := center(rooms[i - 1]);
		var b := center(rooms[1]);
		carve_corridor(a.x, a.y, b.x, a.y);
		carve_corridor(b.x, a.y, b.x, b.y);
	
	# Convert to dictionary representation
	var dungeon := DungeonData.new();
	for row in range(ROWS):
		for col in range(COLS):
			dungeon.set_tile(Vector2i(col, row), grid[row][col], 0);
	
	dungeon.player_spawn = Vector2i(2, 2);
	dungeon.set_tile(Vector2i(2, 2), TileType.FLOOR, 0);
	return dungeon


	## Temporary code for now...
	## Room 1
	#var dungeon := DungeonData.new();
	#for x in range(0, 5):
		#for y in range(0, 5):
			#dungeon.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)
#
	## Corridor (unused currently as it was for same level corridor)
	##for x in range(5, 8):
		##dungeon.set_tile(Vector2i(x, 2), DungeonData.TileType.CORRIDOR, 0)
	#
	## Corridor from Room 1 toward Room 2
	#for x in range(5, 7):
		#dungeon.set_tile(Vector2i(x, 2), DungeonData.TileType.CORRIDOR, 0)
#
	## Ramp connects elevation 0 to elevation +1.
	#dungeon.set_tile(
		#Vector2i(7, 2),
		#DungeonData.TileType.RAMP,
		#0
	#)
#
	## Room 2
	#for x in range(8, 13):
		#for y in range(0, 5):
			#dungeon.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 1)
#
	#dungeon.player_spawn = Vector2i(2, 2)
	#dungeon.enemy_spawns = [Vector2i(10, 2)]
	#dungeon.stairs_position = Vector2i(11, 3)
#
	#var stairs_elevation := dungeon.get_elevation(dungeon.stairs_position)
#
	#dungeon.set_tile(
		#dungeon.stairs_position,
		#DungeonData.TileType.STAIRS,
		#stairs_elevation
	#)
#
	#return dungeon
