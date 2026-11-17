extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
func _initialize() -> void: call_deferred("validate")
func validate() -> void:
	var menu = load("res://scenes/ui/demo_start.tscn").instantiate()
	root.add_child(menu)
	assert(menu.choices.size() == 3)
	# Effect fixture configures Spiritomb directly; he is no longer a menu option.
	var main: Node3D = menu.GAMEPLAY.instantiate()
	main.get_node("Player").species_data = load("res://config/species/spiritomb.tres")
	main.get_node("Player/VisualController").profile = load("res://config/pokemon_spiritomb.tres")
	menu.gameplay = main
	menu.add_child(main)
	Helper.complete_introduction(main)
	var state: PokemonBattleState = main.player.battle_state
	assert(state.level == 20 and [state.health.maximum,state.attack,state.special_attack,state.defense,state.special_defense] == [120,32,32,49,50])
	assert(state.species.types == PackedStringArray(["Ghost","Dark"]))
	assert(state.moves.size() == 2 and state.remaining_pp == [20,20])
	assert(main.player.character_visual.profile.animations.OminousWind == "Charge")
	for name in ["Idle","Walk","Hurt","Attack","Charge","Shoot"]: assert(main.player.character_visual.clips.has(name))
	main.cancel_round()
	main.use_elevation_test = true
	var data := DungeonData.new()
	var room := Rect2i(-3,-4,24,9)
	data.rooms = [room]
	data.room_elevations = [0]
	for y in range(-4,5):
		for x in range(-3,21): data.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR)
	main.dungeon = data
	assert(main.dungeon_renderer.render_dungeon(data,true))
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
	var targets: Array[Skeleton] = []
	for tile in [Vector2i(2,0),Vector2i(-2,0),Vector2i(20,0)]:
		var enemy: Skeleton = main._spawn_regular_enemy(tile,load("res://scenes/enemies/tangela.tscn"))
		enemy.health.reset(10000)
		targets.append(enemy)
	main.refresh_fog()
	assert(main.player.use_move(0))
	assert(main.player.character_visual.clip == "Charge" and state.remaining_pp == [19,20])
	var wind: OminousWindEffect
	for child in main.entities.get_children():
		if child is OminousWindEffect: wind = child
	assert(wind != null and main.resolving_turn)
	assert(main.hud.layer > wind.layer.layer)
	assert(wind.material.get_shader_parameter("uv_scale").y < 1.0)
	wind.animation.pause()
	wind.animation.custom_step(0.999)
	assert(targets[0].health.current == 10000)
	wind.animation.custom_step(0.002)
	assert(targets[0].health.current < 10000 and targets[1].health.current < 10000)
	assert(targets[2].health.current == 10000)
	Helper.complete(main)
	for slot in [1]:
		main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
		targets[0].setup(Vector2i(2,0),data,main.dungeon_renderer)
		targets[0].health.reset(10000)
		main.enemy_occupancy.clear()
		for enemy in main.enemies: main.enemy_occupancy[enemy.grid_position] = enemy
		main.player.facing = Vector2i.RIGHT
		assert(main.player.use_move(slot))
		assert(main.player.character_visual.clip == "Shoot")
		var shot: ProjectileEffect
		for child in main.entities.get_children():
			if child is ProjectileEffect and not child.flight_completed: shot = child
		assert(shot != null and shot.spirit_move == state.moves[slot].move_id)
		assert(targets[0].health.current == 10000)
		assert(state.moves[slot].range_tiles == 4 and state.moves[slot].power == 6)
		assert(is_equal_approx(shot.sprite.pixel_size,0.0126))
		assert(shot.sheet_material.get_shader_parameter("camera_facing") == true)
		shot._set_sheet_time(0.1)
		assert(shot.sprite.frame == 0 and is_equal_approx(shot.sheet_material.get_shader_parameter("source_frame"),3.0))
		assert(shot.sheet_material.get_shader_parameter("stable_atlas"))
		shot.impact_pending = false
		shot._set_sheet_time(shot.spirit_travel_duration * 0.9)
		var opacity: float = shot.sheet_material.get_shader_parameter("fade_amount")
		assert(opacity > 0.0 and opacity < 1.0)
		shot.impact_pending = true
		Helper.complete(main)
		assert(targets[0].health.current < 10000 and not main.resolving_turn)
		assert(state.remaining_pp[slot] == 19)
	# Cancellation cannot apply pending screen damage or revive a round.
	main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
	var before: int = targets[0].health.current
	assert(main.player.use_move(0))
	main.cancel_round()
	assert(targets[0].health.current == before and not main.resolving_turn)
	assert(state.remaining_pp == [18,19])
	main.start_new_run()
	Helper.complete_introduction(main)
	assert(main.player.species_data.species_id == &"spiritomb" and state.remaining_pp == [20,20])
	menu.free()
	await process_frame
	print("PASS: bottom Spiritomb test selection/stats/native clips, screen-wide one-second wind, ranged shots/impacts, PP, delayed damage, cancellation and restart")
	quit()
