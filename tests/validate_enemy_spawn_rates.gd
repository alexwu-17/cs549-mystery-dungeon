extends SceneTree
const Table = preload("res://config/enemy_spawn_table.tres")
const Helper = preload("res://tests/round_test_helper.gd")
const IDS := ["stunky", "glameow", "mankey", "vulpix", "psyduck", "tangela"]

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var rng := RandomNumberGenerator.new()
	var reference := RandomNumberGenerator.new()
	for type in ["Fire", "Water", "Grass"]:
		var types := PackedStringArray([type])
		for floor_number in [1, 2, 3, 4, 5, 100]:
			var expected := PackedInt32Array([45, 45, 4, 2, 2, 2])
			if floor_number >= 3:
				expected = PackedInt32Array([10, 10, 20, 15, 15, 15])
				expected[{"Fire": 5, "Water": 3, "Grass": 4}[type]] = 30
			assert(Table.weights_for(floor_number, types) == expected)
			rng.seed = 549
			reference.seed = 549
			for trial in range(1000):
				var roll := reference.randi_range(0, 99)
				var index := 0
				while roll >= expected[index]:
					roll -= expected[index]
					index += 1
				assert(Table.choose(floor_number, types, rng) == IDS[index])
				assert(rng.state == reference.state)
	assert(Table.weights_for(3, PackedStringArray()) == PackedInt32Array([10, 10, 20, 20, 20, 20]))
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	data.rooms = [Rect2i(0, 0, 3, 3), Rect2i(12, 0, 3, 3)]
	for room in data.rooms:
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	for x in range(3, 12): data.set_tile(Vector2i(x, 1), DungeonData.TileType.CORRIDOR)
	data.player_spawn = Vector2i(1, 1)
	data.enemy_spawns = [Vector2i(13, 1)]
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data, true))
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.use_elevation_test = false
	main.floor_number = 3
	main.enemy_respawn_delay = 1
	for species_id in IDS:
		var chosen_seed := seed_for(species_id, main.player.species_data.types)
		main.enemy_spawn_rng.seed = chosen_seed
		var order_state: int = main.turn_rng.state
		seed(9901)
		var expected_global := randf()
		seed(9901)
		main.spawn_test_enemies()
		assert(randf() == expected_global and main.turn_rng.state == order_state)
		var enemy: Skeleton = main.enemies[0]
		assert(enemy.species_data.species_id == StringName(species_id))
		assert(enemy.character_visual.profile.display_name.to_lower() == species_id)
		assert(enemy.level == 10 and enemy.battle_state.moves.size() == 1)
		# Clear without combat, then exercise the actual delayed-respawn entry point.
		data.enemy_spawns = []
		main.spawn_test_enemies()
		data.update_fog(data.player_spawn)
		main.enemy_spawn_rng.seed = chosen_seed
		main._advance_repopulation()
		assert(main.enemies.size() == 1)
		assert(main.enemies[0].species_data.species_id == StringName(species_id))
		assert(main.enemies[0].health.current == main.enemies[0].maximum_hp)
		data.enemy_spawns = [Vector2i(13, 1)]
	main.free()
	await process_frame
	print("PASS: exact floor1-2/player-type floor3+ weights, 18000 seeded selections, all six initial/respawn species, native profiles/PP and independent topology/turn RNG")
	quit()

func seed_for(species_id: String, types: PackedStringArray) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(10000):
		rng.seed = value
		if Table.choose(3, types, rng) == species_id: return value
	assert(false)
	return 0
