extends Node3D

const TEST_ENEMY_SCENE := preload("res://scenes/enemies/test_enemy.tscn")

@export var use_elevation_test: bool = false

@onready var dungeon_renderer: DungeonRenderer = $DungeonRenderer
@onready var player: Player = $Player
@onready var entities: Node3D = $Entities

var dungeon: DungeonData
var enemies: Array[Skeleton] = []
var enemy_occupancy: Dictionary = {}


func _ready() -> void:
	player.stairs_reached.connect(_on_stairs_reached)
	player.moved.connect(_on_player_moved)
	player.is_tile_occupied = is_enemy_occupied
	load_test_floor()


func _process(_delta: float) -> void:
	# Keep the larger procedural floor visible while retaining the fixture camera.
	if not use_elevation_test:
		$Camera3D.position = player.position + Vector3(0, 10, 8)


func load_test_floor() -> void:
	if use_elevation_test:
		dungeon = TestDungeonFactory.create_elevation_test_dungeon()
	else:
		dungeon = TestDungeonFactory.create_test_dungeon()

	dungeon_renderer.render_dungeon(dungeon)
	spawn_test_enemies()

	player.setup(
		dungeon.player_spawn,
		dungeon,
		dungeon_renderer
	)

	print("Player grid position after setup: ", player.grid_position)
	print("Player world position after setup: ", player.position)
	
func _on_stairs_reached() -> void:
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
		enemies.append(enemy)
		enemy_occupancy[spawn_position] = enemy


func is_enemy_occupied(tile: Vector2i) -> bool:
	return enemy_occupancy.has(tile)


func _on_player_moved() -> void:
	# Resolve sequentially so every skeleton sees the updated occupancy.
	for enemy in enemies:
		var previous := enemy.grid_position
		enemy.take_turn(player.grid_position, enemy_occupancy)
		enemy_occupancy.erase(previous)
		enemy_occupancy[enemy.grid_position] = enemy
