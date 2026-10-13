class_name BenchmarkDungeonFactory
extends RefCounted

const SEED: int = 54903
const MAP_SIZE: Vector2i = Vector2i(30, 22)

static func create() -> DungeonData:
	var data := DungeonData.new()
	data.rooms = [Rect2i(1, 1, 12, 8), Rect2i(17, 1, 12, 8), Rect2i(1, 13, 12, 8), Rect2i(17, 13, 12, 8)]
	data.room_elevations = [0, 0, 0, 0]
	data.connections = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 3)]
	for room in data.rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	for y in [4, 16]:
		for x in range(13, 17): data.set_tile(Vector2i(x, y), DungeonData.TileType.CORRIDOR)
	for x in [6, 23]:
		for y in range(9, 13): data.set_tile(Vector2i(x, y), DungeonData.TileType.CORRIDOR)
	data.player_spawn = Vector2i(6, 4)
	data.stairs_position = Vector2i(23, 16)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS)
	for tile: Vector2i in data.tiles.keys():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := tile + Vector2i(dx, dy)
				if data.get_tile(neighbor) == DungeonData.TileType.VOID:
					data.set_tile(neighbor, DungeonData.TileType.WALL)
	return data

static func candidates(data: DungeonData) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in TestDungeonFactory.reachable_tiles(data):
		if tile != data.player_spawn and tile != data.stairs_position and data.get_room_id(tile) >= 0:
			result.append(tile)
	# A fixed ordering ensures increasing the count preserves earlier spawns.
	result.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for index in range(result.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary := result[index]
		result[index] = result[other]
		result[other] = temporary
	return result
