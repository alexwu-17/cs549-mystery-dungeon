extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
const NAMES := ["budew", "feebas", "riolu", "gible"]
const STATS := [[34,19,19,12,12],[48,19,19,19,19],[48,19,19,19,19],[62,21,21,17,17]]
const MOVES := [&"bullet_seed", &"splash", &"scratch", &"dragon_breath"]
const CLIPS := ["Shoot", "Hop", "Strike", "Shoot"]
const PROBABILITIES := [0.5, 0.75, 0.75, 0.35]
func _initialize() -> void:
	call_deferred("validate")

func choice_seed(probability: float, use_move: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(1000):
		rng.seed = value
		if (rng.randf() < probability) == use_move: return value
	assert(false)
	return 0

func make_main(name: String, tile: Vector2i) -> Node3D:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(7):
		for y in range(3): data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	main.player.health.reset(1000)
	var enemy: Skeleton = load("res://scenes/enemies/%s.tscn" % name).instantiate()
	main.entities.add_child(enemy)
	enemy.setup(tile, data, main.dungeon_renderer)
	enemy.attack_requested.connect(main._on_enemy_attack.bind(enemy))
	main.enemies.append(enemy)
	main.enemy_occupancy[tile] = enemy
	main.refresh_fog()
	return main

func validate() -> void:
	for index in range(4):
		var tile := Vector2i(1 if index == 2 else 2, 0)
		if index == 1: tile = Vector2i(5, 2) # Splash at range and diagonal.
		var main := make_main(NAMES[index], tile)
		var enemy: Skeleton = main.enemies[0]
		var state := enemy.battle_state
		var move := state.moves[0]
		assert(enemy.level == 10 and state.moves.size() == 1 and move.move_id == MOVES[index])
		assert([enemy.health.maximum,state.attack,state.special_attack,state.defense,state.special_defense] == STATS[index])
		if index == 0:
			assert(move.power == 5 and move.maximum_pp == 20 and move.range_tiles == 4)
			assert(move.category == PokemonMoveData.Category.PHYSICAL)
		assert(enemy.attack_policy.move_probability == PROBABILITIES[index])
		var types := PackedStringArray(["Grass"] if index == 0 else ["Water"] if index == 1 else ["Fighting"] if index == 2 else ["Ground","Dragon"])
		assert(state.species.types == types)
		for action in ["Idle","Walk","Hurt","Attack"]:
			assert(enemy.character_visual.profile.animations[action] == action)
			assert(enemy.character_visual.clips.has(action))
		assert(enemy.character_visual.profile.animations[str(move.animation_action)] == CLIPS[index])
		assert(enemy.character_visual.clips.has(CLIPS[index]))
		var hp: int = main.player.health.current
		var pp := state.remaining_pp[0]
		enemy.attack_rng.seed = choice_seed(PROBABILITIES[index], true)
		main.player.basic_attack()
		Helper._complete_leap(main.player.attack_leap)
		assert(enemy.active_attack_move == move and state.remaining_pp[0] == pp - 1)
		assert(enemy.character_visual.clip == CLIPS[index])
		assert(main.player.health.current == hp)
		if index == 0:
			var seed_effect: ProjectileEffect
			for child in main.entities.get_children():
				if child is ProjectileEffect: seed_effect = child
			assert(seed_effect != null)
			assert(seed_effect.sprite.material_override.shader == ProjectileEffect.BULLET_SEED_SHADER)
			assert(seed_effect.ground_shadow == null)
			assert(Helper._complete_projectile(main))
			assert(main.player.health.current == hp)
			var sparks: ProjectileImpactEffect
			for child in main.player.get_children():
				if child is ProjectileImpactEffect: sparks = child
			assert(sparks != null and sparks.bullet_seed)
			assert(sparks.material.get_shader_parameter("impact"))
			assert(sparks.sprite.hframes == 1 and sparks.sprite.vframes == 1)
		if index == 1:
			assert(enemy.grid_position == tile and main.resolving_turn)
			var history: Array = main.dialogue.history
			assert(history[-2].message == "Feebas used Splash.")
			assert(history[-1].message == "It did nothing.")
		Helper.complete(main)
		assert(not main.resolving_turn and not enemy.attack_resolution_pending)
		assert(main.player.health.current == hp - PokemonDamage.move_damage(state, main.player.battle_state, move))
		# Basic choice at range pursues; adjacent choice attacks with no PP spent.
		enemy.attack_rng.seed = choice_seed(PROBABILITIES[index], false)
		var previous := enemy.grid_position
		main.player.basic_attack()
		Helper._complete_leap(main.player.attack_leap)
		if index == 2: assert(enemy.character_visual.clip == "Attack")
		else: assert(enemy.grid_position != previous)
		Helper.complete(main)
		assert(state.remaining_pp[0] == pp - 1)
		if index == 1:
			state.remaining_pp[0] = 0
			previous = enemy.grid_position
			main.player.basic_attack()
			Helper.complete(main)
			assert(enemy.grid_position != previous and state.remaining_pp[0] == 0)
		if index == 3:
			validate_dragon_lane(main, enemy, move)
		main.free()
	await process_frame
	print("PASS: four level10 encounter species/stats/types/native clips, seeded move/basic policies, Bullet Seed single-hit power5/20PP/four-tile data and flight/sparks, ranged Splash no-op/PP/dialogue, Dragon Breath two-tile blocking/delayed damage/cancellation")
	quit()

func validate_dragon_lane(main: Node3D, enemy: Skeleton, move: PokemonMoveData) -> void:
	assert(move.move_type == "Dragon" and move.power == 6 and move.category == PokemonMoveData.Category.SPECIAL and move.range_tiles == 2)
	enemy.grid_position = Vector2i(2,0)
	var player_block := func(tile: Vector2i): return tile == Vector2i.ZERO
	assert(not enemy.projectile_plan(move, Vector2i.ZERO, player_block).is_empty())
	assert(enemy.projectile_plan(move, Vector2i.ZERO, func(tile: Vector2i): return tile in [Vector2i.ZERO,Vector2i(1,0)]).is_empty())
	enemy.grid_position = Vector2i(3,0)
	assert(enemy.projectile_plan(move, Vector2i.ZERO, player_block).is_empty())
	enemy.grid_position = Vector2i(2,0)
	main.dungeon.set_tile(Vector2i(1,0), DungeonData.TileType.WALL)
	assert(enemy.projectile_plan(move, Vector2i.ZERO, player_block).is_empty())
	main.dungeon.set_tile(Vector2i(1,0), DungeonData.TileType.FLOOR)
	enemy.setup(Vector2i(2,0), main.dungeon, main.dungeon_renderer)
	main.enemy_occupancy = {enemy.grid_position:enemy}
	enemy.attack_rng.seed = choice_seed(0.35,true)
	var hp: int = main.player.health.current
	main.player.basic_attack()
	Helper._complete_leap(main.player.attack_leap)
	var effect: ProjectileEffect
	for child in main.entities.get_children():
		if child is ProjectileEffect: effect = child
	assert(effect != null and effect.dragon_breath)
	assert(effect.sprite.texture == ProjectileEffect.DRAGON_BREATH_TEXTURE)
	var camera: Camera3D = main.presentation_camera
	var projected_length := Vector2(effect.flight_direction.dot(camera.global_basis.x), effect.flight_direction.dot(camera.global_basis.y)).length()
	assert(is_equal_approx(effect.sprite.pixel_size, projected_length / 170.0 * 3.0))
	effect.animation.pause()
	var origin := effect.breath_origin
	effect.animation.custom_step(enemy.character_visual.projectile_release_time() + 0.15)
	assert(effect.sprite.global_position.is_equal_approx(origin))
	effect._set_sheet_time(effect.breath_duration)
	var cutoff: float = effect.sheet_material.get_shader_parameter("cutoff_x")
	var visible_length := (cutoff * 184.0 - 12.0) * effect.sprite.pixel_size
	assert(is_equal_approx(visible_length, projected_length))
	assert(effect.flight_direction.length() <= 2.0)
	assert(main.player.health.current == hp)
	main.cancel_round()
	assert(not enemy.attack_resolution_pending and main.player.health.current == hp)
