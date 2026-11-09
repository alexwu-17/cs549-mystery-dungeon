extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	root.size = Vector2i(1920, 1080)
	# Health owns the actual clamped loss; resets/healing/invalid hits emit no damage.
	var health := EntityHealth.new()
	var losses: Array[int] = []
	health.damaged.connect(func(amount: int): losses.append(amount))
	health.reset(9)
	health.damage(0)
	health.damage(-1)
	health.damage(3)
	assert(losses == [3])
	health.heal(2)
	health.damage(100)
	health.damage(4)
	assert(losses == [3, 8])
	health.reset(20)
	assert(losses == [3, 8])
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	var feedback: DamageNumbers = main.hud.damage_numbers
	var player: Player = main.player
	assert(feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(feedback.popups.is_empty() and not feedback.is_processing())
	# Repeated bindings must not create duplicate damage text.
	feedback.watch(player, player.character_visual, player.health)
	player.receive_damage(9)
	feedback.set_process(false)
	assert(feedback.popups.size() == 1)
	var label: Label = feedback.popups[0].label
	assert(label.text == "-9" and label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var start := label.position
	feedback._process(DamageNumbers.LIFETIME / 2.0)
	feedback.set_process(false)
	assert(is_equal_approx(label.modulate.a, 0.5))
	assert(is_equal_approx(label.position.y, start.y - DamageNumbers.RISE / 2.0))
	player.health.heal(2)
	assert(feedback.popups.size() == 1)
	feedback._process(DamageNumbers.LIFETIME)
	assert(feedback.popups.is_empty() and not feedback.is_processing())
	player.invincible = true
	player.receive_damage(9)
	player.invincible = false
	assert(feedback.popups.is_empty())
	# Fog-owned root visibility governs numbers; defeat's child blink does not.
	var enemy: Skeleton = main.enemies[0]
	enemy.visible = false
	enemy.receive_damage(2)
	assert(feedback.popups.is_empty())
	enemy.visible = true
	enemy.receive_damage(3)
	feedback.set_process(false)
	assert(feedback.popups.size() == 1 and feedback.popups[0].label.text == "-3")
	enemy.visible = false
	feedback._process(0.0)
	feedback.set_process(false)
	assert(not feedback.popups[0].label.visible)
	enemy.visible = true
	enemy.character_visual.sprite.hide()
	feedback._process(0.0)
	feedback.set_process(false)
	assert(feedback.popups[0].label.visible)
	enemy.character_visual.sprite.show()
	feedback.clear()
	enemy.health.reset(4)
	enemy.receive_damage(99)
	feedback.set_process(false)
	assert(feedback.popups.size() == 1 and feedback.popups[0].label.text == "-4")
	var damage_count := feedback.popups.size()
	enemy.receive_damage(2)
	assert(feedback.popups.size() == damage_count)
	# Camera projection follows actors, but the popup never changes an actor transform.
	var position := enemy.position
	feedback._process(0.1)
	feedback.set_process(false)
	assert(enemy.position == position)
	# Retiring actors can leave the tree before queue_free; avoid stale transforms.
	main.entities.remove_child(enemy)
	feedback._process(0.0)
	assert(feedback.popups.is_empty())
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(feedback.popups.is_empty())
	player.receive_damage(5)
	assert(feedback.popups.size() == 1)
	main._on_stairs_reached()
	Helper.complete_introduction(main)
	assert(main.floor_number == 2 and feedback.popups.is_empty())
	# Death remains nonblocking; the lethal actual loss still has a popup.
	player.health.reset(9)
	player.receive_damage(99)
	feedback.set_process(false)
	assert(main.game_over and feedback.popups.size() == 1 and feedback.popups[0].label.text == "-9")
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(not main.game_over and feedback.popups.is_empty())
	# Boss defeat's round cancellation must not erase its lethal damage text.
	main.game_mode = GameModeConfig.Mode.DEMO
	main.use_elevation_test = false
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	main.boss.visible = true
	main.boss.receive_damage(100)
	feedback.set_process(false)
	assert(main.victory and feedback.popups.size() == 1 and feedback.popups[0].label.text == "-30")
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(feedback.popups.is_empty() and not main.victory)
	main.free()
	await process_frame
	print("PASS: actual damage events, player/enemy/boss head numbers, rise/fade, zero/heal/invincibility, fog/blink and floor/restart/death/victory cleanup")
	quit()
