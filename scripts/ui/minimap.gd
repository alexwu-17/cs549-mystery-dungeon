extends Control

const ROOM_COLOR = Color("60738b")
const CORRIDOR_COLOR = Color("3f5268")
const PLAYER_COLOR = Color("45da79")
const ENEMY_COLOR = Color("ee5353")
const STAIRS_COLOR = Color("56a8ff")

var dungeon: DungeonData
var player_tile: Vector2i
var enemies: Array[Skeleton] = []
var map_bounds: Rect2i


func _ready() -> void:
	resized.connect(queue_redraw)


func refresh(data: DungeonData, player_position: Vector2i, living_enemies: Array[Skeleton]) -> void:
	if dungeon != data:
		dungeon = data
		map_bounds = Rect2i(player_position, Vector2i.ONE)
		for tile: Vector2i in dungeon.tiles:
			map_bounds = map_bounds.merge(Rect2i(tile, Vector2i.ONE))
	player_tile = player_position
	# Keep the authoritative live list; no remembered enemy locations.
	enemies = living_enemies
	queue_redraw()


func mapped_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if dungeon != null:
		for tile: Vector2i in dungeon.discovered_tiles:
			if dungeon.is_walkable(tile):
				result.append(tile)
	return result


func visible_enemy_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if dungeon != null:
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.health.current > 0 and dungeon.is_bright(enemy.grid_position):
				result.append(enemy.grid_position)
	return result


func has_stairs_marker() -> bool:
	return dungeon != null and dungeon.get_tile(dungeon.stairs_position) == DungeonData.TileType.STAIRS and dungeon.discovered_tiles.has(dungeon.stairs_position)


func _draw() -> void:
	if dungeon == null:
		return
	var available := size - Vector2(16, 16)
	var cell := minf(available.x / maxf(1, map_bounds.size.x), available.y / maxf(1, map_bounds.size.y))
	var origin := (size - Vector2(map_bounds.size) * cell) / 2.0
	for tile in mapped_tiles():
		var corner := origin + Vector2(tile - map_bounds.position) * cell
		draw_rect(Rect2(corner, Vector2.ONE * cell), ROOM_COLOR if dungeon.get_room_id(tile) >= 0 else CORRIDOR_COLOR)
	if has_stairs_marker():
		var corner := origin + Vector2(dungeon.stairs_position - map_bounds.position) * cell
		draw_rect(Rect2(corner + Vector2.ONE * cell * 0.15, Vector2.ONE * cell * 0.7), STAIRS_COLOR, false, 1.5)
	for tile in visible_enemy_tiles():
		draw_circle(origin + (Vector2(tile - map_bounds.position) + Vector2.ONE * 0.5) * cell, maxf(1.5, cell * 0.3), ENEMY_COLOR)
	draw_circle(origin + (Vector2(player_tile - map_bounds.position) + Vector2.ONE * 0.5) * cell, maxf(1.5, cell * 0.35), PLAYER_COLOR)
