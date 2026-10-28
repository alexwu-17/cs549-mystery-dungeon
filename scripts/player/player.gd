class_name Player
extends Node3D

const HealthScript = preload("res://scripts/entities/health.gd")

signal stairs_reached
signal movement_speed_changed(speed: float)
signal moved
signal attack_requested(target: Vector2i)

@export var maximum_hp: int = 20
@export var attack_damage: int = 3

const MOVE_INTERVAL: float = 0.24
const HELD_SPEED: float = 3.0
var held_action: StringName = &""
var held_direction: Vector2i = Vector2i.ZERO
var repeat_remaining: float = 0.0
var movement_speed: float = 1.0

var health: HealthScript = HealthScript.new()
var invincible: bool = false
var level: int = 5
# Presentation reference stays at the departure level until leaving a ramp.
var fog_elevation: int = 0
var gameplay_enabled: bool = true
var round_locked: bool = false
var transition_locked: bool = false
var facing: Vector2i = Vector2i.DOWN
var damage_tween: Tween
@onready var character_visual: CharacterVisual = $VisualController
@onready var attack_leap: AttackLeap = $AttackLeap

var grid_position: Vector2i = Vector2i.ZERO ## The player's real position on a 2D grid
var dungeon_data: DungeonData
var dungeon_renderer: DungeonRenderer
var is_tile_occupied: Callable


func _ready() -> void:
	attack_leap.presentation_started.connect(character_visual.attack)
	attack_leap.presentation_finished.connect(character_visual.standing)


func setup(
	start_position: Vector2i,
	data: DungeonData,
	renderer: DungeonRenderer
) -> void:
	stop_held_movement()
	attack_leap.finish()
	character_visual.cancel()
	character_visual.face(facing)
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

	var actions := [&"move_up", &"move_down", &"move_left", &"move_right"]
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for index in range(actions.size()):
		if event.is_action_released(actions[index]) and held_action == actions[index]:
			stop_held_movement()
		elif event.is_action_pressed(actions[index]):
			stop_held_movement()
			if not can_accept_movement():
				return
			held_action = actions[index]
			held_direction = directions[index]
			repeat_remaining = MOVE_INTERVAL
			try_move(held_direction)
			get_viewport().set_input_as_handled()
			return


func can_accept_movement() -> bool:
	return not transition_locked and not round_locked and not attack_leap.active and gameplay_enabled and health.current > 0 and dungeon_data != null


func stop_held_movement() -> void:
	held_action = &""
	held_direction = Vector2i.ZERO
	repeat_remaining = 0.0
	_set_movement_speed(1.0)


func _set_movement_speed(speed: float) -> void:
	if movement_speed != speed:
		movement_speed = speed
		movement_speed_changed.emit(speed)


func _process(delta: float) -> void:
	if held_action == &"":
		return
	if not Input.is_action_pressed(held_action) or transition_locked or not gameplay_enabled or health.current == 0:
		stop_held_movement()
		return
	repeat_remaining = maxf(0.0, repeat_remaining - delta)
	if repeat_remaining > 0.0:
		return
	_set_movement_speed(HELD_SPEED)
	if can_accept_movement():
		repeat_remaining = MOVE_INTERVAL / HELD_SPEED
		try_move(held_direction)

## Movement functions below

func try_move(direction: Vector2i) -> void:
	if transition_locked or round_locked or attack_leap.active or not gameplay_enabled or health.current == 0 or dungeon_data == null or absi(direction.x) + absi(direction.y) != 1:
		return
	facing = direction
	character_visual.face(facing)
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
		stop_held_movement()
		return
	if is_tile_occupied.is_valid() and is_tile_occupied.call(target_position):
		stop_held_movement()
		print("MOVE BLOCKED: skeleton at ", target_position)
		return

	character_visual.walk()
	grid_position = target_position
	update_world_position()

	print("NEW WORLD POSITION: ", position)
	
	if dungeon_data.get_tile(grid_position) == DungeonData.TileType.STAIRS:
		stop_held_movement()
		print("STAIRS REACHED at ", grid_position)
		stairs_reached.emit()
		return
	moved.emit()


func basic_attack() -> void:
	if transition_locked or round_locked or attack_leap.active or not gameplay_enabled or health.current == 0 or dungeon_data == null:
		return
	stop_held_movement()
	character_visual.face(facing)
	attack_leap.play(facing)
	attack_requested.emit(grid_position + facing)


func receive_damage(amount: int) -> void:
	if invincible:
		print("LIMIT TESTING: blocked player damage ", amount)
		return
	var previous_hp := health.current
	health.damage(amount)
	if health.current > 0 and health.current < previous_hp:
		character_visual.hurt()
	elif health.current == 0:
		character_visual.freeze_defeated()
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		stop_held_movement()
