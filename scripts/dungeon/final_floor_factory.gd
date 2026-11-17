class_name FinalFloorFactory
extends RefCounted

# Fifteen corridor rows, followed by the diamond's southern tip at (13, 15).
const CORRIDOR_LENGTH: int = 15
const PLAYER_SPAWN := Vector2i(13, 30)
const MUSIC_TILE := Vector2i(13, 29) # Row2, counting spawn as row1.

static func corridor_tile(number: int) -> Vector2i:
	return PLAYER_SPAWN + Vector2i.UP * (number - 1)

static func corridor_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for number in range(1, CORRIDOR_LENGTH + 1):
		var half_width := 1 if number < CORRIDOR_LENGTH else 0
		for offset in range(-half_width, half_width + 1):
			result.append(corridor_tile(number) + Vector2i(offset, 0))
	return result

static func is_music_row(tile: Vector2i) -> bool:
	return tile.y == MUSIC_TILE.y and absi(tile.x - MUSIC_TILE.x) <= 1

static func create_floor() -> DungeonData:
	var data := DemoArenaFactory.create_arena()
	for tile in corridor_tiles():
		data.set_tile(tile, DungeonData.TileType.CORRIDOR, 0)
	data.map_bounds = Rect2i(2, -1, 23, 38)
	data.player_spawn = PLAYER_SPAWN
	return data

const SPIRITOMB_CENTER := Vector2i(13, 10)
const SPIRITOMB_BOUNDS := Rect2i(9, 6, 9, 9)
# One-based row3 from either extreme, centered horizontally.
const SPIRITOMB_PLAYER_SPAWN := Vector2i(13, 12)
const SPIRITOMB_SPAWN := Vector2i(13, 8)

static func create_spiritomb_arena() -> DungeonData:
	var data := DungeonData.new()
	data.rooms = [SPIRITOMB_BOUNDS]
	data.room_elevations = [0]
	data.map_bounds = Rect2i(2, -1, 23, 38)
	for y in range(SPIRITOMB_BOUNDS.position.y, SPIRITOMB_BOUNDS.end.y):
		for x in range(SPIRITOMB_BOUNDS.position.x, SPIRITOMB_BOUNDS.end.x):
			var tile := Vector2i(x, y)
			data.set_tile(tile, DungeonData.TileType.FLOOR, 0)
	data.player_spawn = SPIRITOMB_PLAYER_SPAWN
	return data
