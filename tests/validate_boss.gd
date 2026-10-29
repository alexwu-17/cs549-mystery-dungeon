extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.boss == null)
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	var boss: Minotaur = main.boss
	assert(boss.health.current == 30 and boss.grid_position == DemoArenaFactory.BOSS_CENTER)
	assert(main.player.grid_position == DemoArenaFactory.PLAYER_SPAWN)
	assert(main.enemies.is_empty() and boss.footprint() == [Vector2i(13, 9)] and boss.visible)
	var sprite: Sprite3D = boss.get_node("BossSprite")
	# Transparent extraction padding is not the rendered character width.
	var artwork := sprite.texture.get_image()
	var left := artwork.get_width()
	var right := 0
	for y in range(artwork.get_height()):
		for x in range(artwork.get_width()):
			if artwork.get_pixel(x, y).a > 0.5:
				left = mini(left, x)
				right = maxi(right, x)
	assert(is_equal_approx((right - left + 1) * sprite.pixel_size, 2.0))
	assert(sprite.position.x == 0 and sprite.position.z == 0.5)
	for direction: Vector2i in DungeonData.CARDINALS:
		boss.facing = direction
		assert(boss.footprint() == [Vector2i(13, 9)])
	for tile in boss.footprint():
		assert(main.is_enemy_occupied(tile) and main.dungeon.is_walkable(tile))
	assert(not boss.can_occupy(Vector2i(12, 5), main.player.grid_position))
	assert(boss.can_occupy(boss.grid_position + Vector2i.DOWN, boss.grid_position + Vector2i(0, 2)))
	assert(not main.is_enemy_occupied(boss.grid_position+Vector2i.DOWN))
	assert(not boss.can_occupy(boss.grid_position+Vector2i.DOWN,boss.grid_position+Vector2i.DOWN))
	# Enumerate valid body centers and verify an immediate dodge exists for every
	# walkable threat tile. No arena geometry changes are needed.
	var centers := 0
	var dodges := 0
	var trapped := 0
	for tile: Vector2i in main.dungeon.tiles:
		var fits := true
		for body_tile in boss.footprint_at(tile):
			fits = fits and main.dungeon.is_walkable(body_tile)
		if not fits:
			continue
		centers += 1
		boss.grid_position = tile
		var region := boss.attack_tiles()
		var unique: Dictionary = {}
		for threatened in region:
			assert(main.dungeon.is_walkable(threatened) and not boss.footprint().has(threatened) and not unique.has(threatened))
			unique[threatened] = true
			var escape := false
			for step: Vector2i in DungeonData.CARDINALS:
				var destination := threatened + step
				escape = escape or (main.dungeon.can_traverse(threatened, destination) and not region.has(destination) and not boss.footprint_at(tile).has(destination))
			if escape:
				dodges += 1
			else:
				trapped += 1
	assert(centers == 61)
	# The full valid anchor space is connected under the actual body traversal.
	boss.grid_position = DemoArenaFactory.BOSS_CENTER
	var visited := {boss.grid_position: true}
	var queue: Array[Vector2i] = [boss.grid_position]
	var queue_index := 0
	while queue_index < queue.size():
		boss.grid_position = queue[queue_index]
		queue_index += 1
		for step: Vector2i in DungeonData.CARDINALS:
			var destination := boss.grid_position + step
			if not visited.has(destination) and boss.can_occupy(destination, Vector2i(-100, -100)):
				visited[destination] = true
				queue.append(destination)
	assert(visited.size() == centers)
	assert(dodges > trapped)
	print("BOSS ARENA: ", centers, " valid 1x1 anchors; ", dodges, " threat positions with a one-step dodge; ", trapped, " edge hazards")
	# Attack/body collision from all four directions.
	boss.grid_position = DemoArenaFactory.ARENA_CENTER
	var regions: Array = []
	for direction: Vector2i in DungeonData.CARDINALS:
		boss.facing = direction
		var region := boss.attack_tiles()
		assert(region.size() == 2)
		for tile in region:
			assert(not boss.footprint().has(tile))
		assert(not regions.has(region))
		regions.append(region)
	for direction: Vector2i in DungeonData.CARDINALS:
		boss.health.reset(30)
		boss.state = Minotaur.State.HUNTING
		boss.clear_charge()
		main.player.setup(boss.grid_position + direction, main.dungeon, main.dungeon_renderer)
		main.player.facing = -direction
		var start: Vector2i = main.player.grid_position
		main.player.try_move(-direction)
		load("res://tests/round_test_helper.gd").complete(main)
		load("res://tests/round_test_helper.gd").complete_introduction(main)
		assert(main.player.grid_position == start and boss.state == Minotaur.State.HUNTING)
		main.player.basic_attack()
		load("res://tests/round_test_helper.gd").complete(main)
		assert(boss.health.current == 27 and boss.state == Minotaur.State.CHARGING)
		assert(boss.threatened_tiles.size() == 2 and boss.markers.size() == 2)
		for index in range(boss.markers.size()):
			assert(boss.markers[index].global_position.is_equal_approx(main.dungeon_renderer.get_entity_world_position(boss.threatened_tiles[index]) + Vector3(0, 0.035, 0)))
	# Greedy pursuit moves at most one tile; entering range by moving does not
	# start and resolve a charge within that turn.
	boss.clear_charge()
	boss.state = Minotaur.State.HUNTING
	boss.grid_position = DemoArenaFactory.BOSS_CENTER
	boss.take_turn(DemoArenaFactory.PLAYER_SPAWN)
	assert(boss.grid_position == Vector2i(13, 10) and boss.state == Minotaur.State.HUNTING)
	# Player attacks charge, blocked bumps do nothing, escaping causes a miss.
	boss.grid_position = DemoArenaFactory.BOSS_CENTER
	main.player.setup(Vector2i(13, 10), main.dungeon, main.dungeon_renderer)
	main.player.health.reset(20)
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	var locked: Array[Vector2i] = boss.threatened_tiles.duplicate()
	var locked_facing := boss.facing
	var locked_position := boss.grid_position
	for child in boss.get_children():
		if child is StatChangeEffect:
			child.animation.pause()
			child.animation.custom_step(1.0)
	await process_frame
	assert(boss.state == Minotaur.State.CHARGING and boss.markers.size() == 2 and main.player.health.current == 20)
	assert(boss.grid_position == locked_position)
	for marker in boss.markers:
		assert(marker.visible)
	main.player.try_move(Vector2i.UP)
	load("res://tests/round_test_helper.gd").complete(main)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(boss.threatened_tiles == locked and boss.facing == locked_facing and main.player.health.current == 20)
	main.player.try_move(Vector2i.RIGHT)
	load("res://tests/round_test_helper.gd").complete(main)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.player.health.current == 20 and boss.state == Minotaur.State.COOLDOWN and boss.markers.is_empty())
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(boss.state == Minotaur.State.HUNTING) # Entire cooldown turn spent.
	# Hit for exactly 18, then kill during charge: no last attack or lifesteal.
	boss.grid_position = DemoArenaFactory.BOSS_CENTER
	boss.health.reset(30)
	main.player.setup(Vector2i(13, 10), main.dungeon, main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(boss.state == Minotaur.State.CHARGING and main.player.health.current == 20)
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.player.health.current == 2 and boss.state == Minotaur.State.COOLDOWN)
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(boss.state == Minotaur.State.HUNTING)
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(boss.state == Minotaur.State.CHARGING)
	boss.health.reset(3)
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.victory and not main.game_over and boss.state == Minotaur.State.DEAD)
	assert(not main.player.attack_leap.active)
	assert(main.player.health.current == 2 and boss.markers.is_empty() and not main.player.gameplay_enabled)
	for child in boss.get_children():
		assert(not child is StatChangeEffect)
	assert(not main.is_enemy_occupied(boss.grid_position))
	assert(main.hud.get_node("Screen/GameOver/Center/Text/Title").text == "Demo Complete")
	main.run_enemy_turn()
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.player.health.current == 2)
	var restart := InputEventKey.new()
	restart.physical_keycode = KEY_R
	restart.pressed = true
	main._unhandled_input(restart)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.boss == null and not main.victory and main.floor_number == 1 and main.game_mode == GameModeConfig.Mode.DEMO)
	assert(main.player.health.current == 20 and not main.hud.get_node("Screen/GameOver").visible)
	# Losing to a charge uses the original game-over path, not victory.
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	boss = main.boss
	main.player.setup(Vector2i(13, 10), main.dungeon, main.dungeon_renderer)
	main.player.health.reset(18)
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.game_over and not main.victory and main.player.health.current == 0)
	main._unhandled_input(restart)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(main.boss == null and not main.game_over and main.player.health.current == 20)
	# Restart during an active charge removes markers/effects with their owner.
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	boss = main.boss
	main.player.setup(Vector2i(13, 10), main.dungeon, main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(boss.markers.size() == 2)
	main._unhandled_input(restart)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(not is_instance_valid(boss) and main.boss == null)
	main.free()
	await process_frame
	print("PASS: boss footprint/dodges, four-sided attacks, greedy pursuit, locked charge/hit/miss/cooldown, victory/no lifesteal/R")
	quit()
