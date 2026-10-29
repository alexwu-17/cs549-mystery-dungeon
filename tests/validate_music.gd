extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")
var music: Node

func _initialize() -> void:
	call_deferred("validate")

func step(intro: FloorIntroduction, seconds: float) -> void:
	intro.animation.pause()
	intro.animation.custom_step(seconds)

func validate() -> void:
	music = root.get_node("MusicManager")
	assert(music.get_child_count() == 1 and music.player.bus == &"Master")
	assert(music.dungeon_track is AudioStreamMP3 and music.boss_track is AudioStreamMP3)
	assert(music.dungeon_track.get_length() > 30 and music.boss_track.get_length() > 0)
	assert(music.dungeon_track.resource_path.ends_with("mtcoronet_midterm.mp3"))
	assert(music.boss_track.resource_path.ends_with("pmd_bosstheme_midterm.mp3"))
	assert(music.dungeon_track.loop and music.boss_track.loop)
	assert(music.dungeon_track.loop_offset == 0 and music.boss_track.loop_offset == 0)
	for mode in ["main", "limit_testing_main", "demo_main"]:
		var main = load("res://scenes/main/%s.tscn" % mode).instantiate()
		main.benchmark_enabled = false # Music floor progression uses procedural fixtures.
		if mode == "limit_testing_main": main.generation_config = DungeonGenerationConfig.new()
		root.add_child(main)
		assert(music.player.playing and music.player.stream == music.dungeon_track)
		Helper.complete_introduction(main)
		music.player.seek(30.0)
		music.play_dungeon(main)
		assert(music.player.get_playback_position() >= 29.0)
		main._on_stairs_reached()
		assert(music.player.playing)
		Helper.complete_introduction(main)
		assert(music.player.stream == music.dungeon_track and music.player.get_playback_position() >= 29.0)
		main.start_new_run()
		assert(music.player.playing and music.player.get_playback_position() < 1.0)
		Helper.complete_introduction(main)
		main.player.receive_damage(100)
		assert(not music.player.playing)
		main.start_new_run()
		Helper.complete_introduction(main)
		if mode == "demo_main":
			main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR - 1
			main.load_test_floor()
			main._on_stairs_reached()
			assert(not music.player.playing and main.floor_number == GameModeConfig.DEMO_FINAL_FLOOR - 1)
			step(main.floor_introduction, 0.251)
			assert(main.floor_number == GameModeConfig.DEMO_FINAL_FLOOR and not music.player.playing)
			step(main.floor_introduction, 1.501)
			assert(main.floor_introduction.visible and not music.player.playing)
			step(main.floor_introduction, 0.251)
			assert(not main.floor_introduction.visible and music.player.playing)
			assert(music.player.stream == music.boss_track and music.player.get_playback_position() < 1.0)
			main.boss.receive_damage(100)
			assert(main.victory and not music.player.playing)
			main.start_new_run()
			Helper.complete_introduction(main)
			main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR - 1
			main._on_stairs_reached()
			step(main.floor_introduction, 0.251)
			var stale: Tween = main.floor_introduction.animation
			main.start_new_run()
			assert(not stale.is_valid() or not stale.is_running())
			Helper.complete_introduction(main)
			assert(main.floor_number == 1 and music.player.stream == music.dungeon_track and music.player.playing)
		main.free()
		assert(not music.player.playing)
	# An outgoing scene and its canceled callbacks cannot stop a newer owner.
	var old = load("res://scenes/main/demo_main.tscn").instantiate()
	root.add_child(old)
	Helper.complete_introduction(old)
	old.floor_number = GameModeConfig.DEMO_FINAL_FLOOR - 1
	old._on_stairs_reached()
	var newer = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(newer)
	Helper.complete_introduction(newer)
	Helper.complete_introduction(old)
	assert(music.player.stream == music.dungeon_track and music.owns_playback(newer))
	old.free()
	assert(music.player.playing and music.owns_playback(newer))
	newer.free()
	assert(not music.player.playing)
	await process_frame
	await process_frame
	print("PASS: MP3 loading/looping, single player, continuous floors, silent boss intro/completion, death/victory/restart, stale ownership")
	quit()
