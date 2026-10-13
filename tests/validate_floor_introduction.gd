extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")
var completions: int = 0

func _initialize() -> void:
	call_deferred("validate")

func step(intro: FloorIntroduction, seconds: float) -> void:
	intro.animation.pause()
	intro.animation.custom_step(seconds)

func check_lock(main: Node3D) -> void:
	var tile: Vector2i = main.player.grid_position
	var hp: int = main.player.health.current
	main.player.gameplay_enabled = true # Initialization cannot override this lock.
	main.player.try_move(Vector2i.RIGHT)
	main.player.basic_attack()
	main.run_enemy_turn()
	assert(main.player.grid_position == tile and main.player.health.current == hp)
	assert(not main.player.attack_leap.active and not main.resolving_turn)

func validate() -> void:
	for scene in ["main", "demo_main", "limit_testing_main"]:
		var main = load("res://scenes/main/%s.tscn" % scene).instantiate()
		# This suite covers procedural transitions; the fixed benchmark is tested separately.
		main.benchmark_enabled = false
		if scene == "limit_testing_main": main.generation_config = DungeonGenerationConfig.new()
		root.add_child(main)
		var intro: FloorIntroduction = main.floor_introduction
		completions = 0
		intro.introduction_finished.connect(func(): completions += 1)
		assert(intro.visible and intro.background.modulate.a == 1 and intro.title.modulate.a == 0)
		assert(main.player.transition_locked and main.floor_number == 1)
		assert(intro.get_node("CenterContainer/VBoxContainer/FloorSubtitle").text == "1 F")
		check_lock(main)
		step(intro, 0.125)
		assert(is_equal_approx(intro.title.modulate.a, 0.5) and intro.background.modulate.a == 1)
		step(intro, 0.125)
		assert(is_equal_approx(intro.title.modulate.a, 1))
		step(intro, 0.5)
		assert(is_equal_approx(intro.title.modulate.a, 1) and intro.background.modulate.a == 1)
		step(intro, 0.25)
		assert(is_zero_approx(intro.title.modulate.a) and intro.background.modulate.a == 1)
		check_lock(main)
		step(intro, 0.125)
		assert(is_equal_approx(intro.background.modulate.a, 0.5) and intro.title.modulate.a == 0)
		assert(main.player.transition_locked)
		step(intro, 0.126)
		assert(not intro.visible and not main.player.transition_locked and completions == 1)
		# A staircase retains the old floor until opacity reaches one.
		var previous: DungeonData = main.dungeon
		main.dialogue.append_event(&"charging")
		var entries: int = main.dialogue.history.size()
		var timer_remaining: float = main.dialogue.timer.time_left
		main._on_stairs_reached()
		assert(main.floor_number == 1 and main.dungeon == previous)
		assert(intro.title.modulate.a == 0 and intro.background.modulate.a == 0)
		check_lock(main)
		step(intro, 0.125)
		assert(main.dungeon == previous and is_equal_approx(intro.background.modulate.a, 0.5))
		step(intro, 0.126)
		assert(main.floor_number == 2 and main.dungeon != previous and intro.background.modulate.a == 1)
		assert(main.dialogue.history.size() == entries and main.dialogue.timer.time_left == timer_remaining)
		assert(intro.get_node("CenterContainer/VBoxContainer/FloorSubtitle").text == "2 F")
		Helper.complete_introduction(main)
		assert(completions == 2)
		# Restart cancels either fade phase, with no false completion signal.
		main._on_stairs_reached()
		var canceled: Tween = intro.animation
		main.start_new_run()
		assert(not canceled.is_running() and completions == 2 and main.floor_number == 1)
		assert(main.player.transition_locked and intro.background.modulate.a == 1)
		assert(main.dialogue.history.is_empty())
		Helper.complete_introduction(main)
		assert(completions == 3 and not main.player.transition_locked)
		main.dungeon_name = "Test Cavern"
		main.floor_subtitles[3] = "Custom Depths"
		main._on_stairs_reached()
		Helper.complete_introduction(main)
		main._on_stairs_reached()
		step(intro, 0.251)
		assert(intro.get_node("CenterContainer/VBoxContainer/DungeonName").text == "Test Cavern")
		assert(intro.get_node("CenterContainer/VBoxContainer/FloorSubtitle").text == "Custom Depths")
		Helper.complete_introduction(main)
		if scene == "demo_main":
			main.floor_number = 4
			main._on_stairs_reached()
			step(intro, 0.251)
			assert(main.boss != null and main.floor_number == 5)
			assert(intro.get_node("CenterContainer/VBoxContainer/FloorSubtitle").text == "Cavern Depths")
			step(intro, 0.25)
			step(intro, 0.75)
			assert(is_equal_approx(intro.title.modulate.a, 1.0) and main.player.transition_locked)
			step(intro, 0.25)
			assert(is_equal_approx(intro.title.modulate.a, 1.0))
			step(intro, 0.125)
			assert(is_equal_approx(intro.title.modulate.a, 0.5))
			assert(is_equal_approx(intro.text_hold_duration, 0.5)) # Default was not mutated.
			Helper.complete_introduction(main)
		main.start_new_run()
		Helper.complete_introduction(main)
		main._on_stairs_reached()
		# Removing a scene during fade must not initialize another floor.
		main.free()
	await process_frame
	print("PASS: title phases/timing, initial black, load-after-black, authoritative input lock, modes/subtitles, cancellation/completion, dialogue preservation")
	quit()
