extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	var player: Player = main.player
	var leap: AttackLeap = player.attack_leap
	var sprite: Sprite3D = player.get_node("PlayerSprite")
	var original := sprite.transform
	var logical := player.grid_position
	var root_position := player.position
	assert(is_equal_approx(leap.duration, 0.24) and is_equal_approx(leap.hop_height, 0.15))
	# Exercise all directions and the exact peak without relying on wall-clock time.
	for direction: Vector2i in DungeonData.CARDINALS:
		leap.play(direction)
		leap.animation.pause()
		leap.animation.custom_step(0.12)
		var expected := Vector3(direction.x, 0.15, direction.y) * DungeonData.TILE_SIZE
		assert((sprite.position - original.origin).is_equal_approx(expected))
		assert(player.grid_position == logical and player.position == root_position)
		var same_tween := leap.animation
		leap.play(direction)
		assert(leap.animation == same_tween)
		leap.animation.custom_step(0.13)
		assert(not leap.active and sprite.transform == original)
	# Empty/non-walkable attacks trigger animation, while extra input is blocked.
	var data := DungeonData.new()
	data.set_tile(Vector2i.ZERO, DungeonData.TileType.FLOOR)
	data.set_tile(Vector2i.RIGHT, DungeonData.TileType.WALL)
	data.set_tile(Vector2i.DOWN, DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	var actions: Array[int] = [0]
	player.attack_requested.connect(func(_target: Vector2i): actions[0] += 1)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.UP]:
		player.facing = direction
		player.basic_attack()
		assert(leap.active)
		var count := actions[0]
		player.basic_attack()
		player.try_move(Vector2i.DOWN)
		assert(actions[0] == count and player.grid_position == Vector2i.ZERO and player.facing == direction)
		leap.animation.pause()
		leap.animation.custom_step(0.12)
		assert(is_equal_approx((sprite.position - original.origin).length_squared(), 1.0 + 0.15 * 0.15))
		leap.finish()
		assert(sprite.transform == original)
	# Skeleton attacks have visual overlap but retain occupancy and immediate damage.
	data.set_tile(Vector2i.RIGHT, DungeonData.TileType.FLOOR)
	data.enemy_spawns = [Vector2i.RIGHT]
	main.spawn_test_enemies()
	var enemy: Skeleton = main.enemies[0]
	var enemy_visual: Node3D = enemy.get_node("EnemyMesh")
	var enemy_transform := enemy_visual.transform
	player.facing = Vector2i.RIGHT
	player.basic_attack()
	assert(enemy.health.current == 3 and player.health.current == 20)
	assert(leap.active and not enemy.attack_leap.active)
	leap.finish()
	assert(player.health.current == 18 and enemy.attack_leap.active)
	enemy.attack_leap.animation.pause()
	enemy.attack_leap.animation.custom_step(0.12)
	assert((enemy_visual.position - enemy_transform.origin).is_equal_approx(Vector3(-1, 0.15, 0)))
	assert(enemy.grid_position == Vector2i.RIGHT and main.enemy_occupancy.has(Vector2i.RIGHT))
	leap.finish()
	enemy.attack_leap.finish()
	data.set_tile(Vector2i(2, 0), DungeonData.TileType.FLOOR)
	data.set_tile(Vector2i(3, 0), DungeonData.TileType.FLOOR)
	enemy.take_turn(Vector2i(3, 0), {})
	assert(enemy.grid_position == Vector2i(2, 0) and not enemy.attack_leap.active)
	enemy.take_turn(Vector2i(99, 99), {})
	assert(enemy.grid_position == Vector2i(2, 0) and not enemy.attack_leap.active)
	enemy.setup(Vector2i.RIGHT, data, main.dungeon_renderer)
	# A lethal attack leaves only the killer's leap running beneath game over.
	player.health.reset(2)
	player.facing = Vector2i.UP
	player.basic_attack()
	leap.finish()
	enemy = main.enemies[0]
	assert(main.game_over and not leap.active and enemy.attack_leap.active)
	var killer: WeakRef = weakref(enemy)
	main.start_new_run()
	assert(killer.get_ref() == null and not leap.active and sprite.transform == original)
	# Floor changes and setup cancel a partially played leap exactly.
	leap.play(Vector2i.RIGHT)
	leap.animation.pause()
	leap.animation.custom_step(0.1)
	main.load_test_floor()
	assert(not leap.active and sprite.transform == original)
	main.free()
	await process_frame
	print("PASS: full-tile/0.15-hop/0.24s leap, exact restore, misses/walls/hits, input lock, skeleton occupancy/damage, lethal presentation/reset")
	quit()
