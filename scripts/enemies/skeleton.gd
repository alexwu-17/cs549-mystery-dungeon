class_name Skeleton
extends Node3D

const DIRECTIONS = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

signal attack_requested(damage: int)
signal attack_resolution_finished
var attack_resolution_pending := false
var active_projectile_plan: Dictionary = {}

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


func take_turn(player_position: Vector2i, occupied: Dictionary, projectile_occupied: Callable = Callable()) -> void:
	if health.current == 0:
		return
	var difference := player_position - grid_position
	if difference == Vector2i.ZERO:
		return
	var adjacent := dungeon_data.can_traverse(grid_position, player_position)
	var blocker := projectile_occupied if projectile_occupied.is_valid() else func(tile: Vector2i): return tile == player_position or occupied.has(tile)
	var can_execute := func(move: PokemonMoveData):
		if move.move_id == &"splash": return true
		if move.targeting == PokemonMoveData.Targeting.SCREEN: return true
		if move.category == PokemonMoveData.Category.STATUS: return false
		if move.targeting == PokemonMoveData.Targeting.ADJACENT:
			return adjacent and move.range_tiles == 1
		return not projectile_plan(move, player_position, blocker).is_empty()
	# The policy filters ineligible shots before rolling or spending PP.
	# A basic choice at range pursues rather than inventing a ranged basic attack.
	active_attack_move = attack_policy.choose_and_spend(battle_state, attack_rng, can_execute) if attack_policy != null else null
	if adjacent or active_attack_move != null:
		var chosen := active_attack_move
		attack_leap.finish()
		active_attack_move = chosen
		active_projectile_plan = projectile_plan(chosen, player_position, blocker) if chosen != null and chosen.targeting == PokemonMoveData.Targeting.STRAIGHT_PROJECTILE else {}
		facing = Vector2i(signi(difference.x), signi(difference.y))
		if chosen != null and chosen.move_id == &"splash":
			facing = Vector2i(signi(difference.x), 0) if absi(difference.x) > absi(difference.y) else Vector2i(0, signi(difference.y))
		character_visual.face(facing)
		character_visual.prepare_attack(chosen.animation_action if chosen != null else &"Attack")
		attack_leap.play(facing)
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


func projectile_plan(move: PokemonMoveData, target: Vector2i, blocker: Callable) -> Dictionary:
	if move == null or move.targeting != PokemonMoveData.Targeting.STRAIGHT_PROJECTILE:
		return {}
	var delta := target - grid_position
	if delta == Vector2i.ZERO or (delta.x != 0 and delta.y != 0):
		return {}
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	var plan := PokemonProjectile.flight_plan(dungeon_data, grid_position, direction, move.range_tiles, blocker, dungeon_renderer.is_open_upper_tile(grid_position))
	var path: Array[Vector2i] = plan.path
	return plan if bool(plan.hits_actor) and not path.is_empty() and path.back() == target else {}


func finish_attack_resolution() -> void:
	if not attack_resolution_pending: return
	attack_resolution_pending = false
	attack_resolution_finished.emit()


func layer_over_projectile(effect: ProjectileEffect) -> void:
	effect.set_behind_source(facing != Vector2i.DOWN)
	if facing == Vector2i.DOWN: return
	var sprite := character_visual.sprite
	var original_cut := sprite.alpha_cut
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	effect.flight_finished.connect(func(_arrived: bool):
		if is_instance_valid(sprite): sprite.alpha_cut = original_cut, CONNECT_ONE_SHOT)


func _clear_attack_move() -> void:
	active_attack_move = null


func receive_damage(amount: int) -> void:
	if health.current == 0: return
	var previous_hp := health.current
	health.damage(amount)
	if health.current > 0 and health.current < previous_hp:
		character_visual.begin_damage_recovery()
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
	if attack_resolution_pending:
		await attack_resolution_finished


func reset_battle_state() -> void:
	active_attack_move = null
	battle_state.reset(species_data, maximum_hp, 5)
