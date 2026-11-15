extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	for axis: Vector2i in DungeonData.CARDINALS:
		var data := DungeonData.new()
		data.add_ramp(Vector2i.ZERO, axis, 0)
		for index in [-3, -2, -1, 5, 6, 7]:
			data.set_tile(axis * index, DungeonData.TileType.FLOOR, 0 if index < 0 else 1)
		for start in range(-3, 8):
			for sign_value in [-1, 1]:
				var direction: Vector2i = axis * sign_value
				var origin := axis * start
				var occupied := func(tile: Vector2i) -> bool: return data.get_tile(tile) == DungeonData.TileType.RAMP
				var plan := PokemonProjectile.flight_plan(data, origin, direction, 4, occupied, true)
				var expected_angle: bool = start in [1, 2, 3] or (start == 0 and sign_value == 1) or (start == 4 and sign_value == -1)
				assert(plan.angled == expected_angle)
				if not expected_angle:
					assert(not plan.hits_actor)
					for tile: Vector2i in plan.path:
						assert(data.get_tile(tile) != DungeonData.TileType.RAMP)
				else:
					var clear := PokemonProjectile.flight_plan(data, origin, direction, 4)
					assert(not clear.path.is_empty())
					assert(clear.path.back() == axis * (4 if sign_value == 1 else 0))
					for target: Vector2i in clear.path:
						var target_only := func(tile: Vector2i) -> bool: return tile == target
						var hit := PokemonProjectile.flight_plan(data, origin, direction, 4, target_only)
						assert(hit.hits_actor and hit.path.back() == target)
	# Actual shots one tile outside each buffer stay level and cannot hit ramp actors.
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.elemental_move_floor = 1
	root.add_child(main)
	Helper.complete_introduction(main)
	for from_above in [false, true]:
		main.cancel_round()
		var data := DungeonData.new()
		data.add_ramp(Vector2i.ZERO, Vector2i.RIGHT, 0)
		var origin := Vector2i(5, 0) if from_above else Vector2i(-1, 0)
		data.set_tile(origin, DungeonData.TileType.FLOOR, 1 if from_above else 0)
		data.enemy_spawns = [Vector2i(2, 0)]
		main.dungeon = data
		assert(main.dungeon_renderer.render_dungeon(data))
		main.spawn_test_enemies()
		main.player.setup(origin, data, main.dungeon_renderer)
		main.player.facing = Vector2i.LEFT if from_above else Vector2i.RIGHT
		var enemy = main.enemies[0]
		var hp: int = enemy.health.current
		var pp: int = main.player.battle_state.remaining_pp[2]
		assert(main.player.use_move(2))
		var effect: ProjectileEffect
		for child in main.entities.get_children():
			if child is ProjectileEffect and not child.flight_completed: effect = child
		assert(effect != null and not effect.impact_pending)
		var height := effect.global_position.y
		effect.animation.pause()
		effect.animation.custom_step(main.player.character_visual.projectile_release_time() + 0.05)
		assert(is_equal_approx(effect.global_position.y, height))
		Helper.complete(main)
		assert(enemy.health.current == hp and main.player.battle_state.remaining_pp[2] == pp - 1)
		assert(not main.resolving_turn)
	main.free()
	await process_frame
	print("PASS: ramp/buffer-only angled shots, distant ramp immunity, cardinal/uphill/downhill targeting, level rendered flight, PP and round completion")
	quit()
