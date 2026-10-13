extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	for scene in ["main", "demo_main", "limit_testing_main"]:
		var main = load("res://scenes/main/%s.tscn" % scene).instantiate()
		main.benchmark_enabled = false # Exercise the retained procedural mode.
		var config := DungeonGenerationConfig.new()
		config.invincible_player = true
		main.generation_config = config
		root.add_child(main)
		Helper.complete_introduction(main)
		var limit: bool = scene == "limit_testing_main"
		assert(main.player.invincible == limit)
		main._on_enemy_attack(2, "Skeleton")
		assert(main.player.health.current == (20 if limit else 18))
		main.player.receive_damage(100)
		assert(main.player.health.current == (20 if limit else 0))
		assert(main.game_over == not limit)
		if limit:
			main._on_stairs_reached()
			Helper.complete_introduction(main)
			assert(main.floor_number == 2 and main.player.invincible)
			main.start_new_run()
			Helper.complete_introduction(main)
			assert(main.player.invincible and main.player.health.current == 20)
			config.invincible_player = false
			main.start_new_run()
			Helper.complete_introduction(main)
			main.player.receive_damage(2)
			assert(not main.player.invincible and main.player.health.current == 18)
		main.free()
	print("PASS: invincibility only in Limit Testing, blocked/lethal damage, floor/restart persistence, disabling")
	quit()
