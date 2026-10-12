class_name Skeleton
extends Node3D

const HealthScript = preload("res://scripts/entities/health.gd")

const DIRECTIONS = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

signal attack_requested(damage: int)

@export var maximum_hp: int = 6
@export var attack_damage: int = 2
var health: HealthScript = HealthScript.new()
var level: int = 5
var facing: Vector2i = Vector2i.DOWN
@onready var character_visual: CharacterVisual = $VisualController
var damage_tween: Tween
@onready var attack_leap: AttackLeap = $AttackLeap

var grid_position: Vector2i
var dungeon_data: DungeonData
var dungeon_renderer: DungeonRenderer


func _ready() -> void:
	attack_leap.presentation_started.connect(character_visual.attack)
	attack_leap.presentation_finished.connect(character_visual.standing)


func setup(start: Vector2i, data: DungeonData, renderer: DungeonRenderer) -> void:
	attack_leap.finish()
	facing = Vector2i.DOWN
	character_visual.face(facing)
	health.reset(maximum_hp)
	grid_position = start
	dungeon_data = data
	dungeon_renderer = renderer
	position = dungeon_renderer.get_entity_world_position(grid_position)


func take_turn(player_position: Vector2i, occupied: Dictionary) -> void:
	if health.current == 0:
		return
	var difference := player_position - grid_position
	if difference == Vector2i.ZERO or dungeon_data.can_traverse(grid_position, player_position):
		if difference != Vector2i.ZERO:
			print("SKELETON ATTACK at ", grid_position, ": ", attack_damage)
			attack_leap.finish()
			facing = difference
			character_visual.face(facing)
			attack_leap.play(difference)
			attack_requested.emit(attack_damage)
		return
	var next := next_step_toward(player_position, occupied)
	if next == grid_position or next == player_position or occupied.has(next):
		return
	print("SKELETON MOVE: ", grid_position, " -> ", next)
	attack_leap.finish()
	facing = next - grid_position
	character_visual.face(facing)
	grid_position = next
	position = dungeon_renderer.get_entity_world_position(grid_position)


func receive_damage(amount: int) -> void:
	health.damage(amount)
	if health.current == 0:
		attack_leap.finish()
	print("SKELETON HP at ", grid_position, ": ", health.current, "/", health.maximum)
	if has_node("EnemyMesh"):
		if damage_tween != null:
			damage_tween.kill()
		$EnemyMesh.modulate = Color(1, 0.3, 0.3)
		damage_tween = create_tween()
		damage_tween.tween_property($EnemyMesh, "modulate", Color.WHITE, 0.15)


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
			if previous.has(neighbor) or not dungeon_data.can_traverse(current, neighbor):
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


func complete_action() -> void:
	if attack_leap.active:
		await attack_leap.presentation_finished
