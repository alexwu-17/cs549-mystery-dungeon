extends Node3D

const TEST_ENEMY_SCENE := preload("res://scenes/enemies/test_enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/minotaur.tscn")

@export var dungeon_name: String = "Assignment 5 Cave"
@export var floor_subtitles: Dictionary = {}
@export_range(0.0, 10.0, 0.05) var final_floor_text_hold_duration: float = 1.0
var transition_generation: int = 0
@onready var floor_introduction: FloorIntroduction = $HUD/Screen/FloorIntroduction

@export var use_elevation_test: bool = false
@export var game_mode: GameModeConfig.Mode = GameModeConfig.Mode.INFINITE
@export var generation_config: DungeonGenerationConfig
@export var benchmark_enabled: bool = false
var benchmark: LimitBenchmark

@onready var dungeon_renderer: DungeonRenderer = $DungeonRenderer
@onready var player: Player = $Player
@onready var entities: Node3D = $Entities
@onready var dialogue: CombatDialogue = $HUD/Screen/CombatDialogue
@onready var hud = $HUD
@onready var presentation_camera = $Camera3D

var dungeon: DungeonData
var enemies: Array[Skeleton] = []
var retiring_enemies: Array[Skeleton] = []
var enemy_occupancy: Dictionary = {}
var game_over: bool = false
var victory: bool = false
var boss: Minotaur
signal enemy_action_started(enemy: Node3D)
signal round_finished
var round_generation: int = 0
var turn_rng := RandomNumberGenerator.new()
var resolving_turn: bool = false
var loading_floor: bool = false
# Only the player/floor determines terrain fog; actors still refresh every action.
var _fog_context: Array = []
var floor_number: int = 1
@export var healing_on_kill: int = 0 # Legacy fixture override; production uses peaceful recovery.
@export_range(1, 100) var recovery_turns_per_hp: int = 5
@export_range(1, 100) var recovery_initial_turns: int = 15
var peaceful_turns: int = 0
var recovery_started: bool = false
var recovery_damage_serial: int = 0
@export var enemy_respawn_enabled: bool = true
@export_range(1, 100) var enemy_respawn_delay: int = 100
var repopulation := EnemyRepopulation.new()
## First floor on which the starter learns its species' floor_unlock_move, once per run.
@export_range(1, 99) var elemental_move_floor: int = 1 # Testing: restore to 3 for normal progression.
var learned_move_pending: PokemonMoveData


func _ready() -> void:
	# Running the Demo scene directly must use the same entry flow as the project.
	# A selected run is a child of the menu, so it never takes this redirect.
	if game_mode == GameModeConfig.Mode.DEMO and get_tree().current_scene == self:
		set_process(false)
		set_process_unhandled_input(false)
		player.gameplay_enabled = false
		hud.hide()
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/demo_start.tscn")
		return
	dialogue.character_name_provider = _player_display_name
	dialogue.enemy_name_provider = _boss_display_name
	turn_rng.randomize()
	player.movement_speed_changed.connect(_set_action_speed)
	player.stairs_reached.connect(_on_stairs_reached)
	player.moved.connect(_on_player_moved)
	player.waited.connect(_on_player_waited)
	player.health.damaged.connect(_on_recovery_damage)
	_watch_stat_changes(player)
	player.attack_requested.connect(_on_player_attack)
	player.move_requested.connect(_on_player_attack)
	player.health.died.connect(_on_player_died)
	player.is_tile_occupied = is_enemy_occupied
	player.can_request_attack = _can_player_attack
	player.can_request_wait = _can_player_wait
	hud.bind_health(player.health)
	hud.bind_battle_state(player.battle_state)
	hud.damage_numbers.watch(player, player.character_visual, player.health)
	if game_mode == GameModeConfig.Mode.LIMIT_TESTING:
		LimitBenchmark.apply_cap(self)
	if game_mode == GameModeConfig.Mode.LIMIT_TESTING and benchmark_enabled and not use_elevation_test:
		benchmark = LimitBenchmark.new()
		hud.get_node("Screen").add_child(benchmark)
		hud.get_node("Screen").move_child(benchmark, floor_introduction.get_index())
		benchmark.initialize(self)
	start_new_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		start_new_run()
		get_viewport().set_input_as_handled()


func start_new_run() -> void:
	hud.damage_numbers.clear()
	cancel_introduction()
	if benchmark != null:
		benchmark.prepare()
	MusicManager.claim(self)
	MusicManager.play_dungeon(self, true)
	player.transition_locked = true
	floor_introduction.cover_immediately()
	cancel_round()
	dialogue.clear_history()
	game_over = false
	victory = false
	hud.set_game_over(false)
	resolving_turn = false
	player.gameplay_enabled = true
	player.facing = Vector2i.DOWN
	floor_number = 1
	learned_move_pending = null
	player.reset_battle_state()
	print("NEW RUN: PLAYER HP ", player.health.current, "/", player.health.maximum)
	_begin_floor_introduction(false)


func _process(_delta: float) -> void:
	update_presentation()


func update_presentation() -> void:
	presentation_camera.follow_sprite(player.get_node("PlayerSprite"))
	player.character_visual.clear_ramp_intersection(presentation_camera, player.dungeon_data, player.grid_position, player.attack_leap)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.character_visual.clear_ramp_intersection(presentation_camera, enemy.dungeon_data, enemy.grid_position, enemy.attack_leap)
	for enemy in retiring_enemies:
		if is_instance_valid(enemy):
			enemy.character_visual.clear_ramp_intersection(presentation_camera, enemy.dungeon_data, enemy.grid_position, enemy.attack_leap)
	if is_instance_valid(boss):
		boss.character_visual.clear_ramp_intersection(presentation_camera, boss.dungeon_data, boss.grid_position, boss.sprite_clearance)
	var visibility_anchor := dungeon_renderer.get_entity_world_position(player.grid_position)
	dungeon_renderer.update_visibility_center(visibility_anchor)
	# Attack frames may lunge through walls: retain the resting occlusion state.
	if not player.attack_leap.active:
		var points: Array[Vector3] = presentation_camera.sprite_samples(player.get_node("PlayerSprite"))
		for index in range(points.size()):
			points[index] += visibility_anchor - player.global_position
		dungeon_renderer.update_occlusion(presentation_camera, player.grid_position, points, true)


func load_test_floor() -> void:
	player.battle_state.reset_stages()
	for child in player.get_children():
		if child is StatChangeEffect: child.free()
	hud.damage_numbers.clear()
	cancel_round()
	player.invincible = game_mode == GameModeConfig.Mode.LIMIT_TESTING and generation_config != null and generation_config.invincible_player
	loading_floor = true
	player.gameplay_enabled = false
	if use_elevation_test:
		dungeon = TestDungeonFactory.create_elevation_test_dungeon()
	elif benchmark != null:
		dungeon = benchmark.create_floor()
	elif GameModeConfig.is_arena(game_mode, floor_number):
		dungeon = DemoArenaFactory.create_arena()
	elif game_mode == GameModeConfig.Mode.LIMIT_TESTING:
		if generation_config == null:
			push_error("Limit Testing requires a generation configuration.")
			return
		dungeon = TestDungeonFactory.create_configured_dungeon(generation_config)
		if dungeon == null:
			# Invalid experiments remain stopped; do not silently use defaults.
			return
	else:
		# Null uses the shared standard Resource; Inspector overrides also work in
		# Infinite/Demo, e.g. the optional legacy three-elevation configuration.
		dungeon = TestDungeonFactory.create_test_dungeon() if generation_config == null else TestDungeonFactory.create_configured_dungeon(generation_config)
		if dungeon == null: return
		print("ELEVATION FLOOR: ", TestDungeonFactory.last_statistics, " | room heights=", dungeon.room_elevations, " | ramps=", dungeon.ramp_segments)

	if not dungeon_renderer.render_dungeon(dungeon, use_elevation_test or benchmark != null or GameModeConfig.is_arena(game_mode, floor_number)):
		# Keep the existing introduction/input lock authoritative if visual structure
		# cannot be validated even after the structure-only fallback.
		push_error("Floor presentation blocked by unresolved environmental geometry.")
		return
	spawn_test_enemies()

	player.setup(
		dungeon.player_spawn,
		dungeon,
		dungeon_renderer
	)

	print("Player grid position after setup: ", player.grid_position)
	print("Player world position after setup: ", player.position)
	_teach_floor_move()
	refresh_fog()
	loading_floor = false
	player.gameplay_enabled = not game_over and not victory
	
func _teach_floor_move() -> void:
	# Gameplay-authoritative: whenever a floor at or past the unlock floor loads,
	# the starter knows its elemental move. Fresh runs reset moves, so it repeats per run.
	var species := player.battle_state.species
	if species == null or species.floor_unlock_move == null or floor_number < elemental_move_floor:
		return
	if player.battle_state.learn_move(species.floor_unlock_move):
		learned_move_pending = species.floor_unlock_move
		print("MOVE LEARNED: ", species.floor_unlock_move.display_name)


func _on_stairs_reached() -> void:
	if player.transition_locked or game_over or victory or loading_floor or not GameModeConfig.can_advance(game_mode, floor_number):
		return
	if benchmark != null:
		run_enemy_turn() # The fixture stays on one floor; no transition resets.
		return
	_begin_floor_introduction(true)

func spawn_test_enemies() -> void:
	repopulation.reset()
	# Remove enemies from the previous floor.
	if is_instance_valid(boss):
		boss.free()
	boss = null
	enemy_occupancy.clear()
	for enemy in enemies:
		enemy.free()
	enemies.clear()

	for spawn_position: Vector2i in dungeon.enemy_spawns:
		_spawn_regular_enemy(spawn_position)
	if game_mode == GameModeConfig.Mode.DEMO and floor_number == GameModeConfig.DEMO_FINAL_FLOOR and not use_elevation_test:
		boss = BOSS_SCENE.instantiate()
		entities.add_child(boss)
		boss.setup(DemoArenaFactory.BOSS_CENTER, dungeon, dungeon_renderer)
		boss.attack_requested.connect(_on_enemy_attack.bind(boss))
		hud.damage_numbers.watch(boss, boss.character_visual, boss.health)
		boss.presentation_event.connect(_on_boss_message)
		boss.defeated.connect(_on_boss_defeated)
		_watch_stat_changes(boss)


func _spawn_regular_enemy(tile: Vector2i) -> void:
	var enemy: Skeleton = TEST_ENEMY_SCENE.instantiate()
	enemy.add_to_group("test_enemies")
	entities.add_child(enemy)
	enemy.setup(tile, dungeon, dungeon_renderer)
	enemy.attack_requested.connect(_on_enemy_attack.bind(enemy))
	hud.damage_numbers.watch(enemy, enemy.character_visual, enemy.health)
	enemies.append(enemy)
	enemy_occupancy[tile] = enemy
	_watch_stat_changes(enemy)


func _watch_stat_changes(actor: Node3D) -> void:
	actor.battle_state.stage_changed.connect(_on_stage_changed.bind(weakref(actor)))
	actor.battle_state.stats_restored.connect(_on_stats_restored.bind(weakref(actor)))
	actor.battle_state.stage_duration_refreshed.connect(_on_stats_refreshed.bind(weakref(actor)))


func _on_stats_refreshed(actor_ref: WeakRef) -> void:
	var actor: Node3D = actor_ref.get_ref()
	if actor != null and actor.is_inside_tree():
		dialogue.append_event(&"stats_refreshed", {"actor": actor.character_visual.get_display_name()})


func _on_stage_changed(stat: StringName, amount: int, actor_ref: WeakRef) -> void:
	var actor: Node3D = actor_ref.get_ref()
	if actor != null and actor.is_inside_tree():
		StatChangeEffect.play_above_actor(actor, amount > 0)
		var names := {&"attack": "Attack", &"defense": "Defense", &"special_attack": "Special Attack", &"special_defense": "Special Defense"}
		dialogue.append_event(&"stat_changed", {"actor": actor.character_visual.get_display_name(), "stat": names[stat], "direction": "increased" if amount > 0 else "reduced"})


func _on_stats_restored(actor_ref: WeakRef) -> void:
	var actor: Node3D = actor_ref.get_ref()
	if actor != null and actor.is_inside_tree() and actor.health.current > 0:
		dialogue.append_event(&"stats_restored", {"actor": actor.character_visual.get_display_name()})


func _advance_repopulation() -> void:
	if not enemy_respawn_enabled or use_elevation_test or benchmark != null or GameModeConfig.is_arena(game_mode, floor_number):
		return
	if not repopulation.advance(not enemies.is_empty() or is_instance_valid(boss), enemy_respawn_delay):
		return
	var tile: Variant = repopulation.choose(dungeon, player.grid_position, enemy_occupancy)
	if tile == null:
		push_warning("Enemy respawn deferred: no hidden reachable room outside the player's area; retry in %d turns." % enemy_respawn_delay)
		return
	_spawn_regular_enemy(tile)
	refresh_entity_visibility()


func is_enemy_occupied(tile: Vector2i) -> bool:
	return enemy_occupancy.has(tile) or (is_instance_valid(boss) and boss.occupies(tile))


func _on_player_moved() -> void:
	run_enemy_turn(true)


func _on_player_waited() -> void:
	run_enemy_turn(true)


func _on_recovery_damage(_amount: int) -> void:
	_reset_recovery()
	recovery_damage_serial += 1
	if player.held_action == &"wait_turn": player.stop_held_movement()


func _reset_recovery() -> void:
	peaceful_turns = 0
	recovery_started = false


func _can_player_wait() -> bool:
	# Round locks are checked by Player; this predicate also runs during enemy phases.
	if player.transition_locked or game_over or victory or loading_floor:
		return false
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health.current > 0 and dungeon.is_bright(enemy.grid_position):
			return false
	if is_instance_valid(boss) and boss.health.current > 0:
		for tile in boss.footprint():
			if dungeon.is_bright(tile): return false
	return true


func _can_player_attack() -> bool:
	return not (player.transition_locked or game_over or victory or resolving_turn or loading_floor)


func _player_attack_damage(defender: PokemonBattleState, move: PokemonMoveData) -> int:
	if move != null:
		return PokemonDamage.move_damage(player.battle_state, defender, move)
	return PokemonDamage.basic_damage(player.battle_state, defender, player.attack_damage)


func _on_player_attack(target: Vector2i, move: PokemonMoveData = null) -> void:
	if not _can_player_attack():
		return
	_reset_recovery()
	if move != null:
		dialogue.append_event(&"move_used", {"actor": _player_display_name(), "move": move.display_name})
	if move != null and move.category == PokemonMoveData.Category.STATUS:
		var actors: Array[Node3D] = []
		actors.assign(enemies)
		if is_instance_valid(boss): actors.append(boss)
		var previous_sequence: int = dialogue.sequence
		if PokemonStatusMoves.apply(player, dungeon, target, actors, move).is_empty() and dialogue.sequence == previous_sequence:
			dialogue.append_event(&"no_effect")
		run_enemy_turn()
		return
	var delta := target - player.grid_position
	if absi(delta.x) + absi(delta.y) != 1:
		return
	var reachable := dungeon.can_traverse(player.grid_position, target)
	if move != null and move.targeting == PokemonMoveData.Targeting.STRAIGHT_PROJECTILE:
		# Flight follows authoritative traversal; the last tile is the first occupant or the last clear tile.
		var path := PokemonProjectile.flight_path(dungeon, player.grid_position, delta, move.range_tiles, is_enemy_occupied)
		reachable = not path.is_empty()
		if reachable:
			target = path.back()
			# Translate the visual lane only; targeting and tile-based travel time stay authoritative.
			var offset := player.character_visual.projectile_visual_offset() - Vector3.UP * ProjectileEffect.BODY_HEIGHT
			var projectile := ProjectileEffect.launch(entities, dungeon_renderer.get_entity_world_position(player.grid_position) + offset, dungeon_renderer.get_entity_world_position(target) + offset, move.move_type, player.attack_leap.action_speed, player.character_visual.projectile_release_time(), move.move_id)
			player.layer_over_projectile(projectile)
	if reachable and is_instance_valid(boss) and boss.occupies(target):
		print("PLAYER ATTACK MINOTAUR at ", target)
		var damage := _player_attack_damage(boss.battle_state, move)
		dialogue.append_event(&"damage" if move != null else &"attack", {"actor": _player_display_name(), "target": _boss_display_name(), "amount": mini(damage, boss.health.current)})
		boss.receive_damage(damage)
		if not victory:
			run_enemy_turn()
		else:
			refresh_fog()
		return
	if not reachable or not enemy_occupancy.has(target):
		print("PLAYER ATTACK MISSED at ", target)
		if move != null: dialogue.append_event(&"no_effect")
		run_enemy_turn()
		return
	var enemy: Skeleton = enemy_occupancy[target]
	var damage := _player_attack_damage(enemy.battle_state, move)
	print("PLAYER ATTACK at ", target, ": ", damage)
	dialogue.append_event(&"damage" if move != null else &"attack", {"actor": _player_display_name(), "target": enemy.character_visual.get_display_name(), "amount": mini(damage, enemy.health.current)})
	enemy.receive_damage(damage)
	if enemy.health.current == 0:
		dialogue.append_event(&"defeat", {"target": enemy.character_visual.get_display_name()})
		print("SKELETON DIED at ", target)
		enemy_occupancy.erase(target)
		enemies.erase(enemy)
		if enemies.is_empty(): repopulation.cleared()
		_retire_enemy(enemy)
		var healed: int = player.health.heal(healing_on_kill)
		if healed > 0:
			dialogue.append_event(&"heal", {"amount": healed})
		print("HEALED ", healed, ": PLAYER HP ", player.health.current, "/", player.health.maximum)
	run_enemy_turn()


func _on_player_died() -> void:
	# Finish the player's presentation, but let the lethal skeleton's leap play
	# beneath the immediate overlay. Floor replacement frees enemy animations.
	player.stop_held_movement()
	game_over = true
	MusicManager.stop_music(self)
	player.gameplay_enabled = false
	cancel_introduction()
	dialogue.append_event(&"game_over")
	player.attack_leap.finish()
	if is_instance_valid(boss) and boss.character_visual.active:
		var token := round_generation
		await boss.complete_action()
		if token != round_generation or not game_over or not is_instance_valid(boss) or boss.character_visual.disposed:
			return
	hud.set_game_over(true)
	player.gameplay_enabled = false
	print("PLAYER DIED. GAME OVER. Press R to restart.")


func _on_boss_defeated() -> void:
	if game_mode != GameModeConfig.Mode.DEMO:
		return
	victory = true
	MusicManager.stop_music(self)
	cancel_introduction()
	cancel_round(true) # Let the finishing player attack complete beneath the faint effect.
	player.gameplay_enabled = false
	var defeated_boss: Minotaur = boss
	var token := round_generation
	defeated_boss.character_visual.defeat()
	if defeated_boss.character_visual.defeating:
		await defeated_boss.character_visual.defeat_finished
	if token != round_generation or not victory or not is_instance_valid(defeated_boss) or boss != defeated_boss or defeated_boss.character_visual.disposed or not defeated_boss.character_visual.defeat_completed:
		return
	await player.complete_action()
	if token != round_generation or not victory or not is_instance_valid(defeated_boss) or boss != defeated_boss or defeated_boss.character_visual.disposed:
		return
	defeated_boss.hide()
	hud.minimap.refresh_boss(defeated_boss)
	dialogue.append_event(&"victory")
	hud.set_victory(_boss_display_name())
	print("VICTORY: Minotaur defeated. Press R to restart the demo.")


func cancel_round(preserve_player_presentation: bool = false) -> void:
	_reset_recovery()
	repopulation.reset()
	_clear_retiring_enemies()
	player.stop_held_movement()
	# Invalidate before emitting completion signals: old continuations must stop.
	dialogue.abandon_round()
	round_generation += 1
	resolving_turn = false
	player.round_locked = false
	if not preserve_player_presentation:
		player.attack_leap.finish()
		_clear_projectiles()
	if is_instance_valid(boss):
		boss.character_visual.cancel()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.attack_leap.finish()


func _clear_projectiles() -> void:
	for child in entities.get_children():
		if child is ProjectileEffect:
			child.finish()


func _exit_tree() -> void:
	LimitBenchmark.restore_cap(self)
	MusicManager.release(self)
	cancel_introduction()
	cancel_round()


func run_enemy_turn(peaceful: bool = false) -> void:
	if player.transition_locked or game_over or victory or resolving_turn or loading_floor:
		return
	resolving_turn = true
	if not peaceful: _reset_recovery()
	var damage_serial := recovery_damage_serial
	player.round_locked = true
	var token := round_generation
	refresh_turn_visibility()
	await player.complete_action()
	if token != round_generation:
		return
	var order: Array[Node3D] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health.current > 0:
			order.append(enemy)
	if is_instance_valid(boss) and boss.health.current > 0:
		order.append(boss)
	# Fisher-Yates uses independent randomness, not the generator's global RNG.
	for index in range(order.size() - 1, 0, -1):
		var other := turn_rng.randi_range(0, index)
		var temporary := order[index]
		order[index] = order[other]
		order[other] = temporary
	for actor in order:
		if token != round_generation or game_over or victory or loading_floor:
			break
		if not is_instance_valid(actor) or actor.health.current == 0:
			continue
		if actor is Skeleton:
			actor.attack_leap.action_speed = player.movement_speed
		actor.character_visual.action_speed = player.movement_speed
		enemy_action_started.emit(actor)
		if token != round_generation or game_over or victory:
			break
		if actor is Skeleton:
			var previous: Vector2i = actor.grid_position
			actor.take_turn(player.grid_position, enemy_occupancy)
			if token != round_generation:
				return
			enemy_occupancy.erase(previous)
			enemy_occupancy[actor.grid_position] = actor
		else:
			actor.take_turn(player.grid_position)
		if token != round_generation:
			return
		refresh_turn_visibility()
		await actor.complete_action()
		if token != round_generation or not is_instance_valid(actor) or actor.character_visual.disposed:
			return
	if token != round_generation:
		return
	if peaceful and damage_serial == recovery_damage_serial and not game_over and not victory and not loading_floor:
		peaceful_turns += 1
		var threshold := recovery_turns_per_hp if recovery_started else recovery_initial_turns
		if peaceful_turns >= threshold:
			peaceful_turns = 0
			recovery_started = true
			var healed := player.health.heal(1)
			if healed > 0: dialogue.append_event(&"heal", {"amount": healed})
	if not game_over and not victory and not loading_floor:
		player.battle_state.finish_stage_turn()
		if token != round_generation: return
		for enemy in enemies.duplicate():
			if is_instance_valid(enemy) and enemy.health.current > 0: enemy.battle_state.finish_stage_turn()
			if token != round_generation: return
		if is_instance_valid(boss) and boss.health.current > 0: boss.battle_state.finish_stage_turn()
		if token != round_generation: return
		_advance_repopulation()
	if token != round_generation: return
	resolving_turn = false
	player.round_locked = false
	if not game_over and not victory:
		dialogue.end_round()
	round_finished.emit()


func refresh_fog() -> void:
	dungeon.update_fog(player.grid_position)
	dungeon_renderer.apply_fog(player.fog_elevation)
	_fog_context = [dungeon.get_instance_id(), player.grid_position, player.fog_elevation]
	refresh_entity_visibility()
	update_presentation()


func refresh_turn_visibility() -> void:
	if _fog_context != [dungeon.get_instance_id(), player.grid_position, player.fog_elevation]:
		refresh_fog()
	else:
		refresh_entity_visibility()
		update_presentation()


func refresh_entity_visibility() -> void:
	for enemy in retiring_enemies:
		if is_instance_valid(enemy): enemy.visible = dungeon.is_bright(enemy.grid_position)
	for enemy in enemies:
		enemy.visible = dungeon.is_bright(enemy.grid_position)
	if is_instance_valid(boss) and boss.state != Minotaur.State.DEAD:
		boss.refresh_visibility()
	hud.refresh_map(dungeon, player.grid_position, enemies, floor_number)
	hud.minimap.refresh_boss(boss)
	if player.held_action == &"wait_turn" and not _can_player_wait():
		player.stop_held_movement()


func _on_enemy_attack(amount: int, actor: Node3D) -> void:
	var move: PokemonMoveData = actor.active_attack_move
	amount = PokemonDamage.move_damage(actor.battle_state, player.battle_state, move) if move != null else PokemonDamage.basic_damage(actor.battle_state, player.battle_state, amount)
	var visual: CharacterVisual = actor.get("character_visual")
	if move != null and not actor is Minotaur:
		dialogue.append_event(&"move_used", {"actor": visual.get_display_name(), "move": move.display_name})
	dialogue.append_event(&"damage" if move != null else &"attack", {"actor": visual.get_display_name(), "target": _player_display_name(), "amount": 0 if player.invincible else mini(amount, player.health.current)})
	player.receive_damage(amount)


func _on_boss_message(kind: StringName) -> void:
	if kind == &"move_used":
		dialogue.append_event(kind, {"actor": _boss_display_name(), "move": boss.active_attack_move.display_name})
		return
	dialogue.append_event(kind)


func cancel_introduction() -> void:
	transition_generation += 1
	floor_introduction.cancel()
	floor_introduction.hide()


func _begin_floor_introduction(advancing: bool) -> void:
	player.transition_locked = true
	if advancing and game_mode == GameModeConfig.Mode.DEMO and floor_number == GameModeConfig.DEMO_FINAL_FLOOR - 1 and not use_elevation_test:
		MusicManager.stop_music(self)
	cancel_round()
	var token := transition_generation
	if advancing:
		await floor_introduction.fade_to_black()
		if token != transition_generation or floor_introduction.disposed:
			return
		floor_number += 1
	load_test_floor()
	if token != transition_generation or loading_floor:
		return
	var hold_override := final_floor_text_hold_duration if GameModeConfig.is_arena(game_mode, floor_number) and not use_elevation_test else -1.0
	await floor_introduction.reveal(dungeon_name, floor_number, str(floor_subtitles.get(floor_number, "")), hold_override)
	if token != transition_generation or floor_introduction.disposed or game_over or victory:
		return
	# reveal() returns after the final fade and introduction_finished emission.
	if GameModeConfig.is_arena(game_mode, floor_number) and not use_elevation_test:
		MusicManager.play_boss(self)
	if learned_move_pending != null:
		dialogue.append_event(&"move_learned", {"move": learned_move_pending.display_name})
		learned_move_pending = null
	player.transition_locked = false


func _set_action_speed(speed: float) -> void:
	player.attack_leap.action_speed = speed
	player.character_visual.action_speed = speed
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.attack_leap.action_speed = speed
			enemy.character_visual.action_speed = speed
	if is_instance_valid(boss):
		boss.character_visual.action_speed = speed


func _retire_enemy(enemy: Skeleton) -> void:
	retiring_enemies.append(enemy)
	if enemy.character_visual.defeating:
		await enemy.character_visual.defeat_finished
	if not is_instance_valid(enemy) or not retiring_enemies.has(enemy): return
	retiring_enemies.erase(enemy)
	if enemy.character_visual.disposed: return
	entities.remove_child(enemy)
	enemy.queue_free()

func _clear_retiring_enemies() -> void:
	var retired := retiring_enemies.duplicate()
	retiring_enemies.clear() # Invalidate before freeing nodes emits completion signals.
	for enemy in retired:
		if is_instance_valid(enemy): enemy.free()


func _player_display_name() -> String:
	return player.character_visual.get_display_name()

func _boss_display_name() -> String:
	return boss.character_visual.get_display_name() if is_instance_valid(boss) else "Boss"
