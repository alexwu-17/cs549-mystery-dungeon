class_name DungeonData
extends RefCounted


enum TileType {
	VOID,
	FLOOR,
	WALL,
	CORRIDOR,
	RAMP,
	STAIRS
}

const CORRIDOR_VAL = -1;
const TILE_SIZE: float = 1.0
const ELEVATION_HEIGHT: float = 3.0
const CARDINALS = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


var tiles: Dictionary = {}
# Explicit configured extent; rendering must not infer the map from carved rooms.
var map_bounds: Rect2i = Rect2i()
var elevations: Dictionary = {}
var rooms: Array[Rect2i] = []
var room_elevations: Array[int] = []
var connections: Array[Vector2i] = []
var ramp_segments: Array[Dictionary] = []
var ramp_tiles: Dictionary = {}
var reserved_transitions: Dictionary = {}
var legacy_ramp: bool = false
var generation_attempts: int = 0
var routing_attempts: int = 0
var used_fallback: bool = false
var discovered_tiles: Dictionary = {}
var bright_tiles: Dictionary = {}

var player_spawn: Vector2i = Vector2i.ZERO
var enemy_spawns: Array[Vector2i] = []
var stairs_position: Vector2i = Vector2i.ZERO


func set_tile(position: Vector2i, tile_type: TileType, elevation: int = 0) -> void:
	tiles[position] = tile_type
	elevations[position] = elevation


func get_tile(position: Vector2i) -> TileType:
	return tiles.get(position, TileType.VOID)


func get_elevation(position: Vector2i) -> int:
	return elevations.get(position, 0)


func is_walkable(position: Vector2i) -> bool:
	var tile: TileType = get_tile(position)

	return (
		tile == TileType.FLOOR
		or tile == TileType.CORRIDOR
		or tile == TileType.RAMP
		or tile == TileType.STAIRS
	)


func add_ramp(lower_buffer: Vector2i, uphill: Vector2i, lower: int) -> void:
	var segment := {"lower_buffer": lower_buffer, "direction": uphill, "lower": lower}
	var id := ramp_segments.size()
	ramp_segments.append(segment)
	for index in range(5):
		var tile := lower_buffer + uphill * index
		reserved_transitions[tile] = id
		if index == 0 or index == 4:
			set_tile(tile, TileType.CORRIDOR, lower + (1 if index == 4 else 0))
		else:
			set_tile(tile, TileType.RAMP, lower)
			ramp_tiles[tile] = {"segment": id, "index": index - 1}


func can_traverse(from: Vector2i, to: Vector2i) -> bool:
	var delta := to - from
	if absi(delta.x) + absi(delta.y) != 1 or not is_walkable(from) or not is_walkable(to):
		return false
	for tile: Vector2i in [from, to]:
		if reserved_transitions.has(tile):
			var axis: Vector2i = ramp_segments[reserved_transitions[tile]].direction
			if delta != axis and delta != -axis:
				return false
	for tile: Vector2i in [from, to]:
		if ramp_tiles.has(tile):
			var segment: Dictionary = ramp_segments[ramp_tiles[tile].segment]
			var other := to if tile == from else from
			var direction: Vector2i = segment.direction
			var offset := other - Vector2i(segment.lower_buffer)
			var along := offset.x * direction.x + offset.y * direction.y
			if offset != direction * along or along < 0 or along > 4:
				return false
			if reserved_transitions.get(other, -1) != ramp_tiles[tile].segment:
				return false
			if along == 0 or along == 4:
				return get_elevation(other) == int(segment.lower) + (1 if along == 4 else 0) and get_tile(other) != TileType.RAMP
			if not ramp_tiles.has(other) or ramp_tiles[other].index != along - 1:
				return false
			return true
		if get_tile(tile) == TileType.RAMP:
			# The original one-tile debug ramp is explicitly restricted to +X.
			if not legacy_ramp:
				return false
			var other := to if tile == from else from
			return (other == tile - Vector2i.RIGHT and get_elevation(other) == get_elevation(tile)) or (other == tile + Vector2i.RIGHT and get_elevation(other) == get_elevation(tile) + 1)
	return get_elevation(from) == get_elevation(to)


func surface_elevation(tile: Vector2i) -> float:
	if ramp_tiles.has(tile):
		return get_elevation(tile) + (float(ramp_tiles[tile].index) + 0.5) / 3.0
	if legacy_ramp and get_tile(tile) == TileType.RAMP:
		return get_elevation(tile) + 0.5
	return float(get_elevation(tile))


func get_room_id(tile: Vector2i) -> int:
	for id in range(rooms.size()):
		if rooms[id].has_point(tile):
			return id
	return CORRIDOR_VAL if is_walkable(tile) else -2


func update_fog(player_tile: Vector2i) -> void:
	# Port of revealAt(): discovery deliberately differs from bright visibility.
	var room_id := get_room_id(player_tile)
	if room_id >= 0:
		var border := rooms[room_id].grow(1)
		for tile: Vector2i in tiles:
			if border.has_point(tile) and is_walkable(tile):
				discovered_tiles[tile] = true
	else:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var tile := player_tile + offset
			if is_walkable(tile):
				discovered_tiles[tile] = true
	# Prototype brightness, with a cardinal one-tile peek into room entrances.
	bright_tiles.clear()
	for tile: Vector2i in tiles:
		var tile_room := get_room_id(tile)
		var nearby := absi(tile.x - player_tile.x) <= 1 and absi(tile.y - player_tile.y) <= 1
		if room_id >= 0:
			if tile_room == room_id or (tile_room == CORRIDOR_VAL and nearby):
				bright_tiles[tile] = true
		elif room_id == CORRIDOR_VAL and tile_room < 0 and nearby:
			bright_tiles[tile] = true
		elif room_id == CORRIDOR_VAL and tile_room >= 0 and absi(tile.x - player_tile.x) + absi(tile.y - player_tile.y) == 1:
			bright_tiles[tile] = true


func is_bright(tile: Vector2i) -> bool:
	return bright_tiles.has(tile)
