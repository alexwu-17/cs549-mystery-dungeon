extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	assert(InputMap.action_get_events("wait_turn")[0].physical_keycode == KEY_J)
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(9): data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	var player: Player = main.player
	player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.refresh_fog()
	var rounds := [0]
	main.round_finished.connect(func(): rounds[0] += 1)
	player.health.damage(10)
	var hp := player.health.current
	var pp := player.battle_state.remaining_pp.duplicate()
	var facing := player.facing
	for index in range(14): assert(player.wait_turn())
	assert(rounds[0] == 14 and main.peaceful_turns == 14 and player.health.current == hp)
	assert(player.wait_turn())
	assert(player.health.current == hp + 1 and main.peaceful_turns == 0)
	assert(player.grid_position == Vector2i.ZERO and player.facing == facing and not player.attack_leap.active)
	assert(player.battle_state.remaining_pp == pp)
	# Walking shares the counter; blocked movement does not count.
	for index in range(4): assert(player.wait_turn())
	player.try_move(Vector2i.LEFT)
	assert(main.peaceful_turns == 4)
	player.try_move(Vector2i.RIGHT)
	Helper.complete(main)
	assert(player.health.current == hp + 2 and main.peaceful_turns == 0)
	assert(player.wait_turn())
	player.facing = Vector2i.UP
	player.basic_attack()
	Helper.complete(main)
	assert(main.peaceful_turns == 0)
	assert(player.wait_turn())
	assert(player.use_move(0))
	Helper.complete(main)
	assert(main.peaceful_turns == 0)
	assert(player.wait_turn())
	player.health.damage(1)
	assert(main.peaceful_turns == 0 and not main.recovery_started)
	hp = player.health.current
	for index in range(14): assert(player.wait_turn())
	assert(player.health.current == hp)
	assert(player.wait_turn())
	assert(player.health.current == hp + 1 and main.recovery_started)
	# Hold/release uses the same input/repeat path as movement, at its own speed.
	var key := InputEventAction.new()
	key.action = &"wait_turn"
	key.pressed = true
	Input.action_press(&"wait_turn")
	player._unhandled_input(key)
	var before: int = rounds[0]
	player._process(Player.MOVE_INTERVAL)
	assert(rounds[0] == before + 1 and player.movement_speed == 5.0)
	Input.action_release(&"wait_turn")
	player._process(0.0)
	assert(player.movement_speed == 1.0 and player.held_action == &"")
	# Hidden enemy gets exactly one movement per wait. Its reveal cancels the hold.
	player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	data.enemy_spawns = [Vector2i(3, 0)]
	main.spawn_test_enemies()
	main.refresh_fog()
	var enemy: Skeleton = main.enemies[0]
	assert(not enemy.visible and main._can_player_wait())
	Input.action_press(&"wait_turn")
	player._unhandled_input(key)
	assert(enemy.grid_position == Vector2i(2, 0) and player.held_action == &"wait_turn")
	player._process(Player.MOVE_INTERVAL)
	assert(enemy.grid_position == Vector2i(1, 0) and enemy.visible)
	assert(player.movement_speed == 1.0 and player.held_action == &"")
	before = rounds[0]
	assert(not player.wait_turn())
	player._process(10.0)
	assert(rounds[0] == before and enemy.battle_state.remaining_pp == [28])
	player._unhandled_input(key)
	assert(rounds[0] == before and player.held_action == &"")
	Input.action_release(&"wait_turn")
	# A damaging enemy phase invalidates a potential first heal.
	main.peaceful_turns = 14
	main.recovery_started = false
	hp = player.health.current
	main.run_enemy_turn(true)
	Helper.complete(main)
	assert(player.health.current < hp and main.peaceful_turns == 0)
	# An unfinished round cannot grant recovery after a fresh-run cancellation.
	main.peaceful_turns = 4
	main.run_enemy_turn(true)
	assert(main.resolving_turn)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.peaceful_turns == 0 and player.health.current == player.maximum_hp)
	# Waiting is locked during presentation/transitions; cancelled progress stays reset.
	player.transition_locked = true
	assert(not player.wait_turn())
	player.transition_locked = false
	main.peaceful_turns = 4
	main.cancel_round()
	assert(main.peaceful_turns == 0)
	assert(main.healing_on_kill == 0)
	main.start_new_run()
	assert(main.peaceful_turns == 0 and player.health.current == player.maximum_hp)
	Helper.complete_introduction(main)
	# Boss visibility uses the same authoritative footprint/fog rule.
	main.use_elevation_test = false
	main.game_mode = GameModeConfig.Mode.DEMO
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	main.dungeon.bright_tiles[main.boss.grid_position] = true
	main.refresh_entity_visibility()
	assert(not main._can_player_wait())
	main.free()
	await process_frame
	print("PASS: J wait/held5x, initial15 then5 peaceful turns per HP, walk/wait counters, attack/damage resets, visible-enemy/boss blocking and cancellation")
	quit()
