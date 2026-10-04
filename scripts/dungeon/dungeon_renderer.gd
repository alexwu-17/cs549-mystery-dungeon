class_name DungeonRenderer
extends Node3D


const TILE_SIZE: float = 1.0
const ELEVATION_HEIGHT: float = 1.0

var dungeon_data: DungeonData


func render_dungeon(data: DungeonData) -> void:
	dungeon_data = data

	for child in get_children():
		child.queue_free()

	for grid_position: Vector2i in dungeon_data.tiles:
		var tile_type: DungeonData.TileType = dungeon_data.get_tile(grid_position)

		if tile_type == DungeonData.TileType.VOID:
			continue

		create_floor_tile(grid_position)


func create_floor_tile(grid_position: Vector2i) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	box.size = Vector3(TILE_SIZE, 0.2, TILE_SIZE)
	mesh_instance.mesh = box

	var elevation := dungeon_data.get_elevation(grid_position)

	mesh_instance.position = grid_to_world(grid_position, elevation)

	add_child(mesh_instance)


func grid_to_world(grid_position: Vector2i, elevation: int = 0) -> Vector3:
	return Vector3(
		grid_position.x * TILE_SIZE,
		elevation * ELEVATION_HEIGHT,
		grid_position.y * TILE_SIZE
	)
