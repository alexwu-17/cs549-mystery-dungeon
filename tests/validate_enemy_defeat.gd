extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	var data := DungeonData.new()
	for x in range(5): data.set_tile(Vector2i(x,0),DungeonData.TileType.FLOOR)
	renderer.render_dungeon(data)
	var enemy = load("res://scenes/enemies/test_enemy.tscn").instantiate()
	root.add_child(enemy)
	enemy.setup(Vector2i.RIGHT,data,renderer)
	var visual = enemy.character_visual
	assert(visual.clips.has("Faint"))
	assert(is_equal_approx(visual.clips.Faint.total,34.0/60.0))
	var done := [0]
	visual.defeat_finished.connect(func(): done[0] += 1)
	enemy.attack_leap.play(Vector2i.LEFT)
	enemy.receive_damage(6)
	assert(enemy.health.current == 0 and not enemy.attack_leap.active and visual.defeating)
	assert(visual.clip == "Faint" and visual.action == "Defeat" and visual.frame_index == 0)
	assert(visual.sprite.texture.atlas.resource_path.ends_with("/Faint-Anim.png"))
	visual.defeat_animation.pause()
	visual.action_speed = 3.0
	visual.defeat_animation.custom_step(0.07501)
	assert(not visual.sprite.visible and visual.frame_index == 0)
	visual.defeat_animation.custom_step(0.075)
	assert(visual.sprite.visible and visual.frame_index == 1)
	var position_before: Vector3 = enemy.position
	enemy.take_turn(Vector2i.ZERO,{})
	visual.walk()
	visual.attack()
	visual.standing()
	assert(enemy.position == position_before and visual.action == "Defeat")
	enemy.hide()
	visual._sample_defeat(0.3)
	assert(not visual.sprite.is_visible_in_tree()) # Blink cannot reveal a fog-hidden parent.
	enemy.show()
	visual.defeat_animation.custom_step(0.6498)
	assert(visual.defeating and visual.frame_index == 3 and done[0] == 0)
	visual.defeat_animation.custom_step(0.001)
	assert(not visual.defeating and visual.defeat_completed and not visual.sprite.visible and done[0] == 1)
	visual.finish_defeat()
	assert(done[0] == 1)
	enemy.setup(Vector2i.RIGHT,data,renderer)
	assert(visual.sprite.visible and not visual.defeating and not visual.frozen)
	enemy.free()
	renderer.free()

	# Live bookkeeping and healing are immediate; only the old actor's visual lingers.
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i.RIGHT]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
	main.player.health.reset(20)
	main.player.health.damage(5)
	main.player.facing = Vector2i.RIGHT
	enemy = main.enemies[0]
	enemy.health.reset(3)
	main.player.basic_attack()
	assert(main.enemies.is_empty() and main.enemy_occupancy.is_empty() and main.player.health.current == 18)
	assert(main.retiring_enemies.size() == 1 and enemy.is_inside_tree() and enemy.character_visual.defeating)
	assert(not main.is_enemy_occupied(Vector2i.RIGHT))
	var old_enemy: WeakRef = weakref(enemy)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(old_enemy.get_ref() == null and main.retiring_enemies.is_empty())

	# Drapion falls back to the last Hurt frame; completion UI waits for disappearance.
	main.floor_number = 5
	main.load_test_floor()
	Helper.complete_introduction(main)
	var boss: Minotaur = main.boss
	visual = boss.character_visual
	assert(not visual.clips.has("Faint"))
	main.player.setup(Vector2i(13,11),main.dungeon,main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	boss.health.reset(3)
	main.player.basic_attack()
	assert(main.victory and not main.player.gameplay_enabled and visual.defeating)
	assert(main.player.attack_leap.active) # Finishing attack is not cut short.
	main.player.attack_leap.finish()
	assert(not main.hud.get_node("Screen/GameOver").visible)
	assert(visual.clip == "Hurt" and visual.frame_index == visual.clips.Hurt.durations.size()-1)
	visual.defeat_animation.pause()
	visual.defeat_animation.custom_step(0.07501)
	assert(not visual.sprite.visible and not main.hud.get_node("Screen/GameOver").visible)
	visual.defeat_animation.custom_step(0.075)
	assert(visual.sprite.visible and visual.frame_index == 1)
	visual.defeat_animation.custom_step(0.65)
	assert(not boss.visible and visual.defeat_completed and main.hud.get_node("Screen/GameOver").visible)
	assert(main.hud.get_node("Screen/GameOver/Center/Text/Title").text == "Demo Complete")

	# A longer finishing attack is also allowed to complete before the overlay.
	main.start_new_run()
	Helper.complete_introduction(main)
	main.floor_number = 5
	main.load_test_floor()
	Helper.complete_introduction(main)
	boss = main.boss
	main.player.setup(Vector2i(13,11),main.dungeon,main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	main.player.attack_leap.duration = 1.2
	boss.health.reset(3)
	main.player.basic_attack()
	boss.character_visual.finish_defeat()
	assert(not main.hud.get_node("Screen/GameOver").visible and main.player.attack_leap.active)
	main.player.attack_leap.finish()
	assert(main.hud.get_node("Screen/GameOver").visible)
	main.player.attack_leap.duration = float(main.player.character_visual.clips.Attack.total)

	# Restart during a blinking boss must not show a stale Demo Complete overlay.
	main.start_new_run()
	Helper.complete_introduction(main)
	main.floor_number = 5
	main.load_test_floor()
	Helper.complete_introduction(main)
	boss = main.boss
	main.player.setup(Vector2i(13,11),main.dungeon,main.dungeon_renderer)
	main.player.facing = Vector2i.UP
	boss.health.reset(3)
	main.player.basic_attack()
	assert(boss.character_visual.defeating)
	var old_boss: WeakRef = weakref(boss)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(old_boss.get_ref() == null and not main.victory and not main.hud.get_node("Screen/GameOver").visible)
	main.free()
	await process_frame
	print("PASS: native Faint auto-discovery/timing, unscaled blink/hide, Hurt-last fallback, no dead turns/occupancy, immediate healing, fog-safe visibility, delayed Demo Complete and reset cancellation")
	quit()
