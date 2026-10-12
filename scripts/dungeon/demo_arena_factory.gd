class_name DemoArenaFactory
extends RefCounted

const ARENA_BOUNDS := Rect2i(8, 5, 11, 11)
const ARENA_CENTER := Vector2i(13, 10)
# Rows count from 1 at the bottom (largest grid Y).
const PLAYER_SPAWN := Vector2i(13, 13)
const BOSS_CENTER := Vector2i(13, 9)

static func create_arena() -> DungeonData:
	var data := DungeonData.new()
	var room := ARENA_BOUNDS
	data.rooms = [room]
	data.room_elevations = [0]
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var tile := Vector2i(x, y)
			if absi(tile.x - ARENA_CENTER.x) + absi(tile.y - ARENA_CENTER.y) <= 5:
				data.set_tile(tile, DungeonData.TileType.FLOOR, 0)
	data.player_spawn = PLAYER_SPAWN
	return data
