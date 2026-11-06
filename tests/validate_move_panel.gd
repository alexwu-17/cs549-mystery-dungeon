extends SceneTree

const DisplayData = preload("res://scripts/ui/move_display_data.gd")


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	var hud = load("res://scenes/ui/player_hud.tscn").instantiate()
	root.add_child(hud)
	hud.get_node("Screen/FloorIntroduction").hide()
	var panel = hud.move_panel
	assert(panel.rows.size() == 4 and not panel.details.visible)
	for index in range(4):
		assert(panel.rows[index].get_child(0).text == ["🆄", "🅸", "🅾", "🅿"][index])
	# Synthetic display fixture: this does not teach a move to the player.
	var move := DisplayData.new()
	move.move_name = "Ember"
	move.attribute_name = "Fire"
	move.category = "Special"
	move.current_pp = 7
	move.maximum_pp = 10
	move.damage_text = "Power: 40"
	move.description = "Travels up to four tiles forward. Stops at the first wall or enemy; hits one enemy once."
	var entries: Array[DisplayData] = [move]
	panel.set_moves(entries)
	await process_frame
	assert(panel.rows[0].get_child(0).text == "🆄")
	assert(panel.rows[0].get_child(1) is TextureRect)
	assert(panel.rows[0].get_child(2).text == "Ember")
	assert(panel.rows[0].get_child(3).text == "7/10")
	panel.rows[0].mouse_entered.emit()
	await process_frame
	assert(panel.details.visible)
	assert(panel.detail_body.get_child(0).text == "Ember")
	assert(panel.detail_body.get_child(2).text == "Power: 40")
	assert(panel.detail_body.get_child(3).text == move.description)
	assert(panel.details.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(panel.rows[0].mouse_filter == Control.MOUSE_FILTER_PASS)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://.godot/move-panel-preview.png")
	move.current_pp = 0
	panel.set_moves(entries)
	assert(panel.rows[0].get_child(3).text == "0/10")
	assert(move.current_pp == 0)
	panel.rows[0].mouse_exited.emit()
	assert(not panel.details.visible)
	panel.rows[3].mouse_entered.emit()
	assert(not panel.details.visible)
	panel.rows[0].mouse_entered.emit()
	panel.hide()
	assert(not panel.details.visible)
	panel.show()
	var empty: Array[DisplayData] = []
	panel.set_moves(empty)
	assert(panel.rows.size() == 4 and not panel.details.visible)
	hud.free()
	await process_frame
	print("PASS: four move slots, icons, PP refresh, hover details, empty slots and hidden-panel cleanup")
	quit()
