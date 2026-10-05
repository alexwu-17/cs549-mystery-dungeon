class_name DungeonRenderer
extends Node3D


const TILE_SIZE: float = 1.0
const ELEVATION_HEIGHT: float = 1.0
const FLOOR_THICKNESS: float = 0.2

var dungeon_data: DungeonData


func render_dungeon(data: DungeonData) -> void:
	dungeon_data = data

	for child in get_children():
		child.free()

	for grid_position: Vector2i in dungeon_data.tiles:
		var tile_type: DungeonData.TileType = dungeon_data.get_tile(grid_position)

		if tile_type == DungeonData.TileType.VOID:
			continue

		if tile_type == DungeonData.TileType.RAMP:
			create_ramp_tile(grid_position)
		elif tile_type == DungeonData.TileType.STAIRS:
			create_stairs_tile(grid_position)
		else:
			create_floor_tile(grid_position)

		create_floor_tile(grid_position)


func create_floor_tile(grid_position: Vector2i) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	box.size = Vector3(TILE_SIZE, FLOOR_THICKNESS, TILE_SIZE)
	mesh_instance.mesh = box

	var elevation := dungeon_data.get_elevation(grid_position)

	mesh_instance.position = grid_to_world(grid_position, elevation)

	add_child(mesh_instance)

func create_ramp_tile(grid_position: Vector2i) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	box.size = Vector3(TILE_SIZE, 0.2, TILE_SIZE)
	mesh_instance.mesh = box

	var elevation := dungeon_data.get_elevation(grid_position)

	mesh_instance.position = grid_to_world(grid_position, elevation)

	# Tilt upward toward Room 2 (+X direction).
	mesh_instance.rotation_degrees.z = 45.0

	# Raise it slightly so the ramp visually connects the two levels.
	mesh_instance.position.y += ELEVATION_HEIGHT / 2.0

	add_child(mesh_instance)

func create_stairs_tile(grid_position: Vector2i) -> void:
	# Create the normal floor underneath the staircase marker.
	create_floor_tile(grid_position)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	box.size = Vector3(
		TILE_SIZE * 0.6,
		0.15,
		TILE_SIZE * 0.6
	)

	mesh_instance.mesh = box

	var elevation := dungeon_data.get_elevation(grid_position)

	mesh_instance.position = grid_to_world(
		grid_position,
		elevation
	)

	mesh_instance.position.y += 0.2

	add_child(mesh_instance)


func grid_to_world(grid_position: Vector2i, elevation: int = 0) -> Vector3:
	return Vector3(
		grid_position.x * TILE_SIZE,
		elevation * ELEVATION_HEIGHT,
		grid_position.y * TILE_SIZE
	)

func get_entity_world_position(grid_position: Vector2i) -> Vector3:
	var elevation := dungeon_data.get_elevation(grid_position)
	var world_position := grid_to_world(grid_position, elevation)

	# Characters/entities stand on the top surface of the floor,
	# not at the center of the floor mesh.
	world_position.y += FLOOR_THICKNESS / 2.0

	# Ramp entities stand halfway between the two elevation levels
	# in this temporary single-tile ramp implementation.
	if dungeon_data.get_tile(grid_position) == DungeonData.TileType.RAMP:
		world_position.y += ELEVATION_HEIGHT / 2.0

	return world_position
