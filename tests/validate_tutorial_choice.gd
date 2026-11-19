extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")


func _initialize() -> void:
	call_deferred("validate")

func acknowledge(controller: Node) -> void:
	while is_instance_valid(controller.modal):
		var confirm := InputEventKey.new()
		confirm.keycode = KEY_ENTER
		confirm.pressed = true
		root.push_input(confirm, true)

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func validate() -> void:
	for wants_tutorial in [false, true]:
		var entry = load("res://scenes/ui/demo_start.tscn").instantiate()
		root.add_child(entry)
		assert(not entry.choosing and entry.gameplay == null)
		var column = entry.menu.get_child(0)
		assert(column.get_child(0).text == "Would you like a tutorial?")
		var options = column.get_child(1)
		assert(options.get_child(0).text == "Yes" and options.get_child(1).text == "No")
		options.get_child(0 if wants_tutorial else 1).pressed.emit()
		if wants_tutorial:
			var tutorial = entry.tutorial
			assert(not entry.choosing and entry.gameplay == null and tutorial != null)
			assert(tutorial.dungeon.rooms == [Rect2i(2, 14, 7, 7), Rect2i(13, 14, 7, 7), Rect2i(13, 3, 7, 7)])
			assert(tutorial.player.grid_position == Vector2i(5, 17))
			assert(tutorial.enemies.size() == 1 and tutorial.enemies[0].grid_position == Vector2i(16, 17))
			assert(tutorial.enemies[0].species_data.species_id == &"bidoof")
			var pikachu = tutorial.player.battle_state
			var bidoof = tutorial.enemies[0].battle_state
			assert(pikachu.species.species_id == &"pikachu" and pikachu.species.types == PackedStringArray(["Electric"]))
			assert([pikachu.health.maximum, pikachu.attack, pikachu.special_attack, pikachu.defense, pikachu.special_defense] == [98, 21, 21, 23, 18])
			assert([bidoof.health.maximum, bidoof.attack, bidoof.special_attack, bidoof.defense, bidoof.special_defense] == [48, 17, 17, 17, 17])
			assert(pikachu.moves[0].move_id == &"tackle" and pikachu.moves[1].move_id == &"growl")
			assert(bidoof.moves.size() == 1 and bidoof.moves[0].move_id == &"tackle")
			assert(tutorial.enemies[0].attack_policy.move_probability == 1.0)
			for actor in [tutorial.player, tutorial.enemies[0]]:
				for clip in ["Idle", "Walk", "Attack", "Hurt"]:
					assert(actor.character_visual.clips.has(clip))
			assert(tutorial.dungeon.stairs_position == Vector2i(16, 6))
			for tile in tutorial.dungeon.tiles:
				assert(tutorial.dungeon.get_elevation(tile) == 0)
			assert(not tutorial.floor_introduction.visible)
			assert(tutorial.floor_introduction.animation == null)
			assert(tutorial.player.transition_locked)
			var controller = tutorial.tutorial_controller
			var modal = controller.modal
			assert(modal.active and tutorial.dialogue.panel.visible and modal.arrow != null)
			assert(modal.messages.size() == 3 and modal.arrow.get_parent() == tutorial.dialogue)
			assert(modal.arrow.position == tutorial.dialogue.panel.position + tutorial.dialogue.panel.size - Vector2(32, 32))
			assert(tutorial.dialogue.text.get_theme_font_size("normal_font_size") == roundi(modal.original_font_size * 1.5))
			assert(tutorial.dialogue.text.visible_characters == 0)
			modal._process(0.1)
			assert(tutorial.dialogue.text.visible_characters > 0 and tutorial.dialogue.text.visible_characters < tutorial.dialogue.text.get_total_character_count())
			acknowledge(controller)
			assert(not tutorial.player.transition_locked)
			tutorial.player.grid_position = Vector2i(12, 17)
			tutorial.player.try_move(Vector2i.RIGHT)
			assert(controller.stage == &"encounter" and tutorial.player.transition_locked)
			assert(tutorial.enemies[0].grid_position == Vector2i(16, 17))
			acknowledge(controller)
			assert(controller.stage == &"basic")
			press(KEY_D)
			assert(tutorial.player.grid_position == Vector2i(13, 17) and not tutorial.resolving_turn)
			press(KEY_SPACE)
			Helper.complete(tutorial)
			assert(tutorial.enemies[0].grid_position == Vector2i(15, 17))
			assert(controller.modal.messages.size() == 8)
			assert(controller.modal.messages[6].begins_with("Some moves are projectiles"))
			assert("Try adjusting the direction" in controller.modal.messages[7])
			acknowledge(controller)
			assert(controller.stage == &"projectile")
			assert(tutorial.player.battle_state.moves[2].move_id == &"electro_ball")
			var ball = pikachu.moves[2]
			assert(ball.move_type == "Electric" and ball.category == PokemonMoveData.Category.SPECIAL and ball.power == 7 and ball.range_tiles == 4)
			tutorial.player.facing = Vector2i.UP
			press(KEY_O)
			assert(not tutorial.resolving_turn and tutorial.player.battle_state.remaining_pp[2] == 20)
			tutorial.player.facing = Vector2i.RIGHT
			press(KEY_O)
			Helper.complete(tutorial)
			assert(tutorial.enemies[0].grid_position == Vector2i(14, 17))
			assert(tutorial.enemies[0].health.current == tutorial.enemies[0].health.maximum - PokemonDamage.move_damage(pikachu, bidoof, ball))
			assert(controller.modal.messages.size() == 4)
			assert(controller.modal.messages[0].begins_with("There are also status moves"))
			assert(controller.modal.messages[2].begins_with("Pokemon and moves have types, which have strengths"))
			var restore_events: Array = []
			tutorial.enemies[0].health.damaged.connect(func(amount): restore_events.append(amount))
			var sequence_before_restore: int = tutorial.dialogue.sequence
			acknowledge(controller)
			assert(controller.stage == &"combat")
			assert(bidoof.health.current == bidoof.health.maximum and restore_events.is_empty())
			assert(tutorial.dialogue.sequence == sequence_before_restore)
			var enemy = tutorial.enemies[0]
			var hp: int = enemy.health.current
			var pp: int = pikachu.remaining_pp[2]
			assert(tutorial.player.use_move(2))
			assert(pikachu.remaining_pp[2] == pp - 1 and tutorial.player.character_visual.clip == "Shoot")
			var flight: ProjectileEffect
			for effect in tutorial.entities.get_children():
				if effect is ProjectileEffect and not effect.flight_completed: flight = effect
			assert(flight != null and is_equal_approx(flight.spirit_travel_duration, 0.1))
			assert(flight.sprite.texture == SpiritombFx.layout("electro_ball").texture)
			assert(enemy.health.current == hp and tutorial.player.round_locked)
			Helper._complete_projectile(tutorial)
			assert(enemy.health.current == hp)
			var impact: ProjectileImpactEffect
			for effect in enemy.get_children():
				if effect is ProjectileImpactEffect and not effect.completed: impact = effect
			assert(impact != null and impact.electric_sprite != null and impact.duration == 0.45)
			impact._sample(0.6)
			assert(impact.electric_sprite.visible and impact.electric_sprite.frame > 0)
			Helper.complete(tutorial)
			assert(enemy.health.current == hp - PokemonDamage.move_damage(pikachu, bidoof, ball))
			assert(bidoof.remaining_pp[0] == 29)
			assert(enemy.attack_policy == null)
			while tutorial.enemies.size() > 0:
				tutorial.player.use_move(2)
				Helper.complete(tutorial)
			assert(tutorial.player.health.current < tutorial.player.health.maximum)
			assert(controller.modal.messages.size() == 3)
			acknowledge(controller)
			assert(controller.stage == &"healing")
			while controller.stage == &"healing" and not is_instance_valid(controller.modal):
				tutorial.player.wait_turn()
				Helper.complete(tutorial)
			acknowledge(controller)
			assert(controller.stage == &"stairs")
			tutorial.player.grid_position = tutorial.dungeon.stairs_position + Vector2i.DOWN
			tutorial.player.try_move(Vector2i.UP)
			assert(tutorial.stairs_prompt != null)
			tutorial.stairs_prompt.choose(true)
			acknowledge(controller)
			await process_frame
			assert(entry.tutorial == null)
		assert(entry.choosing and entry.choices.size() == 3 and entry.gameplay == null)
		entry.start_starter(0)
		assert(entry.gameplay != null and not entry.choosing)
		var previous_game = entry.gameplay
		press(KEY_R)
		assert(previous_game.starter_selection_pending and previous_game.player.transition_locked)
		await process_frame
		assert(entry.gameplay == null and entry.choosing and entry.get_node("MenuMusic").playing)
		entry.start_starter(1)
		assert(entry.gameplay != null and entry.gameplay.player.species_data.species_id == &"piplup")
		entry.free()
		await process_frame
	# Tutorial guards, reset and repeated Space-only combat use the real round path.
	var entry = load("res://scenes/ui/demo_start.tscn").instantiate()
	root.add_child(entry)
	entry.show_tutorial()
	var tutorial = entry.tutorial
	var controller = tutorial.tutorial_controller
	acknowledge(controller)
	controller.stage = &"combat"
	tutorial.player.invincible = true
	for index in range(6):
		assert(tutorial.player.use_move(1))
		Helper.complete(tutorial)
		assert(controller.growl_uses == index + 1)
		assert(is_instance_valid(controller.modal) == (index == 5))
	assert(controller.modal.messages == ["Use damaging moves to wittle down the enemy's HP!"])
	acknowledge(controller)
	assert(tutorial.player.battle_state.remaining_pp[1] == 0)
	assert(not tutorial.player.use_move(1) and not tutorial.resolving_turn)
	tutorial.player.invincible = false
	tutorial.player.receive_damage(9999)
	assert(tutorial.game_over and not tutorial.player.gameplay_enabled)
	await process_frame
	assert(not tutorial.game_over and tutorial.player.health.current == 98)
	assert(tutorial.tutorial_controller != controller)
	controller = tutorial.tutorial_controller
	assert(controller.growl_uses == 0 and tutorial.player.battle_state.remaining_pp[1] == 20)
	assert(tutorial.enemies[0].attack_policy.move_probability == 1.0)
	assert(controller.modal.messages[0].begins_with("Welcome"))
	acknowledge(controller)
	controller.stage = &"combat"
	tutorial.player.setup(Vector2i(15, 17), tutorial.dungeon, tutorial.dungeon_renderer)
	tutorial.player.facing = Vector2i.RIGHT
	var bidoof = tutorial.enemies[0]
	var attacks: Array[StringName] = []
	bidoof.attack_requested.connect(func(_amount):
		attacks.append(bidoof.active_attack_move.move_id if bidoof.active_attack_move != null else &"basic")
	)
	for index in range(20):
		if tutorial.game_over or tutorial.enemies.is_empty(): break
		tutorial.player.basic_attack()
		Helper.complete(tutorial)
	assert(not tutorial.game_over and tutorial.enemies.is_empty())
	assert(attacks.size() > 1 and attacks[0] == &"tackle")
	for attack in attacks.slice(1): assert(attack == &"basic")
	assert(tutorial.player.health.current > 0)
	entry.free()
	await process_frame
	print("PASS: tutorial choice and both startup paths")
	quit()
