extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var paths := ["main", "demo_main", "limit_testing_main"]
	for mode in range(3):
		var main = load("res://scenes/main/%s.tscn" % paths[mode]).instantiate()
		main.benchmark_enabled = false
		if mode == GameModeConfig.Mode.LIMIT_TESTING:
			# Tests must not inherit the user's current stress-test resource values.
			main.generation_config = DungeonGenerationConfig.new()
		assert(main.game_mode == mode)
		root.add_child(main)
		load("res://tests/round_test_helper.gd").complete_introduction(main)
		assert(main.boss == null)
		var config: DungeonGenerationConfig = main.generation_config
		assert((config != null) == (mode == GameModeConfig.Mode.LIMIT_TESTING))
		main.player.health.damage(5)
		for expected in range(2, 7):
			if mode == GameModeConfig.Mode.DEMO and expected > GameModeConfig.DEMO_FINAL_FLOOR:
				var arena: DungeonData = main.dungeon
				main._on_stairs_reached()
				load("res://tests/round_test_helper.gd").complete_introduction(main)
				assert(main.floor_number == GameModeConfig.DEMO_FINAL_FLOOR and main.dungeon == arena)
				continue
			# Walk onto real stairs; block no enemies in the chosen approach tile.
			var entered := false
			for direction: Vector2i in DungeonData.CARDINALS:
				var neighbor: Vector2i = main.dungeon.stairs_position - direction
				if main.dungeon.can_traverse(neighbor, main.dungeon.stairs_position):
					main.player.setup(neighbor, main.dungeon, main.dungeon_renderer)
					main.player.try_move(direction)
					load("res://tests/round_test_helper.gd").complete_introduction(main)
					entered = true
					break
			assert(entered and main.floor_number == expected)
			assert(main.player.health.current == 15)
			assert(main.hud.floor_label.text == "Floor #%d" % expected)
			assert(main.hud.minimap.dungeon == main.dungeon)
			if mode != GameModeConfig.Mode.DEMO or expected < GameModeConfig.DEMO_FINAL_FLOOR:
				assert(main.boss == null)
			if mode == GameModeConfig.Mode.DEMO and expected == GameModeConfig.DEMO_FINAL_FLOOR:
				assert(main.dungeon.rooms == [Rect2i(8, 5, 11, 11)])
				assert(main.dungeon.tiles.size() == 61)
				assert(TestDungeonFactory.reachable_tiles(main.dungeon).size() == 61)
				assert(main.player.grid_position == Vector2i(13, 13))
				assert(DemoArenaFactory.BOSS_CENTER == Vector2i(13, 9))
				for y in range(5, 16):
					for x in range(8, 19):
						assert(main.dungeon.is_walkable(Vector2i(x, y)) == (absi(x - 13) + absi(y - 10) <= 5))
				for y in range(-1, 2):
					for x in range(-1, 2):
						assert(main.dungeon.is_walkable(DemoArenaFactory.BOSS_CENTER + Vector2i(x, y)))
				assert(main.enemies.is_empty() and main.enemy_occupancy.is_empty())
				assert(main.boss != null and main.boss.health.current == 30)
				assert(not main.hud.minimap.has_stairs_marker())
				for tile: Vector2i in main.dungeon.tiles:
					assert(main.dungeon.get_tile(tile) == DungeonData.TileType.FLOOR)
		main.player.receive_damage(100)
		assert(main.game_over)
		var restart := InputEventKey.new()
		restart.physical_keycode = KEY_R
		restart.pressed = true
		main._unhandled_input(restart)
		load("res://tests/round_test_helper.gd").complete_introduction(main)
		assert(main.game_mode == mode and main.generation_config == config)
		assert(main.floor_number == 1 and main.player.health.current == 20 and main.player.level == 5)
		assert(not main.game_over and main.enemies.size() == 3)
		assert(main.boss == null and not main.victory)
		assert(main.hud.minimap.dungeon == main.dungeon)
		main.free()
	await process_frame
	assert(ProjectSettings.get_setting("application/run/main_scene.demo_build") == "res://scenes/main/demo_main.tscn")
	assert(ProjectSettings.get_setting("application/run/main_scene.limit_testing_build") == "res://scenes/main/limit_testing_main.tscn")
	print("PASS: three entry modes, real stairs, infinite floor 6, demo arena/cap, HP/fog/HUD cleanup, death/R mode persistence, export settings")
	quit()
