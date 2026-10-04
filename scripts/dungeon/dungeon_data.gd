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


var tiles: Dictionary = {}
var elevations: Dictionary = {}

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
