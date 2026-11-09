extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func layout() -> DungeonData:
	var data := DungeonData.new()
	data.rooms = [Rect2i(0, 0, 3, 3), Rect2i(12, 0, 3, 3), Rect2i(30, 0, 3, 3)]
	for room in data.rooms:
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	for x in range(3, 12): data.set_tile(Vector2i(x, 1), DungeonData.TileType.CORRIDOR)
	data.player_spawn = Vector2i(1, 1)
	data.stairs_position = Vector2i(14, 1)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS)
	data.update_fog(data.player_spawn)
	return data

func finish_wait(main: Node3D) -> void:
	assert(main.player.wait_turn())
	Helper.complete(main)
	assert(not main.resolving_turn)

func defeat_last(main: Node3D) -> void:
	var enemy: Skeleton = main.enemies[0]
	main.enemy_occupancy.erase(enemy.grid_position)
	enemy.setup(Vector2i(2, 1), main.dungeon, main.dungeon_renderer)
	main.enemy_occupancy[enemy.grid_position] = enemy
	enemy.health.damage(enemy.health.current - 1)
	main.refresh_entity_visibility()
	main.player.facing = Vector2i.RIGHT
	main.player.basic_attack()
	Helper.complete(main)
	assert(main.enemies.is_empty() and main.repopulation.empty_turns == 0)

func validate() -> void:
	var state := EnemyRepopulation.new()
	var data := layout()
	var eligible := state.candidates(data, data.player_spawn, {})
	assert(not eligible.is_empty())
	for tile in eligible:
		assert(data.get_room_id(tile) == 1 and not data.is_bright(tile))
		assert(data.get_tile(tile) == DungeonData.TileType.FLOOR and not data.reserved_transitions.has(tile))
	# Discovery history does not block a currently hidden room; occupancy does.
	for tile in eligible: data.discovered_tiles[tile] = true
	assert(state.candidates(data, data.player_spawn, {}).size() == eligible.size())
	var occupied := {}
	for tile in eligible: occupied[tile] = true
	assert(state.choose(data, data.player_spawn, occupied) == null)
	var corridor_tile := Vector2i(5, 1)
	data.update_fog(corridor_tile)
	for tile in state.candidates(data, corridor_tile, {}):
		assert(data.get_room_id(tile) >= 0 and data.get_tile(tile) == DungeonData.TileType.FLOOR)
	# A real hidden actor still pursues once per player round after respawning.
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	main.dungeon = layout()
	assert(main.dungeon_renderer.render_dungeon(main.dungeon, true))
	main.spawn_test_enemies()
	main.player.setup(main.dungeon.player_spawn, main.dungeon, main.dungeon_renderer)
	main.use_elevation_test = false
	main.refresh_fog()
	assert(main.enemy_respawn_delay == 100)
	main.repopulation.rng.seed = 10
	for index in range(99):
		finish_wait(main)
		assert(main.enemies.is_empty() and main.repopulation.empty_turns == index + 1)
	finish_wait(main)
	assert(main.enemies.size() == 1 and main.repopulation.empty_turns == 0)
	var enemy: Skeleton = main.enemies[0]
	assert(main.dungeon.get_room_id(enemy.grid_position) == 1 and not enemy.visible)
	assert(enemy.health.current == 42 and enemy.level == 10 and enemy.battle_state.remaining_pp == [28])
	assert(main.enemy_occupancy.get(enemy.grid_position) == enemy)
	var initial := enemy.grid_position
	finish_wait(main)
	assert(enemy.grid_position != initial and not enemy.visible)
	assert(main.repopulation.empty_turns == 0 and main.enemies.size() == 1)
	defeat_last(main)
	for index in range(99):
		finish_wait(main)
		assert(main.enemies.is_empty())
	finish_wait(main)
	assert(main.enemies.size() == 1 and main.enemies[0] != enemy)
	assert(main.enemies[0].battle_state.remaining_pp == [28])
	# No safe area: bounded retry, no spawn into the player's room or corridors.
	defeat_last(main)
	main.dungeon.rooms.resize(1)
	for index in range(100): finish_wait(main)
	assert(main.enemies.is_empty() and main.repopulation.empty_turns == 0)
	finish_wait(main)
	assert(main.repopulation.empty_turns == 1)
	# Rejected wait and rendering/idle frames do not advance the timer.
	main.player.transition_locked = true
	assert(not main.player.wait_turn())
	main.update_presentation()
	assert(main.repopulation.empty_turns == 1)
	main.player.transition_locked = false
	main.cancel_round()
	assert(main.repopulation.empty_turns == 0)
	main.game_mode = GameModeConfig.Mode.DEMO
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	for index in range(100): main._advance_repopulation()
	assert(main.enemies.is_empty() and main.repopulation.empty_turns == 0)
	main.game_mode = GameModeConfig.Mode.INFINITE
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.enemies.size() == 3 and main.repopulation.empty_turns == 0)
	main.free()
	await process_frame
	print("PASS: hidden pursuit, 100 enemy-free turns/repeated single respawn, independent state, safe room/reachable/fog/occupancy selection, bounded fallback and floor/arena reset")
	quit()
