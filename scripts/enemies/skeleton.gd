class_name Skeleton
extends Node3D

const DIRECTIONS = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var grid_position: Vector2i
var dungeon_data: DungeonData
var dungeon_renderer: DungeonRenderer


func setup(start: Vector2i, data: DungeonData, renderer: DungeonRenderer) -> void:
	grid_position = start
	dungeon_data = data
	dungeon_renderer = renderer
	position = dungeon_renderer.get_entity_world_position(grid_position)


func take_turn(player_position: Vector2i, occupied: Dictionary) -> void:
	var difference := player_position - grid_position
	if absi(difference.x) + absi(difference.y) <= 1:
		return
	var next := next_step_toward(player_position, occupied)
	if next == grid_position or next == player_position or occupied.has(next):
		return
	print("SKELETON MOVE: ", grid_position, " -> ", next)
	grid_position = next
	position = dungeon_renderer.get_entity_world_position(grid_position)


func next_step_toward(goal: Vector2i, occupied: Dictionary) -> Vector2i:
	# Search toward the player, but take_turn never steps onto the goal itself.
	var queue: Array[Vector2i] = [grid_position]
	var previous: Dictionary = {grid_position: grid_position}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		if current == goal:
			break
		for direction: Vector2i in DIRECTIONS:
			var neighbor := current + direction
			if previous.has(neighbor) or not dungeon_data.is_walkable(neighbor):
				continue
			if occupied.has(neighbor):
				continue
			previous[neighbor] = current
			queue.append(neighbor)
	if not previous.has(goal):
		return grid_position
	var step := goal
	while step != grid_position and previous[step] != grid_position:
		step = previous[step]
	return step
