extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	var dialogue: CombatDialogue = main.dialogue
	assert(dialogue.history.is_empty() and not dialogue.panel.visible)
	assert(dialogue.text.scroll_active == false and dialogue.visible_lines == 3)
	dialogue.append_event(&"charging")
	assert(dialogue.panel.visible and is_equal_approx(dialogue.timer.wait_time, 4.0))
	var remaining := dialogue.timer.time_left
	dialogue.end_round()
	assert(dialogue.history[-1].type == &"separator")
	assert(dialogue.timer.time_left == remaining)
	dialogue.timer.timeout.emit()
	assert(not dialogue.panel.visible)
	dialogue.end_round()
	assert(not dialogue.panel.visible)
	# Preserve full messages while selecting shaped lines at different widths.
	var long_name := "A very long combatant name with many words ".repeat(10)
	dialogue.append_event(&"attack", {"actor": long_name, "target": "Skeleton", "amount": 3})
	var full_message: String = dialogue.history[-1].message
	# Standalone resizing is intentional; remove inherited full-screen anchors.
	dialogue.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for width in [640, 360, 900]:
		dialogue.size = Vector2(width, 500)
		await process_frame
		await process_frame
		dialogue.refresh_window()
		assert(dialogue.text.get_line_count() > 3)
		var first := dialogue.text.get_line_count() - 3
		assert(is_equal_approx(dialogue.text.get_v_scroll_bar().value, dialogue.text.get_line_offset(first)))
		assert(dialogue.history[-1].message == full_message)
		assert(dialogue.text.size.y < 3 * (dialogue.text.get_line_offset(first + 1) - dialogue.text.get_line_offset(first)))
		print("LINE WINDOW width=", width, " lines=", dialogue.text.get_line_count(), " offset=", dialogue.text.get_v_scroll_bar().value, " height=", dialogue.text.size.y)
	dialogue.history_limit = 5
	for index in range(10):
		dialogue.append_event(&"heal", {"amount": index + 1})
	assert(dialogue.history.size() == 5 and dialogue.history[-1].sequence > 5)
	# Floor changes also preserve a currently running inactivity timer.
	var active_remaining := dialogue.timer.time_left
	main.load_test_floor()
	assert(dialogue.timer.time_left == active_remaining and dialogue.panel.visible)
	# Floor changes neither clear history nor activate hidden dialogue/timers.
	dialogue.timer.stop()
	dialogue.timer.timeout.emit()
	var count := dialogue.history.size()
	main.load_test_floor()
	assert(dialogue.history.size() == count and not dialogue.panel.visible and dialogue.timer.is_stopped())
	main.start_new_run()
	assert(dialogue.history.is_empty() and not dialogue.panel.visible)
	# A silent player action and silent round produce no entries or timer.
	main.dungeon.enemy_spawns.clear()
	main.spawn_test_enemies()
	main.player.facing = Vector2i.UP
	main.player.basic_attack()
	Helper.complete(main)
	assert(dialogue.history.is_empty() and dialogue.timer.is_stopped())
	# Integration: damage precedes death/healing and enemy damage follows the leap.
	var data := DungeonData.new()
	data.set_tile(Vector2i.ZERO, DungeonData.TileType.FLOOR)
	data.set_tile(Vector2i.RIGHT, DungeonData.TileType.FLOOR)
	data.enemy_spawns = [Vector2i.RIGHT]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.player.facing = Vector2i.RIGHT
	main.player.basic_attack()
	assert(dialogue.history.size() == 1 and dialogue.history[0].message.begins_with("Swordsman attacks"))
	Helper.complete(main)
	assert(dialogue.history[1].message.begins_with("Skeleton attacks") and dialogue.history[-1].type == &"separator")
	main.player.basic_attack()
	Helper.complete(main)
	assert(dialogue.history[-3].type == &"defeat" and dialogue.history[-2].type == &"heal" and dialogue.history[-1].type == &"separator")
	main.free()
	await process_frame
	print("PASS: dialogue line window/wrapping/resize, history, timer/separators, silent actions, lifecycle and combat order")
	quit()
