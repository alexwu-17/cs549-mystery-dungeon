extends Node3D


@onready var dungeon_renderer: DungeonRenderer = $DungeonRenderer


func _ready() -> void:
	var dungeon := TestDungeonFactory.create_test_dungeon()

	dungeon_renderer.render_dungeon(dungeon)
