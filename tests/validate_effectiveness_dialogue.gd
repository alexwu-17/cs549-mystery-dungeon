extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
func _initialize() -> void:
	call_deferred("validate")

func expect_message(main: Node3D, expected: String) -> void:
	var lines: Array = main.dialogue.history.filter(func(entry: Dictionary): return entry.type != &"separator")
	assert(lines[0].type == &"move_used")
	assert(lines[1].type == &"damage")
	if not expected.is_empty():
		assert(lines[2].message == expected)
	else:
		assert(not lines.any(func(entry: Dictionary): return entry.type in [&"super_effective", &"not_very_effective"]))

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	assert(main.dialogue.visible_lines == 5)
	assert(main.dialogue.text.get_theme_font_size("normal_font_size") == 24)
	main.cancel_round()
	var data := DungeonData.new()
	for x in range(5): data.set_tile(Vector2i(x,0),DungeonData.TileType.FLOOR)
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
	main.player.health.reset(1000)
	var enemy: Skeleton = main._spawn_regular_enemy(Vector2i.RIGHT, load("res://scenes/enemies/tangela.tscn"))
	enemy.health.reset(1000)
	enemy.battle_state.species = enemy.battle_state.species.duplicate()
	main.player.battle_state.species = main.player.battle_state.species.duplicate()
	var move := PokemonMoveData.new()
	move.move_id = &"dialogue_fixture"
	move.display_name = "Ember"
	move.move_type = "Fire"
	move.category = PokemonMoveData.Category.SPECIAL
	move.power = 1
	var defenders := [PackedStringArray(["Grass"]),PackedStringArray(["Water"]),PackedStringArray(["Grass","Water"]),PackedStringArray(["Ghost"])]
	var messages := ["It's super effective!","It's not very effective...", "", "It had no effect..."]
	for index in range(4):
		move.move_type = "Normal" if index == 3 else "Fire"
		enemy.battle_state.species.types = defenders[index]
		main.dialogue.clear_history()
		main._on_player_attack(Vector2i.RIGHT,move)
		expect_message(main,messages[index])
		Helper.complete(main)
		main.player.battle_state.species.types = defenders[index]
		main.dialogue.clear_history()
		enemy.active_attack_move = move
		main._resolve_enemy_attack(1,enemy)
		expect_message(main,messages[index])
	# Ghost hits Normal for zero as well; keep move/damage/immunity ordering.
	move.move_type = "Ghost"
	enemy.battle_state.species.types = PackedStringArray(["Normal"])
	main.dialogue.clear_history()
	main._on_player_attack(Vector2i.RIGHT, move)
	expect_message(main, "It had no effect...")
	Helper.complete(main)
	# Learning replaces previous battle text and emits the notification sound.
	main.player.battle_state.moves[0] = null
	var learned := PokemonMoveData.new()
	learned.display_name = "Test Learn"
	assert(main.player.battle_state.learn_move(learned))
	assert(main.dialogue.history.size() == 1)
	assert(main.dialogue.history[0].message == main._player_display_name() + " learned Test Learn!")
	assert(main.move_learned_sound.playing and main.awaiting_move_ack)
	main.acknowledge_move()
	# Basic attacks and status moves do not announce type effectiveness.
	main.dialogue.clear_history()
	main._on_player_attack(Vector2i.RIGHT)
	Helper.complete(main)
	assert(not main.dialogue.history.any(func(entry: Dictionary): return entry.type in [&"super_effective", &"not_very_effective"]))
	main.dialogue.clear_history()
	move.category = PokemonMoveData.Category.STATUS
	main._append_effectiveness(move,enemy.battle_state)
	assert(main.dialogue.history.is_empty())
	move.category = PokemonMoveData.Category.SPECIAL
	move.move_type = "Fire"
	# Boss targets share the same ordering; use copied stats to avoid resource edits.
	main.spawn_test_enemies()
	main.boss = main.BOSS_SCENE.instantiate()
	main.entities.add_child(main.boss)
	main.boss.setup(Vector2i.RIGHT,data,main.dungeon_renderer)
	main.boss.health.reset(1000)
	main.boss.battle_state.species = main.boss.battle_state.species.duplicate()
	main.boss.battle_state.species.types = PackedStringArray(["Grass"])
	main._on_player_attack(Vector2i.RIGHT,move)
	expect_message(main,"It's super effective!")
	Helper.complete(main)
	# Lethal hits report the complete damage rather than remaining HP.
	main.dialogue.clear_history()
	main.player.health.current = 1
	var damage := PokemonDamage.move_damage(main.boss.battle_state, main.player.battle_state, move)
	main.boss.active_attack_move = move
	main._resolve_enemy_attack(1,main.boss)
	var hits: Array = main.dialogue.history.filter(func(entry: Dictionary): return entry.type == &"damage")
	assert(hits[0].data.amount == damage and damage > 1)
	main.free()
	await process_frame
	print("PASS: player/enemy/boss dialogue ordering, effectiveness/immunity, full overkill damage and priority move-learning message/audio")
	quit()
