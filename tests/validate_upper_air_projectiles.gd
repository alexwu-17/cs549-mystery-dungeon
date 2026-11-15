extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var data := DungeonData.new()
	data.set_tile(Vector2i.ZERO,DungeonData.TileType.FLOOR,1)
	var plan := PokemonProjectile.flight_plan(data,Vector2i.ZERO,Vector2i.RIGHT,4,Callable(),true)
	assert(plan.path.size()==4 and plan.path.back()==Vector2i(4,0) and plan.air_extension and not plan.hits_actor)
	assert(PokemonProjectile.flight_path(data,Vector2i.ZERO,Vector2i.RIGHT,4).is_empty())
	assert(PokemonProjectile.flight_plan(data,Vector2i.ZERO,Vector2i.RIGHT,4).path.is_empty())
	data.set_tile(Vector2i(2,0),DungeonData.TileType.FLOOR,0)
	data.set_tile(Vector2i(4,0),DungeonData.TileType.FLOOR,1)
	var occupied := func(tile: Vector2i) -> bool: return tile in [Vector2i(2,0),Vector2i(4,0)]
	plan = PokemonProjectile.flight_plan(data,Vector2i.ZERO,Vector2i.RIGHT,4,occupied,true)
	assert(plan.path.size()==4 and plan.hits_actor) # Ignore lower target; hit the upper one.
	data.set_tile(Vector2i(3,0),DungeonData.TileType.WALL)
	plan = PokemonProjectile.flight_plan(data,Vector2i.ZERO,Vector2i.RIGHT,4,occupied,true)
	assert(plan.path.size()==2 and not plan.hits_actor) # Lower target is not a hit endpoint.
	data.set_tile(Vector2i(3,0),DungeonData.TileType.RAMP,1)
	assert(PokemonProjectile.flight_plan(data,Vector2i.ZERO,Vector2i.RIGHT,4,occupied,true).path.size()==2)
	data.set_tile(Vector2i.ZERO,DungeonData.TileType.FLOOR,0)
	assert(PokemonProjectile.flight_plan(data,Vector2i.ZERO,Vector2i.RIGHT,4,occupied,true).path.is_empty())
	var ramp := DungeonData.new()
	ramp.add_ramp(Vector2i.ZERO,Vector2i.RIGHT,0)
	assert(PokemonProjectile.flight_plan(ramp,Vector2i(4,0),Vector2i.DOWN,4,Callable(),true).path.is_empty())
	# Main integration: shoot over an edge/lower enemy at constant +1 height.
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	main.elemental_move_floor = 1
	root.add_child(main)
	Helper.complete_introduction(main)
	for with_upper_enemy in [false,true]:
		main.cancel_round()
		data = DungeonData.new()
		data.set_tile(Vector2i.ZERO,DungeonData.TileType.FLOOR,1)
		data.set_tile(Vector2i(2,0),DungeonData.TileType.FLOOR,0)
		data.enemy_spawns.append(Vector2i(2,0))
		if with_upper_enemy:
			data.set_tile(Vector2i(4,0),DungeonData.TileType.FLOOR,1)
			data.enemy_spawns.append(Vector2i(4,0))
		main.dungeon = data
		assert(main.dungeon_renderer.render_dungeon(data))
		main.spawn_test_enemies()
		main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
		main.player.facing = Vector2i.RIGHT
		main.refresh_fog()
		var original_tiles := data.tiles.duplicate()
		var lower = main.enemy_occupancy[Vector2i(2,0)]
		var lower_hp: int = lower.health.current
		var upper = main.enemy_occupancy.get(Vector2i(4,0))
		var pp: int = main.player.battle_state.remaining_pp[2]
		assert(main.player.use_move(2))
		var effect: ProjectileEffect
		for child in main.entities.get_children():
			if child is ProjectileEffect and not child.flight_completed: effect=child
		assert(effect!=null and effect.impact_pending==with_upper_enemy)
		var y := effect.global_position.y
		effect.animation.pause()
		effect.animation.custom_step(main.player.character_visual.projectile_release_time()+0.4)
		assert(is_equal_approx(effect.global_position.y,y) and effect.global_position.x>1.9)
		assert(lower.health.current==lower_hp)
		Helper.complete(main)
		assert(lower.health.current==lower_hp and main.player.battle_state.remaining_pp[2]==pp-1)
		if with_upper_enemy: assert(upper.health.current<upper.health.maximum)
		assert(data.tiles==original_tiles and not main.resolving_turn)
		await process_frame
	main.free()
	await process_frame
	print("PASS: +1 air flight/range/height, same-height targets across gaps, lower-target immunity, walls/ramps, opt-out, PP/turns and unchanged topology")
	quit()
