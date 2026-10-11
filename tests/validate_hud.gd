extends SceneTree


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	var hud = main.get_node("HUD")
	var minimap = hud.minimap
	assert(hud.hp_label.text == "20 / 20 HP" and hud.hp_bar.value == 20)
	assert(hud.floor_label.text == "Floor #1")
	assert(main.player.level == 5 and main.enemies[0].level == 5)
	await process_frame
	var width: float = hud.hp_bar.size.x
	main.player.receive_damage(8)
	assert(hud.hp_label.text == "12 / 20 HP" and hud.hp_bar.value == 12)
	main.player.health.heal(3)
	assert(hud.hp_bar.value == 15)
	main.player.health.reset(17)
	assert(hud.hp_bar.max_value == 17 and hud.hp_label.text == "17 / 17 HP")
	main.player.health.damage(5)
	assert(hud.hp_label.text == "12 / 17 HP")
	main.player.health.damage(50)
	assert(hud.hp_bar.value == 0 and main.game_over)
	assert(hud.hp_bar.size.x == width)
	main.start_new_run()
	assert(hud.hp_bar.value == 20 and not main.game_over)
	# Discovery and illumination have different marker policies.
	assert(minimap.mapped_tiles().has(Vector2i(0, 0)))
	assert(not minimap.mapped_tiles().has(Vector2i(12, 4)))
	assert(minimap.visible_enemy_tiles().is_empty() and not minimap.has_stairs_marker())
	main.player.setup(Vector2i(11, 2), main.dungeon, main.dungeon_renderer)
	main.refresh_fog()
	assert(minimap.visible_enemy_tiles() == [Vector2i(10, 2)])
	assert(minimap.has_stairs_marker())
	assert(minimap.mapped_tiles().has(Vector2i(12, 4)))
	main.player.setup(Vector2i(2, 2), main.dungeon, main.dungeon_renderer)
	main.refresh_fog()
	assert(minimap.visible_enemy_tiles().is_empty())
	assert(minimap.mapped_tiles().has(Vector2i(12, 4)) and minimap.has_stairs_marker())
	# Moving enemies must use current positions/brightness, not remembered positions.
	var enemy: Skeleton = main.enemies[0]
	enemy.grid_position = Vector2i(6, 2)
	main.player.setup(Vector2i(5, 2), main.dungeon, main.dungeon_renderer)
	main.refresh_fog()
	assert(minimap.visible_enemy_tiles() == [Vector2i(6, 2)])
	assert(minimap.mapped_tiles().has(Vector2i(6, 2)))
	main.player.setup(Vector2i(2, 2), main.dungeon, main.dungeon_renderer)
	main.refresh_fog()
	assert(minimap.visible_enemy_tiles().is_empty())
	# Real combat must remove markers and update health through the same signal.
	main.load_test_floor()
	main.player.setup(Vector2i(9, 2), main.dungeon, main.dungeon_renderer)
	main.player.facing = Vector2i.RIGHT
	main.player.health.reset(20)
	main.player.health.damage(5)
	main.refresh_fog()
	main.player.basic_attack()
	assert(hud.hp_bar.value == 13 and minimap.visible_enemy_tiles().size() == 1)
	main.player.basic_attack()
	assert(hud.hp_bar.value == 16 and minimap.visible_enemy_tiles().is_empty())
	main.player.level = 7
	main.player.setup(Vector2i(11, 2), main.dungeon, main.dungeon_renderer)
	main.player.try_move(Vector2i.DOWN)
	assert(main.floor_number == 2 and hud.floor_label.text == "Floor #2")
	assert(main.player.level == 7 and hud.hp_bar.value == 16)
	assert(main.enemies[0].level == 5)
	assert(not minimap.has_stairs_marker() and not minimap.mapped_tiles().has(Vector2i(12, 4)))
	assert(minimap.player_tile == main.player.grid_position and minimap.dungeon == main.dungeon)
	main.start_new_run()
	assert(hud.floor_label.text == "Floor #1" and main.player.level == 5)
	# No staircase marker without an actual STAIRS tile.
	var no_stairs := DungeonData.new()
	no_stairs.set_tile(Vector2i.ZERO, DungeonData.TileType.FLOOR)
	no_stairs.update_fog(Vector2i.ZERO)
	var no_enemies: Array[Skeleton] = []
	minimap.refresh(no_stairs, Vector2i.ZERO, no_enemies)
	assert(not minimap.has_stairs_marker())
	assert(minimap.map_bounds.size == Vector2i.ONE)
	main.free()
	await process_frame
	print("PASS: HUD health/damage/healing/max/death, floor counter, unused levels, minimap discovery/markers/reset")
	quit()
