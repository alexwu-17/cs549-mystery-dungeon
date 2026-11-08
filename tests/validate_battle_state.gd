extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var chimchar: PokemonSpeciesData = load("res://config/species/chimchar.tres")
	var first := PokemonBattleState.new()
	var second := PokemonBattleState.new()
	first.reset(chimchar)
	second.reset(chimchar)
	assert(first.health != second.health and first.species == second.species)
	first.health.damage(12)
	first.remaining_pp.append(3)
	first.stat_stages[&"attack"] = -1
	first.level = 99
	assert(second.health.current == 76 and second.remaining_pp.is_empty() and second.stat_stages.is_empty())
	assert(chimchar.maximum_hp == 76 and chimchar.level == 20 and chimchar.attack == 39)
	var identity := first.health
	first.reset(chimchar)
	assert(first.health == identity and first.health.current == 76 and first.level == 20)
	assert(first.remaining_pp.is_empty() and first.stat_stages.is_empty())
	# Every authored final stat is copied exactly, without level scaling.
	for species_name in ["chimchar", "piplup", "turtwig", "stunky"]:
		var species: PokemonSpeciesData = load("res://config/species/%s.tres" % species_name)
		first.reset(species)
		assert(first.health.maximum == species.maximum_hp and first.level == species.level)
		assert(first.attack == species.attack and first.special_attack == species.special_attack)
		assert(first.defense == species.defense and first.special_defense == species.special_defense)
	first.reset(null, 30, 5)
	assert(first.species == null and first.health.current == 30 and first.level == 5)
	assert(first.attack == 1 and first.special_defense == 1)

	var main = load("res://scenes/main/main.tscn").instantiate()
	main.game_mode = GameModeConfig.Mode.DEMO
	root.add_child(main)
	Helper.complete_introduction(main)
	assert(main.player.health == main.player.battle_state.health)
	assert(main.player.health.current == 76 and main.player.maximum_hp == 76 and main.player.level == 20)
	assert(main.hud.hp_label.text == "76 / 76 HP")
	assert(main.player.attack_damage == 3)
	var enemy: Skeleton = main.enemies[0]
	assert(enemy.health.current == 42 and enemy.maximum_hp == 42 and enemy.level == 1)
	assert(enemy.battle_state.attack == 21 and enemy.attack_damage == 2)
	var other: Skeleton = main.enemies[1]
	enemy.health.damage(7)
	assert(other.health.current == 42 and enemy.species_data.maximum_hp == 42)
	main.player.health.damage(10)
	main.player.battle_state.remaining_pp.append(4)
	main.player.battle_state.stat_stages[&"defense"] = -1
	# Actual stair transition preserves mutable player state, while new enemies reset.
	main._on_stairs_reached()
	Helper.complete_introduction(main)
	assert(main.floor_number == 2 and main.player.health.current == 66)
	assert(main.player.battle_state.remaining_pp == [4])
	assert(main.player.battle_state.stat_stages[&"defense"] == -1)
	assert(main.enemies[0].health.current == 42)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.player.health.current == 76 and main.player.level == 20)
	assert(main.player.battle_state.remaining_pp.is_empty() and main.player.battle_state.stat_stages.is_empty())
	assert(main.hud.hp_label.text == "76 / 76 HP")
	# A future selected species can use the same reset path; no selection UI added.
	main.player.species_data = load("res://config/species/piplup.tres")
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.player.health.current == 80 and main.player.battle_state.special_attack == 42)
	assert(main.hud.hp_label.text == "80 / 80 HP")
	var live_health: EntityHealth = main.player.health
	main.player.receive_damage(999)
	assert(main.game_over and live_health.current == 0 and main.hud.hp_bar.value == 0)
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(not main.game_over and main.player.health == live_health and live_health.current == 80)
	main._on_stairs_reached()
	Helper.complete_introduction(main)
	main._on_stairs_reached()
	Helper.complete_introduction(main)
	assert(main.boss != null and main.boss.species_data == null)
	assert(main.boss.health == main.boss.battle_state.health and main.boss.health.current == 30)
	assert(main.boss.attack_damage == 18 and main.boss.footprint().size() == 1)
	main.free()
	await process_frame
	print("PASS: isolated battle state, exact species stats, live HP/levels/HUD, floor persistence, fresh reset and boss fallback")
	quit()
