extends SceneTree
## Owns: species types/STAB for the elemental moves, floor unlock once per run,
## authoritative straight projectile flight, O-slot input/PP/turns and boss hits.

const Helper = preload("res://tests/round_test_helper.gd")
const NAMES := ["chimchar", "piplup", "turtwig"]
const TYPES := ["Fire", "Water", "Grass"]
const UNLOCK := [&"ember", &"bubble", &"razor_leaf"]
const UNLOCK_NAMES := ["Ember", "Bubble", "Razor Leaf"]
const CATEGORIES := [PokemonMoveData.Category.SPECIAL, PokemonMoveData.Category.SPECIAL, PokemonMoveData.Category.PHYSICAL]
const POWER := [6, 6, 8]
const STARTING_PP := [[28, 27], [27, 20], [30, 16]]
const STUNKY_DAMAGE := [50, 54, 60]
const DRAPION_DAMAGE := [31, 35, 38]


func _initialize() -> void:
	call_deferred("validate")


func state(name: String) -> PokemonBattleState:
	var result := PokemonBattleState.new()
	result.reset(load("res://config/species/%s.tres" % name))
	return result


func validate_data() -> void:
	var stunky := state("stunky")
	var drapion := state("drapion")
	assert(stunky.species.types == PackedStringArray(["Poison", "Dark"]))
	for index in range(3):
		var attacker := state(NAMES[index])
		var species: PokemonSpeciesData = attacker.species
		assert(species.types == PackedStringArray([TYPES[index]]))
		var move: PokemonMoveData = species.floor_unlock_move
		assert(move != null and move.move_id == UNLOCK[index] and move.display_name == UNLOCK_NAMES[index])
		assert(move.move_type == TYPES[index] and move.category == CATEGORIES[index] and move.power == POWER[index])
		assert(move.maximum_pp == 10 and move.range_tiles == 4 and move.targeting == PokemonMoveData.Targeting.STRAIGHT_PROJECTILE)
		assert(not species.starting_moves.has(move) and attacker.moves.size() == 2)
		assert(PokemonDamage.move_damage(attacker, stunky, move) == STUNKY_DAMAGE[index])
		assert(PokemonDamage.move_damage(attacker, drapion, move) == DRAPION_DAMAGE[index])
		# STAB comes from the species type; the same move without it deals less.
		var neutral := state(NAMES[index])
		neutral.species = neutral.species.duplicate()
		neutral.species.types = PackedStringArray()
		assert(PokemonDamage.move_damage(neutral, stunky, move) < STUNKY_DAMAGE[index])
		# Existing Normal moves/basics receive no STAB from the new types.
		assert(PokemonDamage.move_damage(attacker, stunky, attacker.moves[0]) == [36, 37, 39][index])
		assert(PokemonDamage.basic_damage(attacker, stunky) == [17, 17, 18][index])
		# learn_move appends once with full PP, never twice, and reset forgets it.
		var changes: Array[int] = [0]
		attacker.moves_changed.connect(func(): changes[0] += 1)
		assert(not attacker.knows_move(move) and attacker.learn_move(move) and attacker.knows_move(move))
		assert(attacker.moves.size() == 3 and attacker.remaining_pp == [STARTING_PP[index][0], STARTING_PP[index][1], 10])
		assert(not attacker.learn_move(move) and not attacker.learn_move(null) and changes[0] == 1)
		assert(attacker.spend_pp(2) and attacker.remaining_pp[2] == 9)
		attacker.reset(species)
		assert(attacker.moves.size() == 2 and not attacker.knows_move(move))
		# An explicit empty slot is filled before appending; a full set refuses.
		attacker.moves[1] = null
		attacker.remaining_pp[1] = 0
		assert(attacker.learn_move(move) and attacker.moves[1] == move and attacker.remaining_pp[1] == 10)
		var full := species.duplicate() as PokemonSpeciesData
		full.starting_moves = [attacker.moves[0], attacker.moves[0], attacker.moves[0], attacker.moves[0]]
		attacker.reset(full)
		assert(attacker.moves.size() == 4 and not attacker.learn_move(move) and attacker.moves.size() == 4)


func validate_path() -> void:
	var data := DungeonData.new()
	for x in range(7):
		data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	var origin := Vector2i.ZERO
	var lane: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 4) == lane)
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 2) == lane.slice(0, 2))
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 0).is_empty())
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.LEFT, 4).is_empty())
	assert(PokemonProjectile.flight_path(data, origin, Vector2i(1, 1), 4).is_empty())
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.ZERO, 4).is_empty())
	assert(PokemonProjectile.flight_path(null, origin, Vector2i.RIGHT, 4).is_empty())
	var occupied := func(tile: Vector2i) -> bool: return tile == Vector2i(2, 0)
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 4, occupied) == lane.slice(0, 2))
	var adjacent := func(tile: Vector2i) -> bool: return tile == Vector2i(1, 0)
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 4, adjacent) == lane.slice(0, 1))
	data.set_tile(Vector2i(3, 0), DungeonData.TileType.FLOOR, 1) # Elevation change blocks flight.
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 4) == lane.slice(0, 2))
	data.set_tile(Vector2i(3, 0), DungeonData.TileType.WALL)
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 4) == lane.slice(0, 2))
	data.set_tile(Vector2i(1, 0), DungeonData.TileType.WALL)
	assert(PokemonProjectile.flight_path(data, origin, Vector2i.RIGHT, 4).is_empty())
	# Ramps allow flight along their axis only, like movement.
	var ramp := DungeonData.new()
	ramp.add_ramp(Vector2i.ZERO, Vector2i.RIGHT, 0)
	assert(PokemonProjectile.flight_path(ramp, origin, Vector2i.RIGHT, 4) == lane)
	assert(PokemonProjectile.flight_path(ramp, Vector2i(2, 0), Vector2i.DOWN, 4).is_empty())


func lane(main: Node3D, distances: Array, direction: Vector2i = Vector2i.RIGHT, wall_distance: int = -1) -> Skeleton:
	main.cancel_round()
	var data := DungeonData.new()
	for step in range(7):
		data.set_tile(direction * step, DungeonData.TileType.FLOOR)
	if wall_distance > 0:
		data.set_tile(direction * wall_distance, DungeonData.TileType.WALL)
	data.player_spawn = Vector2i.ZERO
	for distance in distances:
		data.enemy_spawns.append(direction * int(distance))
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data))
	main.spawn_test_enemies()
	for enemy in main.enemies:
		enemy.attack_policy = enemy.attack_policy.duplicate()
		enemy.attack_policy.move_probability = 0.0
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.player.facing = direction
	main.refresh_fog()
	return main.enemies[0] if not main.enemies.is_empty() else null


func projectiles(main: Node3D) -> int:
	var count := 0
	for child in main.entities.get_children():
		if child is ProjectileEffect and not child.is_queued_for_deletion():
			count += 1
	return count


func has_message(main: Node3D, text: String) -> bool:
	for entry in main.dialogue.history:
		if str(entry.message).contains(text):
			return true
	return false


func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func validate() -> void:
	validate_data()
	validate_path()
	for index in range(3):
		var main = load("res://scenes/main/main.tscn").instantiate()
		main.elemental_move_floor = 3 # Exercise normal progression independently of the testing default.
		main.use_elevation_test = true
		main.get_node("Player").species_data = load("res://config/species/%s.tres" % NAMES[index])
		main.get_node("Player/VisualController").profile = load("res://config/pokemon_%s.tres" % NAMES[index])
		root.add_child(main)
		Helper.complete_introduction(main)
		var player: Player = main.player
		var state: PokemonBattleState = player.battle_state
		var rounds: Array[int] = [0]
		main.round_finished.connect(func(): rounds[0] += 1)
		var unlock: PokemonMoveData = state.species.floor_unlock_move
		# Floors 1 and 2 keep two moves; entering floor 3 teaches the elemental move once.
		assert(main.elemental_move_floor == 3 and state.moves.size() == 2)
		main._on_stairs_reached()
		Helper.complete_introduction(main)
		assert(main.floor_number == 2 and state.moves.size() == 2 and not has_message(main, "learned"))
		main._on_stairs_reached()
		Helper.complete_introduction(main)
		assert(main.floor_number == 3 and state.moves.size() == 3 and state.moves[2] == unlock)
		assert(state.remaining_pp == [STARTING_PP[index][0], STARTING_PP[index][1], 10])
		assert(has_message(main, "%s learned %s!" % [player.character_visual.get_display_name(), UNLOCK_NAMES[index]]))
		assert(main.learned_move_pending == null and not player.transition_locked)
		assert(main.hud.move_panel.moves.size() == 3 and main.hud.move_panel.moves[2].move_name == UNLOCK_NAMES[index])
		assert(main.hud.move_panel.moves[2].attribute_name == TYPES[index] and main.hud.move_panel.moves[2].maximum_pp == 10)
		# Reloading a later floor neither re-teaches nor restores PP.
		state.remaining_pp[2] = 7
		main.load_test_floor()
		assert(state.moves.size() == 3 and state.remaining_pp[2] == 7)
		state.remaining_pp[2] = 10
		# O fires along the facing lane: the first enemy within four tiles is hit once.
		var enemy := lane(main, [3])
		var hp := player.health.current
		player._unhandled_input(key(KEY_O))
		assert(player.character_visual.clip == "Shoot" and player.character_visual.action == "Attack")
		assert(is_equal_approx(player.attack_leap.duration, player.character_visual.clips.Shoot.total))
		assert(player.attack_leap.active and main.resolving_turn and player.round_locked)
		assert(state.remaining_pp[2] == 9 and projectiles(main) == 1)
		# Species release poses are explicit; XML HitFrame describes charging.
		var release_time: float = player.character_visual.projectile_release_time()
		assert(is_equal_approx(release_time, (13.0 if index == 0 else 10.5) / 60.0))
		assert(player.get_node("PlayerSprite").alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED)
		for child in main.entities.get_children():
			if child is ProjectileEffect:
				assert(not child.visible)
				child.animation.pause()
				child.animation.custom_step(release_time - 0.001)
				assert(not child.visible)
				child.animation.custom_step(0.002)
				assert(child.visible)
		assert(enemy.health.current == 0 and has_message(main, "took 42 damage") and has_message(main, "used " + UNLOCK_NAMES[index]))
		player._unhandled_input(key(KEY_O)) # Locked presentation cannot double-spend.
		assert(state.remaining_pp[2] == 9)
		Helper.complete(main)
		assert(rounds[0] == 1 and main.enemies.is_empty() and main.enemy_occupancy.is_empty() and player.health.current == hp)
		# Ordering remains valid after Shoot ends, until flight/cancellation ends.
		assert(player.get_node("PlayerSprite").alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED)
		for child in main.entities.get_children():
			if child is ProjectileEffect:
				assert(child.get_child(0).render_priority < player.get_node("PlayerSprite").render_priority)
		main.cancel_round()
		await process_frame
		assert(projectiles(main) == 0)
		assert(player.get_node("PlayerSprite").alpha_cut == SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS)
		# Only the first enemy in the lane is hit; the one behind it is untouched.
		enemy = lane(main, [2, 4])
		var behind: Skeleton = main.enemies[1]
		assert(player.use_move(2))
		assert(enemy.health.current == 0 and behind.health.current == 42 and state.remaining_pp[2] == 8)
		Helper.complete(main)
		assert(main.enemies == [behind] and rounds[0] == 2)
		# Beyond four tiles: PP and a turn are spent, nothing is damaged.
		enemy = lane(main, [5])
		assert(player.use_move(2) and projectiles(main) == 1)
		Helper.complete(main)
		assert(enemy.health.current == 42 and state.remaining_pp[2] == 7 and rounds[0] == 3)
		assert(has_message(main, "But it had no effect."))
		# A wall in between stops the shot short of the enemy; it still flies the clear tile.
		enemy = lane(main, [3], Vector2i.RIGHT, 2)
		assert(player.use_move(2) and projectiles(main) == 1)
		Helper.complete(main)
		assert(enemy.health.current == 42 and state.remaining_pp[2] == 6 and rounds[0] == 4)
		# A wall directly ahead means no flight at all, but PP and the turn are still spent.
		enemy = lane(main, [3], Vector2i.RIGHT, 1)
		assert(player.use_move(2) and projectiles(main) == 0)
		Helper.complete(main)
		assert(enemy.health.current == 42 and state.remaining_pp[2] == 5 and rounds[0] == 5)
		# Adjacent, far-edge and every cardinal direction resolve through the same lane.
		for direction in DungeonData.CARDINALS:
			enemy = lane(main, [4 if direction.x != 0 else 1], direction)
			var before: int = state.remaining_pp[2]
			assert(player.use_move(2) and enemy.health.current == 0 and state.remaining_pp[2] == before - 1)
			var visual_offset: Vector3 = player.character_visual.projectile_visual_offset()
			if direction == Vector2i.DOWN:
				assert(visual_offset.is_equal_approx(Vector3(0, 0.4, 0.25)))
				assert(player.get_node("PlayerSprite").alpha_cut == SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS)
			else:
				assert(player.get_node("PlayerSprite").alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED)
				# Reconstruct the release pose and ensure origin is inside its visible
				# billboard bounds, rather than merely testing a configured height.
				var visual = player.character_visual
				var saved_time: float = visual.clip_time
				visual.clip_time = visual.projectile_release_time()
				visual.apply_frame()
				var sprite: Sprite3D = player.get_node("PlayerSprite")
				var camera: Camera3D = main.get_viewport().get_camera_3d()
				var point := player.global_position + visual_offset - sprite.global_position
				var rect := sprite.get_item_rect()
				var pixel := Vector2(point.dot(camera.global_basis.x) / sprite.pixel_size - rect.position.x, rect.end.y - point.dot(camera.global_basis.y) / sprite.pixel_size)
				assert(Rect2(sprite.texture.get_meta("pokemon_opaque_rect")).has_point(pixel))
				visual.clip_time = saved_time
				visual.apply_frame()
			for child in main.entities.get_children():
				if child is ProjectileEffect and not child.is_queued_for_deletion():
					assert(child.global_position.is_equal_approx(main.dungeon_renderer.get_entity_world_position(player.grid_position) + visual_offset))
					assert(child.sprite.render_priority == (5 if direction == Vector2i.DOWN else -1))
					assert(child.get_child(0).render_priority < player.get_node("PlayerSprite").render_priority)
			Helper.complete(main)
		# Zero PP rejects without a turn; the next Space is still the ordinary Attack.
		enemy = lane(main, [2])
		state.remaining_pp[2] = 0
		var before_rounds: int = rounds[0]
		assert(not player.use_move(2))
		player._unhandled_input(key(KEY_O))
		assert(enemy.health.current == 42 and not player.attack_leap.active and rounds[0] == before_rounds)
		player._unhandled_input(key(KEY_SPACE))
		assert(player.character_visual.clip == "Attack")
		Helper.complete(main)
		# Fresh runs forget the move and restore the two starting moves.
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(main.floor_number == 1 and state.moves.size() == 2 and state.remaining_pp == STARTING_PP[index])
		assert(main.hud.move_panel.moves.size() == 2)
		if index == 0:
			# The unlock floor is configurable per Main instance.
			main.elemental_move_floor = 2
			main._on_stairs_reached()
			Helper.complete_introduction(main)
			assert(main.floor_number == 2 and state.moves.size() == 3)
			main.elemental_move_floor = 3
			main.start_new_run()
			Helper.complete_introduction(main)
			assert(state.moves.size() == 2)
		# Boss arena: the shot crosses an empty tile and uses authored Drapion stats.
		main.game_mode = GameModeConfig.Mode.DEMO
		main.use_elevation_test = false
		main.floor_number = GameModeConfig.DEMO_FINAL_FLOOR
		main.load_test_floor()
		assert(state.moves.size() == 3 and state.remaining_pp[2] == 10)
		player.setup(main.boss.grid_position - Vector2i.RIGHT * 2, main.dungeon, main.dungeon_renderer)
		player.facing = Vector2i.RIGHT
		main.refresh_fog()
		assert(player.use_move(2) and main.boss.health.current == 92 - DRAPION_DAMAGE[index])
		assert(state.remaining_pp[2] == 9 and projectiles(main) == 1)
		Helper.complete(main)
		main.free()
		await process_frame
	print("PASS: starter types/STAB, elemental move data, floor-3 unlock once per run, projectile flight/blocking/first-target, O input/PP/turns, HUD and boss hits")
	quit()
