extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
func _initialize() -> void: call_deferred("validate")
func validate() -> void:
	var recovery: PokemonMoveData = load("res://config/moves/recovery.tres")
	for choice in range(3):
		var menu = load("res://scenes/ui/demo_start.tscn").instantiate()
		root.add_child(menu)
		menu.show_selection()
		menu.start_starter(choice)
		var main: Node3D = menu.gameplay
		Helper.complete_introduction(main)
		main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
		main.load_test_floor()
		if main.awaiting_move_ack: main.acknowledge_move()
		main.move_learned_sound.stop()
		var sequence: FinalFloorSequence = main.final_floor_sequence
		var reveal := SpiritombReveal.new()
		sequence.add_child(reveal)
		sequence.spiritomb_reveal = reveal
		reveal.initialize(main, sequence)
		reveal.animation.pause()
		assert(not main.player.battle_state.knows_move(recovery))
		reveal.animation.custom_step(1.81)
		await process_frame
		await process_frame
		reveal.animation.pause()
		assert(main.player.battle_state.knows_move(recovery) and not main.awaiting_move_ack)
		assert(not main.move_learned_sound.playing)
		reveal.cry.stop()
		reveal._on_cry_finished()
		reveal.music_start.pause()
		reveal.music_start.custom_step(1.1)
		reveal.animation.custom_step(5.11)
		assert(main.awaiting_move_ack and main.move_learned_sound.playing)
		assert(main.dialogue.history[0].message == main._player_display_name() + " learned Recovery!")
		assert(main.get_node("/root/MusicManager").player.stream_paused)
		assert(not main.player.gameplay_enabled and main.dialogue.timer.is_stopped())
		assert(not main.player.use_move(main.player.battle_state.moves.find(recovery)))
		main.acknowledge_move()
		assert(not main.awaiting_move_ack and not main.get_node("/root/MusicManager").player.stream_paused)
		reveal.animation.custom_step(1.1)
		var state: PokemonBattleState = main.player.battle_state
		assert(state.knows_move(recovery))
		var slot := state.moves.find(recovery)
		assert(state.remaining_pp[slot] == 10)
		# Remove enemy turns to measure only healing, while retaining real round flow.
		main.enemies[0].free()
		main.enemies.clear()
		main.enemy_occupancy.clear()
		state.health.damage(state.health.maximum - 1)
		var expected := ceili(state.health.maximum * 0.5)
		assert(main.player.use_move(slot))
		assert(main.player.character_visual.clip == "Charge" and state.health.current == 1)
		Helper.complete(main)
		assert(state.health.current == mini(state.health.maximum, 1 + expected))
		assert(state.remaining_pp[slot] == 9 and not main.resolving_turn)
		var found := false
		for popup in main.hud.damage_numbers.popups:
			if popup.label.text == "+%d" % expected: found = true
		assert(found)
		for i in range(9):
			assert(main.player.use_move(slot))
			Helper.complete(main)
		assert(state.health.current == state.health.maximum and state.remaining_pp[slot] == 0)
		assert(not main.player.use_move(slot))
		state.remaining_pp[slot] = 1
		state.health.damage(10)
		assert(main.player.use_move(slot))
		main.cancel_round()
		Helper.complete(main)
		assert(state.health.current == state.health.maximum - 10)
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(not state.knows_move(recovery))
		menu.free()
	print("PASS: all starters learn Recovery at Spiritomb; Charge, delayed half-HP heal, cap, green number, ten PP, turns and fresh-run reset")
	quit()
