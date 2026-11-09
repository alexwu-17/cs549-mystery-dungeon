extends SceneTree

const HealthScript = preload("res://scripts/entities/health.gd")
const Helper = preload("res://tests/round_test_helper.gd")
var moves := 0

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	validate_health()
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	validate_movement(main)
	main.start_new_run()
	Helper.complete_introduction(main)
	validate_attack_input(main)
	main.free()
	await process_frame
	print("PASS: health boundaries/death, movement and blocked bumps, BFS/occupancy/stairs cleanup, Space facing/misses/hits/echo/release, kill/healing, death guards and R restart with live species")
	quit()

func validate_health() -> void:
	var health: HealthScript = HealthScript.new()
	var deaths: Array[int] = [0]
	health.died.connect(func(): deaths[0] += 1)
	health.reset(20)
	health.damage(-1)
	assert(health.current == 20)
	health.damage(4)
	assert(health.heal(3) == 3 and health.current == 19)
	assert(health.heal(3) == 1 and health.current == 20)
	health.damage(99)
	health.damage(99)
	assert(health.current == 0 and deaths[0] == 1 and health.heal(3) == 0)

func validate_movement(main: Node3D) -> void:
	main.turn_rng.seed = 1
	var data := DungeonData.new()
	for x in range(7):
		for y in range(3):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i(0, 1)
	data.enemy_spawns = [Vector2i(5, 1), Vector2i(6, 1)]
	data.stairs_position = Vector2i(0, 2)
	data.set_tile(data.stairs_position, DungeonData.TileType.STAIRS)
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	main.player.moved.connect(func(): moves += 1)
	var first: Skeleton = main.enemies[0]
	var second: Skeleton = main.enemies[1]
	main.turn_rng.seed = 1
	main.player.try_move(Vector2i.LEFT)
	Helper.complete_introduction(main)
	assert(moves == 0 and first.grid_position == Vector2i(5, 1))
	main.turn_rng.seed = 1
	main.player.try_move(Vector2i.RIGHT)
	Helper.complete_introduction(main)
	assert(moves == 1 and first.grid_position == Vector2i(4, 1))
	assert(second.grid_position == Vector2i(5, 1))
	main.turn_rng.seed = 1
	main.player.try_move(Vector2i.RIGHT)
	Helper.complete_introduction(main)
	assert(moves == 2 and first.grid_position == Vector2i(3, 1))
	main.turn_rng.seed = 1
	main.player.try_move(Vector2i.RIGHT)
	Helper.complete_introduction(main)
	assert(moves == 2 and main.player.grid_position == Vector2i(2, 1))
	assert(first.health.current == first.maximum_hp and main.player.health.current == main.player.maximum_hp)
	assert(first.grid_position == Vector2i(3, 1) and second.grid_position == Vector2i(4, 1))
	main.turn_rng.seed = 1
	main.player.try_move(Vector2i.DOWN)
	Helper.complete_introduction(main)
	Helper.complete(main)
	assert(moves == 3)
	assert(main.enemy_occupancy.size() == 2)
	for enemy: Skeleton in main.enemies:
		assert(enemy.grid_position != main.player.grid_position)
		assert(main.enemy_occupancy[enemy.grid_position] == enemy)
		assert(enemy.position.is_equal_approx(main.dungeon_renderer.get_entity_world_position(enemy.grid_position)))
	# A detour must go around missing terrain, even when it initially leads away.
	var detour := DungeonData.new()
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)]:
		detour.set_tile(tile, DungeonData.TileType.FLOOR)
	main.dungeon_renderer.render_dungeon(detour)
	first.setup(Vector2i.ZERO, detour, main.dungeon_renderer)
	assert(first.next_step_toward(Vector2i(2, 0), {}) == Vector2i(0, 1))
	assert(first.next_step_toward(Vector2i(2, 0), {Vector2i(0, 1): second}) == Vector2i.ZERO)
	assert(first.next_step_toward(Vector2i(9, 9), {}) == Vector2i.ZERO)
	first.take_turn(Vector2i(0, 1), {})
	assert(first.grid_position == Vector2i.ZERO)
	# Stairs must free old enemies and skip the movement/enemy-phase signal.
	main.dungeon_renderer.render_dungeon(data)
	main.player.setup(Vector2i(0, 1), data, main.dungeon_renderer)
	var old_first: WeakRef = weakref(first)
	var old_second: WeakRef = weakref(second)
	main.turn_rng.seed = 1
	main.player.try_move(Vector2i.DOWN)
	Helper.complete_introduction(main)
	Helper.complete(main)
	assert(moves == 3)
	assert(old_first.get_ref() == null and old_second.get_ref() == null)
	assert(main.enemy_occupancy.size() == main.enemies.size())
	for enemy: Skeleton in main.enemies:
		assert(enemy.dungeon_data == main.dungeon)
		assert(enemy.grid_position in main.dungeon.enemy_spawns)
		assert(main.enemy_occupancy[enemy.grid_position] == enemy)

func validate_attack_input(main: Node3D) -> void:
	var data := DungeonData.new()
	for x in range(6):
		data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i(5, 0)]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(data.player_spawn, data, main.dungeon_renderer)
	var enemy: Skeleton = main.enemies[0]
	for invalid in [Vector2i(1, 1), Vector2i(-2, 0)]:
		main.player.try_move(invalid)
	assert(main.player.grid_position == Vector2i.ZERO and enemy.grid_position == Vector2i(5, 0))
	# A deliberately two-hit enemy makes kill bookkeeping fast without replacing
	# production species configuration or baking in old HP6/player HP20.
	# Keep its counterattack basic here; selection/PP has a dedicated owner.
	enemy.attack_policy = enemy.attack_policy.duplicate()
	enemy.attack_policy.move_probability = 0.0
	var damage := PokemonDamage.basic_damage(main.player.battle_state, enemy.battle_state)
	var enemy_damage := PokemonDamage.basic_damage(enemy.battle_state, main.player.battle_state)
	enemy.health.reset(damage * 2)
	var maximum: int = main.player.maximum_hp
	var before_hit: int = enemy.health.current
	var requests: Array[int] = [0]
	main.player.attack_requested.connect(func(_target: Vector2i): requests[0] += 1)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	assert(space.is_action_pressed("basic_attack"))
	assert(main.player.facing == Vector2i.DOWN)
	# Default-facing wall miss consumes exactly one phase without moving player.
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(requests[0] == 1 and enemy.grid_position == Vector2i(4, 0))
	assert(main.player.grid_position == Vector2i.ZERO)
	space.echo = true
	main.player._unhandled_input(space)
	Helper.complete(main)
	space.echo = false
	space.pressed = false
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(requests[0] == 1 and enemy.grid_position == Vector2i(4, 0))
	space.pressed = true
	main.player.try_move(Vector2i.UP)
	Helper.complete_introduction(main)
	assert(main.player.facing == Vector2i.UP and enemy.grid_position == Vector2i(4, 0))
	main.player.facing = Vector2i.RIGHT
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(requests[0] == 2 and enemy.grid_position == Vector2i(3, 0))
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(enemy.grid_position == Vector2i(2, 0))
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(enemy.grid_position == Vector2i(1, 0) and main.player.health.current == maximum)
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(enemy.health.current == before_hit - damage and main.player.health.current == maximum - enemy_damage)
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(main.enemies.is_empty() and main.enemy_occupancy.is_empty())
	var after_kill := mini(maximum, maximum - enemy_damage + main.healing_on_kill)
	assert(main.player.health.current == after_kill and main.player.grid_position == Vector2i.ZERO)
	main.loading_floor = true
	main.player._unhandled_input(space)
	Helper.complete(main)
	assert(main.player.health.current == after_kill and main.enemies.is_empty())
	main.loading_floor = false
	main.spawn_test_enemies()
	var old_enemy: WeakRef = weakref(main.enemies[0])
	main.player.receive_damage(main.player.health.current)
	var before := requests[0]
	main.player._unhandled_input(space)
	Helper.complete(main)
	main.player.try_move(Vector2i.RIGHT)
	assert(main.game_over and requests[0] == before and main.player.grid_position == Vector2i.ZERO)
	var restart := InputEventKey.new()
	restart.physical_keycode = KEY_R
	restart.pressed = true
	main._unhandled_input(restart)
	Helper.complete_introduction(main)
	assert(main.player.facing == Vector2i.DOWN and main.player.health.current == maximum)
	assert(old_enemy.get_ref() == null)
