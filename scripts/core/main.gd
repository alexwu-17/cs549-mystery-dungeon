extends Node3D

const TEST_ENEMY_SCENE := preload("res://scenes/enemies/test_enemy.tscn")

@export var use_elevation_test: bool = false

@onready var dungeon_renderer: DungeonRenderer = $DungeonRenderer
@onready var player: Player = $Player
@onready var entities: Node3D = $Entities

var dungeon: DungeonData


func _ready() -> void:
	player.stairs_reached.connect(_on_stairs_reached)
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
	for child in get_tree().get_nodes_in_group("test_enemies"):
		child.free()

	for spawn_position: Vector2i in dungeon.enemy_spawns:
		var enemy := TEST_ENEMY_SCENE.instantiate()
		enemy.add_to_group("test_enemies")
		entities.add_child(enemy)

		enemy.position = dungeon_renderer.get_entity_world_position(
			spawn_position
		)
