extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
func _initialize() -> void: call_deferred("validate")

func final_room(main: Node3D) -> FinalFloorSequence:
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	if main.awaiting_move_ack: main.acknowledge_move()
	main.player.health.reset(10000)
	main.player.setup(FinalFloorSequence.RECOVERY_TILE,main.dungeon,main.dungeon_renderer)
	main.player.try_move(Vector2i.UP)
	var sequence: FinalFloorSequence = main.final_floor_sequence
	sequence.camera_transition.pause()
	sequence.camera_transition.custom_step(1.0)
	return sequence

func validate() -> void:
	var arena := FinalFloorFactory.create_spiritomb_arena()
	assert(arena.tiles.size() == 81 and TestDungeonFactory.reachable_tiles(arena).size() == 81)
	for y in range(5,16):
		for x in range(8,19): assert(arena.is_walkable(Vector2i(x,y)) == Rect2i(9,6,9,9).has_point(Vector2i(x,y)))
	assert(arena.player_spawn == Vector2i(13,12) and FinalFloorFactory.SPIRITOMB_SPAWN == Vector2i(13,8))
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	var sequence := final_room(main)
	for y in range(14,9,-1):
		main.player.try_move(Vector2i.UP)
		Helper.complete(main)
	sequence.encounter_transition.pause()
	sequence.encounter_transition.custom_step(2.0)
	assert(main.enemies.size() == 4)
	main.player.battle_state.species = null
	main.player.attack_damage = 10000
	var music = root.get_node("MusicManager")
	for index in range(4):
		var enemy: Skeleton = main.enemies[0]
		for direction: Vector2i in DungeonData.CARDINALS:
			var neighbor := enemy.grid_position + direction
			if main.dungeon.can_traverse(neighbor,enemy.grid_position) and not main.is_enemy_occupied(neighbor):
				main.player.setup(neighbor,main.dungeon,main.dungeon_renderer)
				break
		if index == 3: main.player.round_locked = true # Finishing projectile/screen move lock.
		main._on_player_attack(enemy.grid_position)
		if index < 3:
			Helper.complete(main)
			assert(not is_instance_valid(sequence.spiritomb_reveal))
	var reveal: SpiritombReveal = sequence.spiritomb_reveal
	assert(reveal != null and main.player.transition_locked and not main.resolving_turn and not main.player.round_locked)
	assert(music.player.stream == null and main.enemies.is_empty())
	var hp: int = main.player.health.current
	var pp: Array[int] = main.player.battle_state.remaining_pp.duplicate()
	reveal.animation.pause()
	reveal.animation.custom_step(0.999)
	assert(reveal.phase == &"waiting")
	reveal.animation.custom_step(0.002)
	assert(reveal.phase == &"glitch" and reveal.effect.visible)
	reveal.animation.custom_step(0.8)
	assert(reveal.phase == &"black" and reveal.black.visible and reveal.cry.playing)
	assert(main.dungeon.tiles.size() == 81 and main.player.grid_position == arena.player_spawn)
	assert(reveal.spiritomb != null and main.is_enemy_occupied(Vector2i(13,8)))
	assert(main.player.health.current == hp and main.player.battle_state.remaining_pp == pp)
	assert(not main.get_node("DirectionalLight3D").visible)
	assert(main.get_node("SunlightAtmosphere").selected_mode == SunlightAtmosphere.Mode.ORIGINAL)
	assert(main.presentation_camera.environment == reveal.room_style.room_environment)
	assert(main.presentation_camera.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR)
	for visual in main.dungeon_renderer.fog_visuals:
		if visual.materials.is_empty(): continue
		assert(visual.materials[0][0].albedo_color == (SpiritombRoomStyle.STONE_TINT if visual.wall or visual.get("filler",false) else SpiritombRoomStyle.FLOOR_TINT))
	assert(reveal.CRY.get_length() < 4.0)
	# Deterministic audio-completion callback, without waiting for the mixer.
	reveal.cry.stop()
	reveal._on_cry_finished()
	reveal.music_start.pause()
	assert(music.player.stream == null)
	reveal.music_start.custom_step(0.999)
	assert(music.player.stream == null)
	reveal.music_start.custom_step(0.002)
	assert(music.player.stream == reveal.BATTLE and reveal.BATTLE.loop)
	assert(is_equal_approx(reveal.BATTLE.loop_offset,8.374))
	reveal.animation.custom_step(3.998)
	assert(reveal.phase == &"black" and main.player.transition_locked)
	reveal.animation.custom_step(0.002)
	assert(reveal.phase == &"dissolve" and not reveal.black.visible)
	reveal.animation.custom_step(1.1)
	assert(reveal.phase == &"settling" and not reveal.overlay.visible and main.player.transition_locked)
	if main.awaiting_move_ack: main.acknowledge_move()
	reveal.animation.custom_step(0.998)
	assert(main.player.transition_locked)
	reveal.animation.custom_step(0.004)
	assert(reveal.phase == &"ready" and not main.player.transition_locked)
	main.player.setup(Vector2i(13,9),main.dungeon,main.dungeon_renderer)
	main.player.try_move(Vector2i.UP)
	assert(main.player.grid_position == Vector2i(13,9))
	var spirit: Skeleton = reveal.spiritomb
	assert(main.enemies.size() == 1 and spirit.level == spirit.species_data.level and spirit.health.maximum == spirit.species_data.maximum_hp)
	main.update_presentation()
	assert(main.presentation_camera.global_position.is_equal_approx(main.player.global_position + main.presentation_camera.follow_offset))
	# Force each move through the real sequential enemy turn and presentation gates.
	spirit.attack_policy = spirit.attack_policy.duplicate()
	spirit.attack_policy.move_probability = 1.0
	for slot in range(2):
		spirit.battle_state.remaining_pp[0] = 0
		spirit.battle_state.remaining_pp[1] = 0
		spirit.battle_state.remaining_pp[slot] = 2
		var before: int = main.player.health.current
		main.run_enemy_turn()
		assert(main.player.health.current == before)
		Helper.complete(main)
		assert(main.player.health.current < before and spirit.battle_state.remaining_pp[slot] == 1)
		assert(not main.resolving_turn and not spirit.attack_resolution_pending)
	# Basic fallback at adjacency and final victory rather than another reveal.
	spirit.attack_policy.move_probability = 0.0
	var before_basic: int = main.player.health.current
	main.run_enemy_turn()
	Helper.complete(main)
	assert(main.player.health.current < before_basic)
	assert(main._damage_enemy_from_player(spirit, null))
	Helper.complete(main)
	assert(main.victory and not main.player.gameplay_enabled and music.player.stream == null)
	main.start_new_run()
	Helper.complete_introduction(main)
	# Cancel during wipe, black/cry, and dissolve. New introduction owns the lock.
	for elapsed in [1.2,2.0,6.0]:
		sequence = final_room(main)
		sequence.encounter_active = true
		assert(sequence.try_begin_spiritomb_reveal())
		reveal = sequence.spiritomb_reveal
		reveal.animation.pause()
		reveal.animation.custom_step(elapsed)
		var stale := reveal.animation
		var stale_music: Tween
		if reveal.arena_ready:
			reveal.cry.stop()
			reveal._on_cry_finished()
			stale_music = reveal.music_start
		main.start_new_run()
		assert(not stale.is_running() and main.player.transition_locked)
		if stale_music != null: assert(not stale_music.is_running())
		assert(music.player.stream == music.dungeon_track)
		Helper.complete_introduction(main)
		assert(main.final_floor_sequence == null and not main.player.transition_locked)
		assert(main.get_node("DirectionalLight3D").visible and main.presentation_camera.environment == null)
	main.free()
	await process_frame
	print("PASS: actual four defeats stop music, 1s wait/glitch/4s black/cry-1s-buffer-looped battle/dissolve/1s lock, 81-tile square, live Spiritomb AI/moves/basic/victory/camera, HP/PP and restart cancellation")
	quit()

