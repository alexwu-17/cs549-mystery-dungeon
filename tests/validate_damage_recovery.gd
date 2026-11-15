extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(6): data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	data.enemy_spawns.append(Vector2i(3, 0))
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	main.refresh_fog()
	var enemy = main.enemies[0]
	var visual = enemy.character_visual
	visual.action_speed = 4.0
	enemy.receive_damage(1)
	assert(visual.damage_recovering and visual.action == "Hurt")
	visual.hurt_flash.pause()
	visual.hurt_flash.custom_step(visual.profile.defeat_blink_interval + 0.001)
	assert(not visual.sprite.visible)
	visual.damage_recovery.pause()
	visual._process(0.6)
	assert(visual.action == "Hurt") # Authored clip ended, but reaction is held.
	main.run_enemy_turn()
	assert(main.resolving_turn and main.player.round_locked and enemy.grid_position == Vector2i(3, 0))
	visual.damage_recovery.custom_step(0.249)
	assert(visual.damage_recovering and enemy.grid_position == Vector2i(3, 0))
	visual.damage_recovery.custom_step(0.002)
	assert(visual.action == "Idle" and visual.damage_recovering and enemy.grid_position == Vector2i(3, 0))
	assert(visual.sprite.visible and not visual.hurt_flash.is_running())
	visual.damage_recovery.custom_step(0.248)
	assert(visual.action == "Idle" and enemy.grid_position == Vector2i(3, 0))
	visual.damage_recovery.custom_step(0.002)
	assert(not visual.damage_recovering and enemy.grid_position == Vector2i(2, 0))
	Helper.complete(main)
	assert(not main.resolving_turn)
	# Another hit resets the full real-time delay rather than waking the waiter.
	enemy.receive_damage(1)
	visual.damage_recovery.pause()
	main.run_enemy_turn()
	visual.damage_recovery.custom_step(0.3)
	assert(visual.action == "Idle")
	enemy.receive_damage(1)
	assert(visual.action == "Hurt" and visual.damage_hurt_phase)
	assert(visual.sprite.visible)
	visual.damage_recovery.pause()
	visual.damage_recovery.custom_step(0.499)
	assert(enemy.grid_position == Vector2i(2, 0) and visual.damage_recovering)
	# Cancel while Main is awaiting recovery: no stale enemy movement/unlock.
	main.cancel_round()
	assert(not visual.damage_recovering and not main.resolving_turn and not main.player.round_locked)
	assert(visual.sprite.visible and not visual.hurt_flash.is_running())
	assert(enemy.grid_position == Vector2i(2, 0))
	# Uninjured enemies do not incur the recovery delay.
	main.run_enemy_turn()
	assert(enemy.grid_position == Vector2i(1, 0))
	Helper.complete(main)
	# Player Hurt also flashes, without adding a player recovery hold.
	var player_visual = main.player.character_visual
	player_visual.hurt()
	assert(not player_visual.damage_recovering and player_visual.hurt_flash != null)
	player_visual.hurt_flash.pause()
	player_visual.hurt_flash.custom_step(player_visual.profile.defeat_blink_interval + 0.001)
	assert(not player_visual.sprite.visible)
	player_visual.cancel()
	assert(player_visual.sprite.visible and not player_visual.hurt_flash.is_running())
	main.free()
	await process_frame
	print("PASS: damage-only0.25s Hurt then0.25s Idle, fast-speed timing, repeated-hit reset, cancellation and no added pause on uninjured turns")
	quit()
