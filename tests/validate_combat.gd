extends SceneTree

const HealthScript = preload("res://scripts/entities/health.gd")


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	var health: HealthScript = HealthScript.new()
	var deaths: Array[int] = [0]
	health.died.connect(func(): deaths[0] += 1)
	health.reset(20)
	health.damage(-1)
	assert(health.current == 20)
	health.damage(4)
	assert(health.heal(3) == 3 and health.current == 19)
	assert(health.heal(3) == 1 and health.current == 20)
	health.damage(99)
	health.damage(99)
	assert(health.current == 0 and deaths[0] == 1 and health.heal(3) == 0)
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var data := DungeonData.new()
	for x in range(5):
		for y in range(3):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i(1, 1)
	data.enemy_spawns = [Vector2i(2, 1), Vector2i(4, 1)]
	data.stairs_position = Vector2i(1, 2)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS)
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	var first: Skeleton = main.enemies[0]
	var second: Skeleton = main.enemies[1]
	main.player.try_move(Vector2i(1, 1))
	main.player.try_move(Vector2i(-2, 0))
	assert(first.health.current == 6 and main.player.health.current == 20)
	main.player.try_move(Vector2i.RIGHT)
	assert(first.health.current == 6 and main.player.health.current == 20)
	assert(second.grid_position == Vector2i(4, 1))
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.player.grid_position == data.player_spawn)
	assert(first.health.current == 3 and main.player.health.current == 18)
	assert(second.grid_position == Vector2i(3, 1))
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.enemies.size() == 1 and main.enemy_occupancy.size() == 1)
	assert(main.player.health.current == 20)
	assert(second.grid_position == Vector2i(2, 1))
	# A newly adjacent skeleton does not also attack on the turn it moves.
	main.player.receive_damage(6)
	main.player.try_move(Vector2i.DOWN)
	assert(main.player.health.current == 14)
	assert(main.player.grid_position == main.dungeon.player_spawn)
	for enemy: Skeleton in main.enemies:
		assert(enemy.health.current == 6)
	# Multiple adjacent enemies: death from the first must stop the phase.
	main.dungeon = data
	data.enemy_spawns = [Vector2i(2, 1), Vector2i(1, 0)]
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.player.health.reset(20)
	main.player.receive_damage(18)
	var attacks: Array[int] = [0]
	for enemy: Skeleton in main.enemies:
		enemy.attack_requested.connect(func(_damage: int): attacks[0] += 1)
	main.player.try_move(Vector2i.RIGHT)
	assert(not main.game_over and attacks[0] == 0)
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.game_over and main.player.health.current == 0 and attacks[0] == 1)
	main.player.try_move(Vector2i.DOWN)
	assert(main.player.grid_position == data.player_spawn and attacks[0] == 1)
	var old_enemy: WeakRef = weakref(main.enemies[0])
	var restart := InputEventKey.new()
	restart.physical_keycode = KEY_R
	restart.pressed = true
	main._unhandled_input(restart)
	assert(not main.game_over and main.player.health.current == 20)
	assert(old_enemy.get_ref() == null and main.enemies.size() == 3)
	main.free()
	await process_frame
	print("PASS: health, blocked bumps, basic attacks, single enemy phases, kill removal/healing, HP across stairs, game over, R restart")
	quit()
