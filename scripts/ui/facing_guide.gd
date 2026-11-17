extends Control
## Presentation only: projects authoritative tiles without changing fog or terrain.
var player: Player
var was_active: bool = false
const YELLOW := Color(1.0, 0.85, 0.05, 0.35)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var active := player != null and player.holding_still
	if active or was_active:
		queue_redraw()
	was_active = active

func highlighted_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if player == null or not player.holding_still or not player.can_accept_movement():
		return tiles
	var data := player.dungeon_data
	var tile := player.grid_position
	tiles.append(tile)
	while true:
		var next := tile + player.facing
		if not data.is_bright(next) or not data.can_traverse(tile, next):
			break
		tiles.append(next)
		tile = next
	return tiles

func _draw() -> void:
	var tiles := highlighted_tiles()
	var camera := get_viewport().get_camera_3d()
	if tiles.is_empty() or camera == null:
		return
	for tile in tiles:
		var polygon := PackedVector2Array()
		for offset in [Vector2(-0.43, -0.43), Vector2(0.43, -0.43), Vector2(0.43, 0.43), Vector2(-0.43, 0.43)]:
			polygon.append(_project(tile, offset, camera))
		draw_colored_polygon(polygon, YELLOW)
		polygon.append(polygon[0])
		draw_polyline(polygon, Color(1.0, 0.85, 0.05, 0.85), 2.0, true)
	for direction: Vector2i in DungeonData.CARDINALS:
		var axis := Vector2(direction)
		var side := Vector2(-axis.y, axis.x)
		var triangle := PackedVector2Array()
		for offset in [axis * 0.39, axis * 0.21 + side * 0.10, axis * 0.21 - side * 0.10]:
			triangle.append(_project(player.grid_position, offset, camera))
		draw_colored_polygon(triangle, Color.WHITE)

func _project(tile: Vector2i, offset: Vector2, camera: Camera3D) -> Vector2:
	var world := player.dungeon_renderer.get_entity_world_position(tile)
	world += Vector3(offset.x, 0.025, offset.y)
	var data := player.dungeon_data
	if data.ramp_tiles.has(tile):
		var segment: Dictionary = data.ramp_segments[data.ramp_tiles[tile].segment]
		world.y += offset.dot(Vector2(segment.direction)) * DungeonData.ELEVATION_HEIGHT / 3.0
	elif data.legacy_ramp and data.get_tile(tile) == DungeonData.TileType.RAMP:
		world.y += offset.x * DungeonData.ELEVATION_HEIGHT
	return get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(world)
