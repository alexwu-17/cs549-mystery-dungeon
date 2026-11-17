extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func enter_center(main: Node3D) -> FinalFloorSequence:
	main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
	main.load_test_floor()
	var atmosphere: SunlightAtmosphere = main.get_node("SunlightAtmosphere")
	atmosphere._update_context()
	var ground: GroundMist = atmosphere.ground_mist
	assert(ground.bounds.has_point(FinalFloorFactory.PLAYER_SPAWN))
	main.player.health.reset(1000)
	main.player.setup(FinalFloorSequence.RECOVERY_TILE, main.dungeon, main.dungeon_renderer)
	main.player.try_move(Vector2i.UP)
	var sequence: FinalFloorSequence = main.final_floor_sequence
	sequence.camera_transition.pause()
	sequence.camera_transition.custom_step(1.0)
	assert(not main.player.transition_locked and main.enemies.is_empty())
	assert(is_equal_approx(main.get_node("SunlightAtmosphere").ground_mist.material.get_shader_parameter("opacity"), 0.1275 * 5.0))
	main.get_node("/root/MusicManager").play_custom(main, main.final_approach_track)
	for y in range(14, 9, -1):
		main.player.try_move(Vector2i.UP)
		Helper.complete(main)
	assert(main.player.grid_position == DemoArenaFactory.ARENA_CENTER)
	assert(sequence.encounter_started and not sequence.encounter_active)
	assert(is_equal_approx(main.get_node("SunlightAtmosphere").ground_mist.material.get_shader_parameter("opacity"), 0.1275))
	assert(main.player.transition_locked and main.floor_introduction.visible)
	assert(main.floor_introduction.background.modulate.a == 1.0)
	assert(not sequence.center_marker.visible)
	sequence.encounter_transition.pause()
	return sequence

func validate() -> void:
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	main.get_node("SunlightAtmosphere").bind_main(main)
	var music = root.get_node("MusicManager")
	var sequence := enter_center(main)
	assert(music.player.stream == null and not music.player.playing)
	var tween := sequence.encounter_transition
	var hp: int = main.player.health.current
	tween.custom_step(0.999)
	assert(music.player.stream == null and not music.player.playing and main.enemies.is_empty())
	main.player.try_move(Vector2i.UP)
	assert(main.player.grid_position == DemoArenaFactory.ARENA_CENTER)
	assert(not main.player.use_move(0))
	tween.custom_step(0.002)
	assert(music.player.stream == music.boss_track)
	assert(music.boss_track.loop and is_equal_approx(music.boss_track.loop_offset,22.54))
	assert(main.floor_introduction.visible and main.enemies.is_empty())
	tween.custom_step(0.498)
	assert(main.floor_introduction.visible and not sequence.encounter_active)
	tween.custom_step(0.002)
	assert(sequence.encounter_active and not main.player.transition_locked)
	assert(not main.floor_introduction.visible and main.enemies.size() == 4 and main.enemy_occupancy.size() == 4)
	assert(main.player.health.current == hp and not main.resolving_turn)
	var formation := {Vector2i(0,-2):"riolu",Vector2i(-2,0):"budew",Vector2i(2,0):"gible",Vector2i(0,2):"feebas"}
	for offset: Vector2i in formation:
		var enemy: Skeleton = main.enemy_occupancy[DemoArenaFactory.ARENA_CENTER + offset]
		assert(enemy.species_data.species_id == StringName(formation[offset]))
		assert(enemy.health.current == enemy.health.maximum and enemy.level == 10)
		assert(enemy.facing == -offset / 2)
		assert(enemy.visible)
	var actions := [0]
	main.enemy_action_started.connect(func(_actor: Node3D): actions[0] += 1)
	main.player.basic_attack()
	Helper.complete(main)
	assert(actions[0] == 4 and not main.game_over)
	sequence.on_player_moved()
	assert(main.enemies.size() == 4 and not main.floor_introduction.visible)
	# Restart before the cue, and again after the cue but before reveal.
	for elapsed in [0.5,1.1]:
		sequence = enter_center(main)
		sequence.encounter_transition.custom_step(elapsed)
		var stale := sequence.encounter_transition
		main.start_new_run()
		assert(not stale.is_running() and main.player.transition_locked)
		Helper.complete_introduction(main)
		assert(main.floor_number == 1 and main.final_floor_sequence == null)
		assert(not main.player.transition_locked and not main.floor_introduction.visible)
		assert(music.player.stream == music.dungeon_track)
		for enemy in main.enemies:
			assert(enemy.species_data.species_id not in [&"budew",&"feebas",&"riolu",&"gible"])
	# Death while black cancels both the pending cue and spawns.
	sequence = enter_center(main)
	var stale := sequence.encounter_transition
	main.player.receive_damage(10000)
	assert(main.game_over and not stale.is_running())
	assert(main.enemies.is_empty() and music.player.stream == null)
	main.free()
	await process_frame
	print("PASS: center-only one-shot encounter, 1s imported-loop music, 1.5s blackout, exact four-species formation/facing, input locks, next-action combat, restart/death cancellation")
	quit()
