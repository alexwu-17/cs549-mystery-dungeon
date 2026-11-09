extends "res://tests/validate_status_moves.gd"

func unit_duration() -> void:
	var state := PokemonBattleState.new()
	state.reset(load("res://config/species/stunky.tres"))
	var restored := [0]
	state.stats_restored.connect(func(): restored[0] += 1)
	state.change_stage(&"attack", -1)
	state.finish_stage_turn()
	assert(state.stage_turns_remaining == 5)
	for index in range(4): state.finish_stage_turn()
	assert(state.stage_turns_remaining == 1 and state.get_stage(&"attack") == -1)
	# Another stat refreshes the actor's whole stack, without changing copied bases.
	state.change_stage(&"defense", -1)
	state.finish_stage_turn()
	assert(state.stage_turns_remaining == 5 and state.get_stage(&"attack") == -1)
	state.change_stage(&"attack", -999)
	state.finish_stage_turn()
	for index in range(4): state.finish_stage_turn()
	assert(state.change_stage(&"attack", -1) == 0 and state.stage_turns_remaining == 5)
	state.finish_stage_turn()
	for index in range(4): state.finish_stage_turn()
	assert(restored[0] == 0 and state.stage_turns_remaining == 1)
	state.finish_stage_turn()
	assert(restored[0] == 1 and state.stat_stages.is_empty() and state.attack == 21 and state.defense == 18)
	state.finish_stage_turn()
	assert(restored[0] == 1)
	state.change_stage(&"defense", 1)
	state.reset_stages()
	for index in range(8): state.finish_stage_turn()
	assert(restored[0] == 1 and state.stage_turns_remaining == 0)

func advance(main: Node3D) -> void:
	main.run_enemy_turn()
	Helper.complete(main)
	assert(not main.resolving_turn)

func validate() -> void:
	unit_duration()
	for index in range(3):
		var main := make_main(index)
		var player: Player = main.player
		var enemy: Skeleton = main.enemies[0]
		for actor in main.enemies:
			actor.attack_policy = actor.attack_policy.duplicate()
			actor.attack_policy.move_probability = 1.0
		var target: Node3D = player if index == 2 else enemy
		var stat := &"attack" if index == 1 else &"defense"
		var delta := 1 if index == 2 else -1
		main.dialogue.clear_history()
		press_i(player)
		assert(main.dialogue.history[0].message == "%s used %s." % [player.character_visual.get_display_name(), player.battle_state.moves[1].display_name])
		assert(main.dialogue.history[1].message == "%s's %s was %s." % [target.character_visual.get_display_name(), "Attack" if index == 1 else "Defense", "increased" if index == 2 else "reduced"])
		Helper.complete(main)
		assert(target.battle_state.stage_turns_remaining == 5)
		if index == 1:
			assert(main.enemies[1].battle_state.stage_turns_remaining == 5)
			assert(main.enemies[2].battle_state.stage_turns_remaining == 0)
		for tick in range(4): advance(main)
		assert(target.battle_state.stage_turns_remaining == 1 and target.battle_state.get_stage(stat) == delta)
		# Rejected input/idle processing never advances the timer.
		player.transition_locked = true
		assert(not player.use_move(1))
		player._process(10.0)
		assert(target.battle_state.stage_turns_remaining == 1)
		player.transition_locked = false
		press_i(player)
		Helper.complete(main)
		assert(target.battle_state.stage_turns_remaining == 5 and target.battle_state.get_stage(stat) == delta * 2)
		for tick in range(4): advance(main)
		assert(target.battle_state.get_stage(stat) == delta * 2)
		advance(main)
		assert(target.battle_state.stat_stages.is_empty() and target.battle_state.stage_turns_remaining == 0)
		var restores: Array = main.dialogue.history.filter(func(entry): return entry.type == &"stats_restored")
		assert(restores.size() == (2 if index == 1 else 1))
		assert(restores[0].message == "%s's stats returned to normal." % target.character_visual.get_display_name())
		advance(main)
		assert(main.dialogue.history.filter(func(entry): return entry.type == &"stats_restored").size() == restores.size())
		if index == 0:
			main.dialogue.clear_history()
			assert(player.use_move(0))
			assert(main.dialogue.history[0].message == "Chimchar used Scratch.")
			assert(main.dialogue.history[1].message == "Stunky took 36 damage.")
			Helper.complete(main)
			var used: Array = main.dialogue.history.filter(func(entry): return entry.type == &"move_used" and entry.data.actor == "Stunky")
			assert(not used.is_empty() and used[0].message == "Stunky used Scratch.")
		# Cancellation/fresh reset clears timers without delayed expiry dialogue.
		player.battle_state.change_stage(&"defense", 1)
		player.battle_state.stage_duration_fresh = false
		player.battle_state.stage_turns_remaining = 1
		main.run_enemy_turn()
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(player.battle_state.stage_turns_remaining == 0 and player.battle_state.stat_stages.is_empty())
		assert(main.dialogue.history.is_empty())
		main.free()
		await process_frame
	# A reset triggered by expiry listeners cannot unlock/finish the outgoing round.
	var main := make_main(0)
	main.player.battle_state.change_stage(&"defense", 1)
	main.player.battle_state.stage_duration_fresh = false
	main.player.battle_state.stage_turns_remaining = 1
	main.player.battle_state.stats_restored.connect(main.start_new_run, CONNECT_ONE_SHOT)
	main.run_enemy_turn()
	Helper.complete(main)
	assert(main.player.transition_locked and main.dialogue.history.is_empty())
	Helper.complete_introduction(main)
	assert(not main.player.transition_locked and main.player.battle_state.stage_turns_remaining == 0)
	main.free()
	await process_frame
	print("PASS: five subsequent turns, shared stack/refresh/cap/expiry timers, room isolation, move/stat/damage/expiry dialogue and reset/cancellation")
	quit()
