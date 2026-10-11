extends Node3D

const TEST_ENEMY_SCENE := preload("res://scenes/enemies/test_enemy.tscn")

@export var use_elevation_test: bool = false

@onready var dungeon_renderer: DungeonRenderer = $DungeonRenderer
@onready var player: Player = $Player
@onready var entities: Node3D = $Entities
@onready var hud = $HUD
@onready var presentation_camera = $Camera3D

var dungeon: DungeonData
var enemies: Array[Skeleton] = []
var enemy_occupancy: Dictionary = {}
var game_over: bool = false
var resolving_turn: bool = false
var loading_floor: bool = false
var floor_number: int = 1
@export var healing_on_kill: int = 3


func _ready() -> void:
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
	game_over = false
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
	loading_floor = true
	player.gameplay_enabled = false
	if use_elevation_test:
		dungeon = TestDungeonFactory.create_elevation_test_dungeon()
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
	player.gameplay_enabled = not game_over
	
func _on_stairs_reached() -> void:
	floor_number += 1
	print("Loading next test floor...")
	load_test_floor()

func spawn_test_enemies() -> void:
	# Remove enemies from the previous floor.
	enemy_occupancy.clear()
	for enemy in enemies:
		enemy.free()
	enemies.clear()

	for spawn_position: Vector2i in dungeon.enemy_spawns:
		var enemy: Skeleton = TEST_ENEMY_SCENE.instantiate()
		enemy.add_to_group("test_enemies")
		entities.add_child(enemy)

		enemy.setup(spawn_position, dungeon, dungeon_renderer)
		enemy.attack_requested.connect(player.receive_damage)
		enemies.append(enemy)
		enemy_occupancy[spawn_position] = enemy


func is_enemy_occupied(tile: Vector2i) -> bool:
	return enemy_occupancy.has(tile)


func _on_player_moved() -> void:
	run_enemy_turn()


func _on_player_attack(target: Vector2i) -> void:
	if game_over or resolving_turn or loading_floor:
		return
	var delta := target - player.grid_position
	if absi(delta.x) + absi(delta.y) != 1:
		return
	if not dungeon.can_traverse(player.grid_position, target) or not enemy_occupancy.has(target):
		print("PLAYER ATTACK MISSED at ", target)
		run_enemy_turn()
		return
	var enemy: Skeleton = enemy_occupancy[target]
	print("PLAYER ATTACK at ", target, ": ", player.attack_damage)
	enemy.receive_damage(player.attack_damage)
	if enemy.health.current == 0:
		print("SKELETON DIED at ", target)
		enemy_occupancy.erase(target)
		enemies.erase(enemy)
		# Detach immediately; deletion waits until the current signal has unwound.
		entities.remove_child(enemy)
		enemy.queue_free()
		var healed: int = player.health.heal(healing_on_kill)
		print("HEALED ", healed, ": PLAYER HP ", player.health.current, "/", player.health.maximum)
	run_enemy_turn()


func _on_player_died() -> void:
	game_over = true
	hud.set_game_over(true)
	player.gameplay_enabled = false
	print("PLAYER DIED. GAME OVER. Press R to restart.")


func run_enemy_turn() -> void:
	if game_over or resolving_turn or loading_floor:
		return
	resolving_turn = true
	# Resolve sequentially so every skeleton sees the updated occupancy.
	for enemy in enemies:
		if game_over:
			break
		var previous := enemy.grid_position
		enemy.take_turn(player.grid_position, enemy_occupancy)
		enemy_occupancy.erase(previous)
		enemy_occupancy[enemy.grid_position] = enemy
	resolving_turn = false
	refresh_fog()


func refresh_fog() -> void:
	dungeon.update_fog(player.grid_position)
	dungeon_renderer.apply_fog()
	for enemy in enemies:
		enemy.visible = dungeon.is_bright(enemy.grid_position)
	hud.refresh_map(dungeon, player.grid_position, enemies, floor_number)
	update_presentation()
