extends SceneTree

const RoundHelper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	RoundHelper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(5):
		data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = []
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	var player: Player = main.player
	var rounds := [0]
	main.round_finished.connect(func(): rounds[0] += 1)
	var key := InputEventAction.new()
	key.action = &"move_right"
	key.pressed = true
	Input.action_press(&"move_right")
	player._unhandled_input(key)
	assert(player.grid_position == Vector2i(1, 0) and player.movement_speed == 1.0)
	player._process(Player.MOVE_INTERVAL / 2.0)
	assert(player.grid_position == Vector2i(1, 0))
	player._process(Player.MOVE_INTERVAL / 2.0)
	assert(player.grid_position == Vector2i(2, 0) and player.movement_speed == 3.0)
	assert(player.attack_leap.action_speed == 3.0)
	player.round_locked = true
	player._process(1.0)
	assert(player.grid_position == Vector2i(2, 0))
	player.round_locked = false
	player._process(0.0)
	assert(player.grid_position == Vector2i(3, 0))
	Input.action_release(&"move_right")
	player._process(0.0)
	assert(player.movement_speed == 1.0 and player.held_action == &"")
	Input.action_press(&"move_right")
	player._unhandled_input(key)
	assert(player.grid_position == Vector2i(4, 0))
	var before: int = rounds[0]
	player._process(Player.MOVE_INTERVAL)
	assert(player.grid_position == Vector2i(4, 0) and rounds[0] == before)
	assert(player.movement_speed == 1.0 and player.held_action == &"")
	player._process(10.0)
	assert(rounds[0] == before)
	Input.action_release(&"move_right")
	# Occupied tiles stop repetition without an automatic bump attack.
	data.enemy_spawns = [Vector2i(3, 0)]
	main.spawn_test_enemies()
	var enemy: Skeleton = main.enemies[0]
	main._set_action_speed(3.0)
	enemy.attack_leap.play(Vector2i.RIGHT)
	enemy.attack_leap.animation.pause()
	enemy.attack_leap.animation.custom_step(0.04)
	assert(enemy.attack_leap.active)
	main._set_action_speed(1.0)
	var half_remaining := (enemy.attack_leap.duration - 0.04 * 3.0) / 2.0
	enemy.attack_leap.animation.custom_step(half_remaining)
	assert(enemy.attack_leap.active)
	enemy.attack_leap.animation.custom_step(half_remaining + 0.001)
	assert(not enemy.attack_leap.active)
	player.try_move(Vector2i.LEFT)
	assert(player.grid_position == Vector2i(4, 0) and rounds[0] == before)
	assert(enemy.health.current == enemy.health.maximum)
	Input.action_press(&"move_right")
	player.held_action = &"move_right"
	player._set_movement_speed(3.0)
	main.cancel_round()
	assert(player.held_action == &"" and player.movement_speed == 1.0)
	assert(enemy.attack_leap.action_speed == 1.0)
	Input.action_release(&"move_right")
	main.free()
	await process_frame
	print("PASS: held movement delay, 3x cadence, round lock, release, wall stop and no blocked turns")
	quit()
