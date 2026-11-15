extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func hit(actor: Node3D) -> ProjectileImpactEffect:
	for child in actor.get_children():
		if child is ProjectileImpactEffect and not child.completed: return child
	return null

func validate() -> void:
	for species in ["chimchar", "piplup", "turtwig"]:
		var main = load("res://scenes/main/main.tscn").instantiate()
		main.use_elevation_test = true
		main.elemental_move_floor = 99
		main.get_node("Player").species_data = load("res://config/species/%s.tres" % species)
		main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % species)
		root.add_child(main)
		Helper.complete_introduction(main)
		main.cancel_round()
		var data := DungeonData.new()
		for x in range(3): data.set_tile(Vector2i(x,0),DungeonData.TileType.FLOOR)
		data.enemy_spawns.append(Vector2i.RIGHT)
		main.dungeon = data
		assert(main.dungeon_renderer.render_dungeon(data))
		main.spawn_test_enemies()
		main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
		main.player.facing = Vector2i.RIGHT
		main.refresh_fog()
		var enemy = main.enemies[0]
		enemy.health.reset(100)
		var state: PokemonBattleState = main.player.battle_state
		var move: PokemonMoveData = state.moves[0]
		var pp: int = state.remaining_pp[0]
		var expected := 100 - PokemonDamage.move_damage(state,enemy.battle_state,move)
		assert(main.player.use_move(0))
		var leap: AttackLeap = main.player.attack_leap
		var visual = main.player.character_visual
		var contact_frame: int = visual.profile.melee_contact_frames[str(visual.attack_action)]
		assert(contact_frame == (5 if species in ["chimchar","turtwig"] else 6))
		assert(enemy.health.current == 100 and hit(enemy) == null and main.player.round_locked)
		leap.animation.pause()
		leap.animation.custom_step(leap.contact_time - 0.001)
		assert(enemy.health.current == 100 and hit(enemy) == null)
		leap.animation.custom_step(0.002)
		assert(visual.frame_index == contact_frame and leap.active)
		var effect := hit(enemy)
		assert(effect != null and effect.sprite.texture == ProjectileImpactEffect.TEXTURES[move.move_id])
		if move.move_id == &"scratch":
			assert(enemy.health.current == 100)
			effect.animation.pause()
			effect.animation.custom_step(effect.duration + 0.001)
		assert(enemy.health.current == expected and state.remaining_pp[0] == pp-1)
		Helper.complete(main)
		assert(not main.resolving_turn)
		await process_frame
		if species == "chimchar":
			# Stunky Scratch also starts on its configured forward/contact pose.
			enemy.active_attack_move = load("res://config/moves/scratch.tres")
			enemy.character_visual.prepare_attack(&"Scratch")
			enemy.attack_leap.play(Vector2i.LEFT)
			var hp: int = main.player.health.current
			main._on_enemy_attack(1,enemy)
			enemy.attack_leap.animation.pause()
			enemy.attack_leap.animation.custom_step(enemy.attack_leap.contact_time-0.001)
			assert(main.player.health.current == hp and hit(main.player) == null)
			enemy.attack_leap.animation.custom_step(0.002)
			assert(enemy.character_visual.frame_index == 7 and hit(main.player) != null)
			assert(main.player.health.current == hp)
			hit(main.player).animation.pause()
			hit(main.player).animation.custom_step(1.0)
			assert(main.player.health.current < hp)
			enemy.attack_leap.finish()
			main.cancel_round()
			# Before-contact cancellation must not deal damage or unlock stale work.
			var previous: int = enemy.health.current
			assert(main.player.use_move(0))
			main.cancel_round()
			assert(enemy.health.current == previous and not main.resolving_turn and not main.player.round_locked)
			# The same protection applies after contact while swipes are playing.
			assert(main.player.use_move(0))
			main.player.attack_leap.animation.pause()
			main.player.attack_leap.animation.custom_step(main.player.attack_leap.contact_time+0.001)
			assert(hit(enemy) != null and enemy.health.current == previous)
			main.cancel_round()
			assert(enemy.health.current == previous and not main.resolving_turn and not main.player.round_locked)
		main.free()
		await process_frame
	print("PASS: Chimchar/Piplup/Turtwig/Stunky authored impact poses, no early effects/damage, star damage at contact, Scratch swipes before damage, PP/round locks and cancellation")
	quit()
