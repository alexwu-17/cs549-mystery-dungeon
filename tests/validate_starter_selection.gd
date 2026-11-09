extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")


func _initialize() -> void:
	call_deferred("validate")


func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://.godot/starter-%s.png" % name)


func validate() -> void:
	root.size = Vector2i(1920, 1080)
	# Exercise SceneTree's actual scene launch path, not only manual instantiation.
	assert(change_scene_to_file("res://scenes/main/demo_main.tscn") == OK)
	for iteration in range(10):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/demo_start.tscn":
			break
	assert(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/demo_start.tscn")
	var launched = current_scene
	assert(launched.choosing and launched.gameplay == null)
	launched.start_starter(1)
	Helper.complete_introduction(launched.gameplay)
	assert(launched.gameplay.player.species_data.species_id == &"piplup")
	assert(launched.gameplay.dungeon != null)
	launched.free()
	await process_frame
	for index in range(3):
		var entry = load("res://scenes/ui/demo_start.tscn").instantiate()
		var configured_track: AudioStreamOggVorbis = entry.menu_music
		assert(configured_track.resource_path == "res://assets/audio/music/character_select_menu.ogg")
		assert(configured_track.loop and is_zero_approx(configured_track.loop_offset))
		# Retain coverage of the optional silent-menu configuration.
		if index == 2:
			entry.menu_music = null
		root.add_child(entry)
		assert(entry.choosing and entry.gameplay == null)
		await process_frame
		var cards = entry.menu.get_child(0).get_child(1)
		var baseline: float = cards.get_child(0).get_child(0).get_child(0).get_global_rect().end.y
		for card in cards.get_children():
			var portrait: Control = card.get_child(0).get_child(0)
			assert(is_equal_approx(portrait.size.y, 96.0))
			assert(is_equal_approx(portrait.get_global_rect().end.y, baseline))
		# Physical A/D navigate without starting gameplay; wrap at both ends.
		var key := InputEventKey.new()
		key.pressed = true
		key.physical_keycode = KEY_A
		root.push_input(key, true)
		assert(entry.focused_index == 2 and entry.choices[2].has_focus())
		key.physical_keycode = KEY_D
		root.push_input(key, true)
		assert(entry.focused_index == 0 and entry.choices[0].has_focus())
		var hover := InputEventMouseMotion.new()
		hover.position = cards.get_child(1).get_global_rect().position + Vector2(115, 90)
		root.push_input(hover, true)
		await process_frame
		assert(entry.focused_index == 1 and entry.gameplay == null)
		for slot in range(3):
			assert(entry.portraits[slot].walking == (slot == 1))
		var preview = entry.portraits[1]
		preview.set_process(false)
		var rect: Rect2 = preview.get_global_rect()
		preview._process(float(preview.clips.Walk.durations[0]) + 0.00001)
		assert(preview.frame_index == 1 and preview.get_global_rect() == rect)
		entry.choices[2].grab_focus()
		assert(not preview.walking and preview.frame_index == 0)
		assert(entry.portraits[2].walking)
		if index < 2:
			assert(entry.get_node("MenuMusic").playing)
			assert(entry.get_node("MenuMusic").stream == configured_track)
			entry.get_node("MenuMusic").stop()
			entry.get_node("MenuMusic").finished.emit()
			assert(entry.get_node("MenuMusic").playing)
		else:
			assert(not entry.get_node("MenuMusic").playing)
		# Launch goes directly to selection; no Start screen or function-key binding.
		if index == 0:
			await capture("selection")
		entry.choices[index].grab_focus()
		var confirm := InputEventKey.new()
		confirm.keycode = KEY_ENTER
		confirm.pressed = true
		root.push_input(confirm, true)
		confirm.pressed = false
		root.push_input(confirm, true)
		assert(not entry.get_node("MenuMusic").playing and entry.get_node("MenuMusic").stream == null)
		entry.get_node("MenuMusic").finished.emit()
		assert(not entry.get_node("MenuMusic").playing)
		var main = entry.gameplay
		Helper.complete_introduction(main)
		assert(main.game_mode == GameModeConfig.Mode.DEMO and main.floor_number == 1)
		assert(not entry.menu.visible and not entry.get_node("Background").visible)
		var player = main.player
		var visual = player.character_visual
		var species: PokemonSpeciesData = entry.SPECIES[index]
		assert(player.species_data == species and player.level == 20)
		assert(player.battle_state.moves[0].move_id == [&"scratch", &"pound", &"tackle"][index])
		assert(player.battle_state.remaining_pp == [[28, 27], [27, 20], [30, 16]][index])
		assert(main.hud.move_panel.moves[0].move_name == ["Scratch", "Pound", "Tackle"][index])
		assert(player.health.current == species.maximum_hp)
		assert(main.hud.hp_bar.max_value == species.maximum_hp)
		assert(main._player_display_name() == species.display_name)
		assert(visual.profile == entry.PROFILES[index])
		assert(visual.profile.pixel_size == 0.04 and visual.profile.body_to_ground == 8.0)
		assert(not player.attack_leap.procedural_motion)
		assert(is_equal_approx(player.attack_leap.duration, visual.clips.Attack.total))
		visual.set_process(false)
		var reference: Vector2 = visual.ground_reference
		# Exercise every native frame and cardinal row, preserving authored offsets.
		for direction in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
			visual.face(direction)
			for clip in ["Idle", "Walk", "Attack", "Hurt"]:
				assert(visual.clips.has(clip))
				visual.play_clip(clip, true)
				var info: Dictionary = visual.clips[clip]
				var elapsed: float = 0.0
				for frame in range(info.durations.size()):
					visual.clip_time = elapsed + 0.000001
					visual.frame_index = -1
					visual.apply_frame()
					assert(visual.frame_index == frame)
					assert(visual.sprite.texture == info.rows[visual.row()][frame].texture)
					assert(visual.ground_reference == reference)
					assert(not visual.sprite.flip_h and not visual.sprite.flip_v)
					assert(visual.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
					elapsed += float(info.durations[frame])
				if index > 0 and "--capture" in OS.get_cmdline_user_args():
					visual.clip_time = float(info.total) * 0.5
					visual.frame_index = -1
					visual.apply_frame()
					await capture("%s-%s-%d" % [species.species_id, clip, visual.row()])
		visual.cancel()
		visual.face(Vector2i.DOWN)
		await capture(species.species_id)
		# Drive the selected species through a real shared combat round.
		main.use_elevation_test = true
		main.load_test_floor()
		Helper.complete_introduction(main)
		var start: Vector2i = player.grid_position
		player.try_move(Vector2i.RIGHT)
		Helper.complete(main)
		assert(player.grid_position == start + Vector2i.RIGHT)
		var enemy: Skeleton = main.enemies[0]
		player.setup(enemy.grid_position - Vector2i.RIGHT, main.dungeon, main.dungeon_renderer)
		player.facing = Vector2i.RIGHT
		var enemy_hp: int = enemy.health.current
		player.basic_attack()
		assert(player.attack_leap.active and visual.action == "Attack")
		Helper.complete(main)
		assert(enemy.health.current == enemy_hp - [17, 17, 18][index])
		assert(not main.resolving_turn and visual.action == "Hurt")
		visual._process(float(visual.clips.Hurt.total) + 0.001)
		assert(visual.action == "Idle")
		player.health.reset(species.maximum_hp)
		var identity: EntityHealth = player.health
		player.health.damage(5)
		main._on_stairs_reached()
		Helper.complete_introduction(main)
		assert(main.floor_number == 2 and player.health.current == species.maximum_hp - 5)
		assert(visual.profile == entry.PROFILES[index])
		# Restart during an active presentation/introduction must retain the choice.
		player.attack_leap.play(Vector2i.DOWN)
		main.start_new_run()
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(player.health == identity and player.health.current == species.maximum_hp)
		assert(player.species_data == species and visual.profile == entry.PROFILES[index])
		assert(not player.attack_leap.active and not player.transition_locked)
		player.receive_damage(999)
		assert(main.game_over)
		var restart := InputEventKey.new()
		restart.physical_keycode = KEY_R
		restart.pressed = true
		main._unhandled_input(restart)
		Helper.complete_introduction(main)
		assert(not main.game_over and player.health.current == species.maximum_hp)
		assert(visual.profile == entry.PROFILES[index])
		entry.start_starter((index + 1) % 3)
		assert(entry.gameplay == main)
		entry.free()
		await process_frame
	print("PASS: direct startup selection, three starter buttons, native cardinal frames/timing, species/HUD/names, floor persistence and restart cancellation")
	quit()
