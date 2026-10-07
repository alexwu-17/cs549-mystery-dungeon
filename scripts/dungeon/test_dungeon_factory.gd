class_name TestDungeonFactory
extends RefCounted

const TileType = preload("res://scripts/dungeon/dungeon_data.gd").TileType
const ROWS = 22
const COLS = 30

static func create_2D_array(rows: int, cols: int, value) -> Array[Array]:
	var grid: Array[Array] = []
	grid.resize(rows)
	for i in rows:
		grid[i] = []
		grid[i].resize(cols)
		grid[i].fill(value)
	return grid

static func create_test_dungeon() -> DungeonData:
	# var rng = RandomNumberGenerator.new();
	
	#var grid = create_2D_array(ROWS, COLS, TileType.WALL);
	#var room_id_grid = create_2D_array(ROWS, COLS, -2);
	#var discovered = create_2D_array(ROWS, COLS, false);
	var rooms: Array[Rectangle] = [];
	
	var candidates: Array[Rectangle] = [
		Rectangle.new(1, 11, 7, 6),
		Rectangle.new(6, 8, 5, 6)
	];
	
	# var desired_rooms := rng.randi_range(5, 7);
	for candidate in candidates:
		if not rooms.any(func(r): Rectangle.overlaps(r, candidate, 1)):
			rooms.append(candidate);
			
	print(rooms)
	
	var dungeon := DungeonData.new()
	return dungeon

	# Temporary code for now...
	## Room 1
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
