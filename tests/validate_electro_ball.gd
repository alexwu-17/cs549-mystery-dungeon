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
	for name in ["pikachu"]:
		var main = load("res://scenes/main/main.tscn").instantiate()
		main.use_elevation_test = true
		main.elemental_move_floor = 1
		main.get_node("Player").species_data = load("res://config/species/%s.tres" % name)
		main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % name)
		root.add_child(main)
		Helper.complete_introduction(main)
		if main.awaiting_move_ack: main.acknowledge_move()
		var state: PokemonBattleState = main.player.battle_state
		var move: PokemonMoveData = state.moves[2]
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
			assert(not main.player.use_move(slot))
			var release: float = main.player.character_visual.projectile_release_time()
			var target_position := enemy.grid_position
			effect.animation.pause()
			main.player.attack_leap.finish()
			assert(main.resolving_turn and main.player.round_locked and enemy.grid_position == target_position)
			effect.animation.custom_step(release + distance * ProjectileEffect.SECONDS_PER_TILE * 0.5 - 0.001)
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
		main.free()
		await process_frame
	print("PASS: Electro Ball release/travel/impact, damage, PP, turn locks, cancellation and misses")
	quit()
