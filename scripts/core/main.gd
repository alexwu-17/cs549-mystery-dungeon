extends Node3D

const TEST_ENEMY_SCENE := preload("res://scenes/enemies/test_enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/minotaur.tscn")

@export var use_elevation_test: bool = false
@export var game_mode: GameModeConfig.Mode = GameModeConfig.Mode.INFINITE
@export var generation_config: DungeonGenerationConfig

@onready var dungeon_renderer: DungeonRenderer = $DungeonRenderer
@onready var player: Player = $Player
@onready var entities: Node3D = $Entities
@onready var dialogue: CombatDialogue = $HUD/Screen/CombatDialogue
@onready var hud = $HUD
@onready var presentation_camera = $Camera3D

var dungeon: DungeonData
var enemies: Array[Skeleton] = []
var enemy_occupancy: Dictionary = {}
var game_over: bool = false
var victory: bool = false
var boss: Minotaur
signal enemy_action_started(enemy: Node3D)
signal round_finished
var round_generation: int = 0
var turn_rng := RandomNumberGenerator.new()
var resolving_turn: bool = false
var loading_floor: bool = false
var floor_number: int = 1
@export var healing_on_kill: int = 3


func _ready() -> void:
	turn_rng.randomize()
	player.stairs_reached.connect(_on_stairs_reached)
	player.moved.connect(_on_player_moved)
	player.attack_requested.connect(_on_player_attack)
	player.health.died.connect(_on_player_died)
	player.is_tile_occupied = is_enemy_occupied
	hud.bind_health(player.health)
	start_new_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		start_new_run()
		get_viewport().set_input_as_handled()


func start_new_run() -> void:
	cancel_round()
	dialogue.clear_history()
	game_over = false
	victory = false
	hud.set_game_over(false)
	resolving_turn = false
	player.gameplay_enabled = true
	player.facing = Vector2i.DOWN
	player.level = 5
	floor_number = 1
	player.health.reset(player.maximum_hp)
	print("NEW RUN: PLAYER HP ", player.health.current, "/", player.health.maximum)
	load_test_floor()


func _process(_delta: float) -> void:
	update_presentation()


func update_presentation() -> void:
	presentation_camera.follow_sprite(player.get_node("PlayerSprite"))
	dungeon_renderer.update_occlusion(presentation_camera, player.grid_position, presentation_camera.sprite_samples(player.get_node("PlayerSprite")))


func load_test_floor() -> void:
	cancel_round()
	loading_floor = true
	player.gameplay_enabled = false
	if use_elevation_test:
		dungeon = TestDungeonFactory.create_elevation_test_dungeon()
	elif GameModeConfig.is_arena(game_mode, floor_number):
		dungeon = DemoArenaFactory.create_arena()
	elif game_mode == GameModeConfig.Mode.LIMIT_TESTING:
		if generation_config == null:
			push_error("Limit Testing requires a generation configuration.")
			return
		dungeon = TestDungeonFactory.create_configured_dungeon(generation_config)
		if dungeon == null:
			# Invalid experiments remain stopped; do not silently use defaults.
			return
	else:
		dungeon = TestDungeonFactory.create_test_dungeon()
		print("ELEVATION FLOOR: ", TestDungeonFactory.last_statistics, " | room heights=", dungeon.room_elevations, " | ramps=", dungeon.ramp_segments)

	dungeon_renderer.render_dungeon(dungeon)
	spawn_test_enemies()

	player.setup(
		dungeon.player_spawn,
		dungeon,
		dungeon_renderer
	)

	print("Player grid position after setup: ", player.grid_position)
	print("Player world position after setup: ", player.position)
	refresh_fog()
	loading_floor = false
	player.gameplay_enabled = not game_over and not victory
	
func _on_stairs_reached() -> void:
	if game_over or victory or loading_floor or not GameModeConfig.can_advance(game_mode, floor_number):
		return
	floor_number += 1
	print("Loading next test floor...")
	load_test_floor()

func spawn_test_enemies() -> void:
	# Remove enemies from the previous floor.
	if is_instance_valid(boss):
		boss.free()
	boss = null
	enemy_occupancy.clear()
	for enemy in enemies:
		enemy.free()
	enemies.clear()

	for spawn_position: Vector2i in dungeon.enemy_spawns:
		var enemy: Skeleton = TEST_ENEMY_SCENE.instantiate()
		enemy.add_to_group("test_enemies")
		entities.add_child(enemy)

		enemy.setup(spawn_position, dungeon, dungeon_renderer)
		enemy.attack_requested.connect(_on_enemy_attack.bind("Skeleton"))
		enemies.append(enemy)
		enemy_occupancy[spawn_position] = enemy
	if game_mode == GameModeConfig.Mode.DEMO and floor_number == GameModeConfig.DEMO_FINAL_FLOOR and not use_elevation_test:
		boss = BOSS_SCENE.instantiate()
		entities.add_child(boss)
		boss.setup(DemoArenaFactory.BOSS_CENTER, dungeon, dungeon_renderer)
		boss.attack_requested.connect(_on_enemy_attack.bind("Minotaur"))
		boss.presentation_event.connect(_on_boss_message)
		boss.defeated.connect(_on_boss_defeated)


func is_enemy_occupied(tile: Vector2i) -> bool:
	return enemy_occupancy.has(tile) or (is_instance_valid(boss) and boss.occupies(tile))


func _on_player_moved() -> void:
	run_enemy_turn()


func _on_player_attack(target: Vector2i) -> void:
	if game_over or victory or resolving_turn or loading_floor:
		return
	var delta := target - player.grid_position
	if absi(delta.x) + absi(delta.y) != 1:
		return
	if dungeon.can_traverse(player.grid_position, target) and is_instance_valid(boss) and boss.occupies(target):
		print("PLAYER ATTACK MINOTAUR at ", target)
		dialogue.append_event(&"attack", {"actor": "Swordsman", "target": "Minotaur", "amount": mini(player.attack_damage, boss.health.current)})
		boss.receive_damage(player.attack_damage)
		if not victory:
			run_enemy_turn()
		else:
			refresh_fog()
		return
	if not dungeon.can_traverse(player.grid_position, target) or not enemy_occupancy.has(target):
		print("PLAYER ATTACK MISSED at ", target)
		run_enemy_turn()
		return
	var enemy: Skeleton = enemy_occupancy[target]
	print("PLAYER ATTACK at ", target, ": ", player.attack_damage)
	dialogue.append_event(&"attack", {"actor": "Swordsman", "target": "Skeleton", "amount": mini(player.attack_damage, enemy.health.current)})
	enemy.receive_damage(player.attack_damage)
	if enemy.health.current == 0:
		dialogue.append_event(&"defeat", {"target": "Skeleton"})
		print("SKELETON DIED at ", target)
		enemy_occupancy.erase(target)
		enemies.erase(enemy)
		# Detach immediately; deletion waits until the current signal has unwound.
		entities.remove_child(enemy)
		enemy.queue_free()
		var healed: int = player.health.heal(healing_on_kill)
		if healed > 0:
			dialogue.append_event(&"heal", {"amount": healed})
		print("HEALED ", healed, ": PLAYER HP ", player.health.current, "/", player.health.maximum)
	run_enemy_turn()


func _on_player_died() -> void:
	# Finish the player's presentation, but let the lethal skeleton's leap play
	# beneath the immediate overlay. Floor replacement frees enemy animations.
	game_over = true
	dialogue.append_event(&"game_over")
	player.attack_leap.finish()
	hud.set_game_over(true)
	player.gameplay_enabled = false
	print("PLAYER DIED. GAME OVER. Press R to restart.")


func _on_boss_defeated() -> void:
	if game_mode != GameModeConfig.Mode.DEMO:
		return
	victory = true
	dialogue.append_event(&"victory")
	cancel_round()
	player.gameplay_enabled = false
	hud.set_victory()
	print("VICTORY: Minotaur defeated. Press R to restart the demo.")


func cancel_round() -> void:
	# Invalidate before emitting completion signals: old continuations must stop.
	dialogue.abandon_round()
	round_generation += 1
	resolving_turn = false
	player.round_locked = false
	player.attack_leap.finish()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.attack_leap.finish()


func _exit_tree() -> void:
	cancel_round()


func run_enemy_turn() -> void:
	if game_over or victory or resolving_turn or loading_floor:
		return
	resolving_turn = true
	player.round_locked = true
	var token := round_generation
	refresh_fog()
	await player.complete_action()
	if token != round_generation:
		return
	var order: Array[Node3D] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health.current > 0:
			order.append(enemy)
	if is_instance_valid(boss) and boss.health.current > 0:
		order.append(boss)
	# Fisher-Yates uses independent randomness, not the generator's global RNG.
	for index in range(order.size() - 1, 0, -1):
		var other := turn_rng.randi_range(0, index)
		var temporary := order[index]
		order[index] = order[other]
		order[other] = temporary
	for actor in order:
		if token != round_generation or game_over or victory or loading_floor:
			break
		if not is_instance_valid(actor) or actor.health.current == 0:
			continue
		enemy_action_started.emit(actor)
		if token != round_generation or game_over or victory:
			break
		if actor is Skeleton:
			var previous: Vector2i = actor.grid_position
			actor.take_turn(player.grid_position, enemy_occupancy)
			if token != round_generation:
				return
			enemy_occupancy.erase(previous)
			enemy_occupancy[actor.grid_position] = actor
		else:
			actor.take_turn(player.grid_position)
		if token != round_generation:
			return
		refresh_fog()
		await actor.complete_action()
		if token != round_generation:
			return
	if token != round_generation:
		return
	resolving_turn = false
	player.round_locked = false
	if not game_over and not victory:
		dialogue.end_round()
	round_finished.emit()


func refresh_fog() -> void:
	dungeon.update_fog(player.grid_position)
	dungeon_renderer.apply_fog(player.fog_elevation)
	for enemy in enemies:
		enemy.visible = dungeon.is_bright(enemy.grid_position)
	if is_instance_valid(boss) and boss.state != Minotaur.State.DEAD:
		boss.refresh_visibility()
	hud.refresh_map(dungeon, player.grid_position, enemies, floor_number)
	hud.minimap.refresh_boss(boss)
	update_presentation()


func _on_enemy_attack(amount: int, actor_name: String) -> void:
	dialogue.append_event(&"attack", {"actor": actor_name, "target": "Swordsman", "amount": mini(amount, player.health.current)})
	player.receive_damage(amount)


func _on_boss_message(kind: StringName) -> void:
	dialogue.append_event(kind)
