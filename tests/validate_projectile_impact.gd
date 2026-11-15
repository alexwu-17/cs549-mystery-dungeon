extends SceneTree
## Projectile release/travel gates damage, reactions and enemy turns.
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func make_lane(main: Node3D, distance: int) -> Skeleton:
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(7):
		data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	data.enemy_spawns.append(Vector2i(distance, 0))
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.player.facing = Vector2i.RIGHT
	main.refresh_fog()
	return main.enemies[0]

func shot(main: Node3D) -> ProjectileEffect:
	for child in main.entities.get_children():
		if child is ProjectileEffect and not child.flight_completed:
			return child
	return null

func hit_effects(actor: Node3D) -> Array[ProjectileImpactEffect]:
	var result: Array[ProjectileImpactEffect] = []
	for child in actor.get_children():
		if child is ProjectileImpactEffect and not child.is_queued_for_deletion(): result.append(child)
	return result

func validate() -> void:
	for name in ["chimchar", "piplup", "turtwig"]:
		var main = load("res://scenes/main/main.tscn").instantiate()
		main.use_elevation_test = true
		main.elemental_move_floor = 1
		main.get_node("Player").species_data = load("res://config/species/%s.tres" % name)
		main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % name)
		root.add_child(main)
		Helper.complete_introduction(main)
		var state: PokemonBattleState = main.player.battle_state
		var move: PokemonMoveData = state.species.floor_unlock_move
		var slot := state.moves.find(move)
		assert(slot >= 0)
		var rounds: Array[int] = [0]
		main.round_finished.connect(func(): rounds[0] += 1)
		for distance in [1, 4]:
			var enemy := make_lane(main, distance)
			var hp := enemy.health.current
			var expected := maxi(0, hp - PokemonDamage.move_damage(state, enemy.battle_state, move))
			var pp: int = state.remaining_pp[slot]
			var before_rounds := rounds[0]
			assert(main.player.use_move(slot))
			var effect := shot(main)
			assert(effect != null and main.resolving_turn and main.player.round_locked)
			assert(enemy.health.current == hp and state.remaining_pp[slot] == pp - 1)
			assert(hit_effects(enemy).is_empty())
			if move.move_id == &"ember":
				assert(effect.ember_light != null and not effect.ember_light.is_visible_in_tree())
				assert(not effect.ember_light.shadow_enabled and effect.ember_light.light_volumetric_fog_energy == 0.0)
				var discovered: Dictionary = main.dungeon.discovered_tiles.duplicate()
				var bright: Dictionary = main.dungeon.bright_tiles.duplicate()
				effect._set_ember_time(0.0)
				var start_energy: float = effect.ember_light.light_energy
				effect._set_ember_time(2.2 * ProjectileEffect.SECONDS_PER_TILE)
				assert(effect.ember_light.light_energy > start_energy and effect.ember_light.omni_range > DungeonData.TILE_SIZE)
				effect._set_ember_time(3.9 * ProjectileEffect.SECONDS_PER_TILE)
				assert(effect.ember_light.light_energy < start_energy)
				assert(main.dungeon.discovered_tiles == discovered and main.dungeon.bright_tiles == bright)
				effect._set_ember_time(0.0)
			assert(not main.player.use_move(slot))
			var release: float = main.player.character_visual.projectile_release_time()
			var target_position := enemy.grid_position
			effect.animation.pause()
			main.player.attack_leap.finish()
			assert(main.resolving_turn and main.player.round_locked and enemy.grid_position == target_position)
			effect.animation.custom_step(release + distance * ProjectileEffect.SECONDS_PER_TILE - 0.001)
			assert(enemy.health.current == hp and enemy.grid_position == target_position and rounds[0] == before_rounds)
			assert(hit_effects(enemy).is_empty())
			effect.animation.custom_step(0.002)
			assert(effect.flight_completed and enemy.health.current == hp)
			if effect.ember_light != null: assert(effect.ember_light.light_energy == 0.0)
			var hits := hit_effects(enemy)
			assert(hits.size() == 1 and hits[0].sprite.texture == ProjectileImpactEffect.TEXTURES[move.move_id])
			assert(hits[0].get_parent() == enemy and hits[0].sprite.no_depth_test)
			assert(hits[0].sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(not enemy.character_visual.damage_recovering and enemy.character_visual.action != "Hurt")
			if move.move_id == &"ember":
				assert(hits[0].frame_count == 118 and hits[0].sprite.hframes == 9 and hits[0].sprite.vframes == 14)
				assert(is_equal_approx(hits[0].sprite.pixel_size * 184.0, DungeonData.TILE_SIZE) and hits[0].duration == 0.5)
				var ground: Vector3 = main.dungeon_renderer.get_entity_world_position(enemy.grid_position)
				assert(hits[0].global_position.is_equal_approx(ground + Vector3.UP * ProjectileImpactEffect.EMBER_GROUND_CLEARANCE))
				assert(hits[0].sprite.offset == Vector2(0, 28))
				assert(hits[0].burst_sprite != null and hits[0].smoke_clouds.size() == 3)
				var body_sprite: Sprite3D = enemy.character_visual.sprite
				var body_bounds: Rect2i = body_sprite.texture.get_meta("pokemon_opaque_rect")
				var body_width := body_bounds.size.x * body_sprite.pixel_size * body_sprite.global_basis.x.length()
				assert(is_equal_approx(hits[0].burst_sprite.pixel_size * 90.0, maxf(0.2, body_width)))
				hits[0]._sample(1.0)
				for cloud in hits[0].smoke_clouds:
					assert(is_equal_approx(cloud.sprite.global_position.y - Vector3(cloud.origin).y, DungeonData.TILE_SIZE * 2.0))
				hits[0]._sample(0.0)
			elif move.move_id == &"razor_leaf":
				var target_body: Sprite3D = enemy.character_visual.sprite
				var target_bounds: Rect2i = target_body.texture.get_meta("pokemon_opaque_rect")
				var old_width := clampf(target_bounds.size.x * target_body.pixel_size * target_body.global_basis.x.length() * 1.05, 0.18, 0.8)
				assert(is_equal_approx(hits[0].sprite.pixel_size * 64.0, old_width * 2.0))
			hits[0].animation.pause()
			hits[0].animation.custom_step(hits[0].duration - 0.001)
			assert(not hits[0].is_queued_for_deletion() and hits[0].sprite.frame > 0)
			assert(enemy.health.current == hp and not enemy.character_visual.damage_recovering)
			hits[0].animation.custom_step(0.002)
			assert(hits[0].is_queued_for_deletion())
			assert(enemy.health.current == expected)
			if expected > 0: assert(enemy.character_visual.action == "Hurt" and enemy.character_visual.damage_hurt_phase)
			Helper.complete(main)
			assert(rounds[0] == before_rounds + 1 and not main.player.round_locked)
			await process_frame
		# Cancellation before arrival must not damage the old target or start a turn.
		var cancelled_enemy := make_lane(main, 4)
		var cancelled_hp := cancelled_enemy.health.current
		var before_cancel := rounds[0]
		assert(main.player.use_move(slot))
		var cancelled := shot(main)
		cancelled.animation.pause()
		cancelled.animation.custom_step(0.05)
		main.cancel_round()
		assert(cancelled.flight_completed and cancelled_enemy.health.current == cancelled_hp)
		assert(rounds[0] == before_cancel and not main.resolving_turn and not main.player.round_locked)
		await process_frame
		# Cancelling after arrival but during impact must also suppress damage.
		cancelled_enemy = make_lane(main, 3)
		cancelled_hp = cancelled_enemy.health.current
		assert(main.player.use_move(slot))
		Helper._complete_projectile(main)
		assert(hit_effects(cancelled_enemy).size() == 1 and cancelled_enemy.health.current == cancelled_hp)
		main.cancel_round()
		assert(hit_effects(cancelled_enemy).is_empty() and cancelled_enemy.health.current == cancelled_hp)
		assert(not main.resolving_turn and not main.player.round_locked)
		await process_frame
		# Misses also hold the enemy phase until travel completes.
		var missed_enemy := make_lane(main, 5)
		var missed_hp := missed_enemy.health.current
		assert(main.player.use_move(slot))
		var miss := shot(main)
		miss.animation.pause()
		main.player.attack_leap.finish()
		assert(missed_enemy.grid_position == Vector2i(5, 0) and main.resolving_turn)
		Helper.complete(main)
		assert(missed_enemy.health.current == missed_hp and not main.resolving_turn)
		assert(hit_effects(missed_enemy).is_empty())
		# Boss damage uses the same arrival gate, including lethal victory.
		main.game_mode = GameModeConfig.Mode.DEMO
		main.use_elevation_test = false
		main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
		main.load_test_floor()
		main.player.setup(main.boss.grid_position - Vector2i.RIGHT * 2, main.dungeon, main.dungeon_renderer)
		main.player.facing = Vector2i.RIGHT
		main.refresh_fog()
		var boss_hp: int = main.boss.health.current
		var boss_damage := PokemonDamage.move_damage(state, main.boss.battle_state, move)
		assert(main.player.use_move(slot) and main.boss.health.current == boss_hp)
		Helper._complete_projectile(main)
		assert(main.boss.health.current == boss_hp and hit_effects(main.boss).size() == 1)
		Helper.complete(main)
		assert(main.boss.health.current == maxi(0, boss_hp - boss_damage))
		assert(hit_effects(main.boss).is_empty())
		main.cancel_round()
		assert(hit_effects(main.boss).is_empty())
		main.boss.health.current = 1
		main.player.facing = Vector2i.RIGHT
		assert(main.player.use_move(slot) and not main.victory)
		Helper.complete(main)
		assert(main.boss.health.current == 0 and main.victory)
		assert(hit_effects(main.boss).is_empty())
		main.free()
		await process_frame
	print("PASS: impact before Hurt, ground-anchored Ember fire ring at one tile/0.5s, doubled Leaf size, turn locks, cancellation, misses, boss impacts and victory")
	quit()
