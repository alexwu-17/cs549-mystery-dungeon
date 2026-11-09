class_name Skeleton
extends Node3D

const DIRECTIONS = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

signal attack_requested(damage: int)

# Legacy/fallback HP remains editable when no species is assigned.
@export var maximum_hp: int = 6:
	get:
		return species_data.maximum_hp if species_data != null else maximum_hp
@export var attack_damage: int = 2 ## Legacy signal/fallback; Main resolves authored stat damage.
@export var species_data: PokemonSpeciesData
@export var attack_policy: EnemyAttackPolicy
var attack_rng := RandomNumberGenerator.new()
var active_attack_move: PokemonMoveData
var battle_state: PokemonBattleState = PokemonBattleState.new()
var health: EntityHealth:
	get:
		return battle_state.health
var level: int:
	get:
		return battle_state.level
	set(value):
		battle_state.level = value
var facing: Vector2i = Vector2i.DOWN
@onready var character_visual: CharacterVisual = $VisualController
var damage_tween: Tween
@onready var attack_leap: AttackLeap = $AttackLeap

var grid_position: Vector2i
var dungeon_data: DungeonData
var dungeon_renderer: DungeonRenderer


func _ready() -> void:
	attack_rng.randomize() # Independent of generation and Main's shuffle RNG.
	attack_leap.presentation_started.connect(character_visual.attack)
	attack_leap.presentation_finished.connect(character_visual.standing)
	attack_leap.presentation_finished.connect(_clear_attack_move)


func setup(start: Vector2i, data: DungeonData, renderer: DungeonRenderer) -> void:
	attack_leap.finish()
	character_visual.cancel()
	facing = Vector2i.DOWN
	character_visual.face(facing)
	reset_battle_state()
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
			attack_leap.finish()
			active_attack_move = attack_policy.choose_and_spend(battle_state, attack_rng, _supports_move) if attack_policy != null else null
			print("SKELETON ATTACK at ", grid_position, ": ", active_attack_move.display_name if active_attack_move != null else "Basic")
			facing = difference
			character_visual.face(facing)
			character_visual.prepare_attack(active_attack_move.animation_action if active_attack_move != null else &"Attack")
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
	character_visual.walk()
	grid_position = next
	position = dungeon_renderer.get_entity_world_position(grid_position)


func _supports_move(move: PokemonMoveData) -> bool:
	return move.targeting == PokemonMoveData.Targeting.ADJACENT and move.range_tiles == 1 and move.category != PokemonMoveData.Category.STATUS


func _clear_attack_move() -> void:
	active_attack_move = null


func receive_damage(amount: int) -> void:
	if health.current == 0: return
	var previous_hp := health.current
	health.damage(amount)
	if health.current > 0 and health.current < previous_hp:
		character_visual.hurt()
	if health.current == 0:
		attack_leap.finish()
		if damage_tween != null: damage_tween.kill()
		character_visual.sprite.modulate = Color.WHITE
		character_visual.defeat()
		return
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


func reset_battle_state() -> void:
	active_attack_move = null
	battle_state.reset(species_data, maximum_hp, 5)
