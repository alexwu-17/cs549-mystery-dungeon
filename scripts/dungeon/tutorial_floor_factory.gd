class_name TutorialFloorFactory
extends RefCounted

static func create_floor() -> DungeonData:
	var data := DungeonData.new()
	data.rooms = [Rect2i(2, 14, 7, 7), Rect2i(13, 14, 7, 7), Rect2i(13, 3, 7, 7)]
	data.room_elevations = [0, 0, 0]
	data.connections = [Vector2i(0, 1), Vector2i(1, 2)]
	data.map_bounds = Rect2i(0, 0, 22, 23)
	for room in data.rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)
	for x in range(9, 13):
		data.set_tile(Vector2i(x, 17), DungeonData.TileType.CORRIDOR, 0)
	for y in range(10, 14):
		data.set_tile(Vector2i(16, y), DungeonData.TileType.CORRIDOR, 0)
	data.player_spawn = Vector2i(5, 17)
	data.enemy_spawns = [Vector2i(16, 17)]
	data.stairs_position = Vector2i(16, 6)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS, 0)
	return data
