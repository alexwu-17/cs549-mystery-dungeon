class_name Player
extends Node3D

const HealthScript = preload("res://scripts/entities/health.gd")

signal stairs_reached
signal moved
signal attack_requested(target: Vector2i)

@export var maximum_hp: int = 20
@export var attack_damage: int = 3

var health: HealthScript = HealthScript.new()
var level: int = 5
# Presentation reference stays at the departure level until leaving a ramp.
var fog_elevation: int = 0
var gameplay_enabled: bool = true
var round_locked: bool = false
var facing: Vector2i = Vector2i.DOWN
var damage_tween: Tween
@onready var attack_leap: AttackLeap = $AttackLeap

var grid_position: Vector2i = Vector2i.ZERO ## The player's real position on a 2D grid
var dungeon_data: DungeonData
var dungeon_renderer: DungeonRenderer
var is_tile_occupied: Callable


func setup(
	start_position: Vector2i,
	data: DungeonData,
	renderer: DungeonRenderer
) -> void:
	attack_leap.finish()
	grid_position = start_position
	dungeon_data = data
	dungeon_renderer = renderer
	fog_elevation = data.get_elevation(start_position)

	update_world_position()


func update_world_position() -> void:
	position = dungeon_renderer.get_entity_world_position(grid_position)
	if dungeon_data.get_tile(grid_position) != DungeonData.TileType.RAMP:
		fog_elevation = dungeon_data.get_elevation(grid_position)
	
func _unhandled_input(event: InputEvent) -> void:
	
	if dungeon_data == null:
		return
	if event.is_action_pressed("basic_attack"):
		basic_attack()
		get_viewport().set_input_as_handled()
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
	if round_locked or attack_leap.active or not gameplay_enabled or health.current == 0 or dungeon_data == null or absi(direction.x) + absi(direction.y) != 1:
		return
	facing = direction
	var target_position := grid_position + direction
	var walkable := dungeon_data.can_traverse(grid_position, target_position)

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
	if is_tile_occupied.is_valid() and is_tile_occupied.call(target_position):
		print("MOVE BLOCKED: skeleton at ", target_position)
		return

	grid_position = target_position
	update_world_position()

	print("NEW WORLD POSITION: ", position)
	
	if dungeon_data.get_tile(grid_position) == DungeonData.TileType.STAIRS:
		print("STAIRS REACHED at ", grid_position)
		stairs_reached.emit()
		return
	moved.emit()


func basic_attack() -> void:
	if round_locked or attack_leap.active or not gameplay_enabled or health.current == 0 or dungeon_data == null:
		return
	attack_leap.play(facing)
	attack_requested.emit(grid_position + facing)


func receive_damage(amount: int) -> void:
	health.damage(amount)
	print("PLAYER HP: ", health.current, "/", health.maximum)
	if has_node("PlayerSprite"):
		if damage_tween != null:
			damage_tween.kill()
		$PlayerSprite.modulate = Color(1, 0.3, 0.3)
		damage_tween = create_tween()
		damage_tween.tween_property($PlayerSprite, "modulate", Color.WHITE, 0.15)


func complete_action() -> void:
	if attack_leap.active:
		await attack_leap.presentation_finished
