class_name Player
extends Node3D

signal stairs_reached

var grid_position: Vector2i = Vector2i.ZERO ## The player's real position on a 2D grid
var dungeon_data: DungeonData
var dungeon_renderer: DungeonRenderer


func setup(
	start_position: Vector2i,
	data: DungeonData,
	renderer: DungeonRenderer
) -> void:
	grid_position = start_position
	dungeon_data = data
	dungeon_renderer = renderer

	update_world_position()


func update_world_position() -> void:
	position = dungeon_renderer.get_entity_world_position(grid_position)
	
func _unhandled_input(event: InputEvent) -> void:
	
	if dungeon_data == null:
		return

	if event.is_action_pressed("move_up"):
		try_move(Vector2i(0, -1))

	elif event.is_action_pressed("move_down"):
		try_move(Vector2i(0, 1))

	elif event.is_action_pressed("move_left"):
		try_move(Vector2i(-1, 0))

	elif event.is_action_pressed("move_right"):
		try_move(Vector2i(1, 0))

## Movement functions below

func try_move(direction: Vector2i) -> void:
	var target_position := grid_position + direction
	var walkable := dungeon_data.is_walkable(target_position)

	print(
		"MOVE: ",
		grid_position,
		" -> ",
		target_position,
		" | walkable = ",
		walkable
	)

	if not walkable:
		return

	grid_position = target_position
	update_world_position()

	print("NEW WORLD POSITION: ", position)
	
	if dungeon_data.get_tile(grid_position) == DungeonData.TileType.STAIRS:
		print("STAIRS REACHED at ", grid_position)
		stairs_reached.emit()
