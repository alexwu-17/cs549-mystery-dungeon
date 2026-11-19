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
			assert(tutorial.enemies[0].species_data.species_id == &"psyduck")
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
			assert(tutorial.player.battle_state.moves[2].move_id == &"ember")
			tutorial.player.facing = Vector2i.UP
			press(KEY_O)
			assert(not tutorial.resolving_turn and tutorial.player.battle_state.remaining_pp[2] == 20)
			tutorial.player.facing = Vector2i.RIGHT
			press(KEY_O)
			Helper.complete(tutorial)
			assert(tutorial.enemies[0].grid_position == Vector2i(14, 17))
			assert(tutorial.enemies[0].health.current == tutorial.enemies[0].health.maximum)
			assert(controller.modal.messages.size() == 4)
			assert(controller.modal.messages[0].begins_with("There are also status moves"))
			assert(controller.modal.messages[2].begins_with("Pokemon and moves have types, which have strengths"))
			acknowledge(controller)
			assert(controller.stage == &"combat")
			while tutorial.enemies.size() > 0:
				tutorial.player.basic_attack()
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
	print("PASS: tutorial choice and both startup paths")
	quit()
