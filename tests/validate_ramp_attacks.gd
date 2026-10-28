extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.rotation.x = deg_to_rad(-35.0)
	var cases := 0
	var flat_approaches := 0
	for scene in ["res://scenes/player/player.tscn","res://scenes/enemies/test_enemy.tscn"]:
		var actor = load(scene).instantiate()
		root.add_child(actor)
		for uphill: Vector2i in DungeonData.CARDINALS:
			var data := DungeonData.new()
			data.add_ramp(Vector2i.ZERO,uphill,0)
			assert(renderer.render_dungeon(data))
			for index in range(5):
				for sign_value in [-1,1]:
					var target_index: int = index + sign_value
					if target_index < 0 or target_index > 4: continue
					var start: Vector2i = uphill * index
					var direction: Vector2i = uphill * sign_value
					actor.setup(start,data,renderer)
					camera.position = actor.position + Vector3(0,sin(deg_to_rad(35.0)),cos(deg_to_rad(35.0)))*12.8
					actor.facing = direction
					actor.character_visual.face(direction)
					var root_position: Vector3 = actor.position
					var leap: AttackLeap = actor.attack_leap
					var visual = actor.character_visual
					var rest_origin: Vector3 = visual.sprite.global_position - leap.surface_offset
					leap.play(direction)
					leap.animation.pause()
					if data.get_tile(start) != DungeonData.TileType.RAMP:
						assert(not leap.ramp_path)
						for progress in [0.0,0.25,0.5,0.75,1.0]:
							leap._sample(progress)
							assert(leap.attack_world_offset == Vector3.ZERO)
							assert(visual.sprite.offset.is_equal_approx(Vector2(-visual.ground_reference.x,visual.ground_reference.y)))
						leap.finish()
						flat_approaches += 1
						continue
					assert(leap.ramp_path and not leap.procedural_motion)
					assert(is_equal_approx(leap.duration,visual.clips.Attack.total))
					var info: Dictionary = visual.clips.Attack
					var hit_time := 0.0
					for frame in range(info.hit_frame): hit_time += float(info.durations[frame])
					leap._sample(hit_time / leap.duration)
					var delta := renderer.get_entity_world_position(start+direction)-renderer.get_entity_world_position(start)
					assert(leap.attack_world_offset.is_equal_approx(delta))
					assert(signf(leap.attack_world_offset.y) == sign_value)
					assert(actor.position == root_position and actor.grid_position == start)
					var bounds: Rect2i = visual.sprite.texture.get_meta("pokemon_opaque_rect")
					var rect: Rect2 = visual.sprite.get_item_rect()
					var plane_origin: Vector3 = actor.global_position + leap.attack_world_offset
					for x in [bounds.position.x,bounds.end.x]:
						for y in [bounds.position.y,bounds.end.y]:
							var point: Vector3 = visual.sprite.global_position + camera.global_basis.x*(rect.position.x+x)*visual.sprite.pixel_size
							point += camera.global_basis.y*(rect.end.y-y)*visual.sprite.pixel_size
							assert(leap.attack_plane_normal.dot(point-plane_origin) >= leap.attack_plane_normal.y*leap.attack_tread_clearance - 0.001)

					# Pose anchoring removes baked screen travel only while this path is active.
					var first: Dictionary = info.rows[visual.row()][0]
					var frame: Dictionary = info.rows[visual.row()][visual.frame_index]
					var anchor: Vector2 = visual.foot_anchor - frame.texture.get_size()/2.0
					var body_delta: Vector2 = (frame.body-frame.texture.get_size()/2.0)-(first.body-first.texture.get_size()/2.0)
					assert(anchor.is_equal_approx(visual.ground_reference+body_delta))
					# At the shared edge, buffers have reached their flat height; middle ramps rise linearly.
					var rush_time := 0.0
					for frame_index in range(info.rush_frame): rush_time += float(info.durations[frame_index])
					leap._sample((rush_time+(hit_time-rush_time)*0.5)/leap.duration)
					var from_ramp := data.get_tile(start) == DungeonData.TileType.RAMP
					var to_ramp := data.get_tile(start+direction) == DungeonData.TileType.RAMP
					var expected_y := delta.y * (0.5 if from_ramp and to_ramp else (1.0 if from_ramp else 0.0))
					assert(is_equal_approx(leap.attack_world_offset.y,expected_y))
					leap._sample(1.0)
					assert(leap.attack_world_offset.is_zero_approx())
					leap.finish()
					assert(not leap.active and not leap.ramp_path and leap.attack_world_offset == Vector3.ZERO)
					assert((visual.sprite.global_position-leap.surface_offset).is_equal_approx(rest_origin))
					assert(actor.position == root_position and actor.grid_position == start and visual.action == "Idle")
					# Cancellation from the extended position restores the same actor and idle state.
					leap.play(direction)
					leap.animation.pause()
					leap._sample(hit_time / leap.duration)
					leap.finish()
					assert(actor.position == root_position and actor.grid_position == start and visual.action == "Idle")
					cases += 1
			# A ramp's side entry remains incompatible even if a floor tile exists there.
			var side := Vector2i(-uphill.y,uphill.x)
			var start := uphill * 2
			data.set_tile(start+side,DungeonData.TileType.FLOOR)
			actor.setup(start,data,renderer)
			actor.character_visual.face(side)
			actor.attack_leap.play(side)
			assert(not actor.attack_leap.ramp_path)
			actor.attack_leap.finish()
		# Same-height floors retain the existing native attack without world travel.
		var flat := DungeonData.new()
		for direction: Vector2i in DungeonData.CARDINALS: flat.set_tile(direction,DungeonData.TileType.FLOOR)
		flat.set_tile(Vector2i.ZERO,DungeonData.TileType.FLOOR)
		renderer.render_dungeon(flat)
		actor.setup(Vector2i.ZERO,flat,renderer)
		for direction: Vector2i in DungeonData.CARDINALS:
			actor.character_visual.face(direction)
			actor.attack_leap.play(direction)
			actor.attack_leap.animation.pause()
			for progress in [0.0,0.25,0.5,0.75,1.0]:
				actor.attack_leap._sample(progress)
				assert(not actor.attack_leap.ramp_path and actor.attack_leap.attack_world_offset == Vector3.ZERO)
				var visual = actor.character_visual
				assert(visual.sprite.offset.is_equal_approx(Vector2(-visual.ground_reference.x,visual.ground_reference.y)))
			actor.attack_leap.finish()
		actor.free()
	camera.free()
	renderer.free()
	# Exercise real combat signals/round sequencing on adjacent ramp tiles.
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	var combat := DungeonData.new()
	combat.add_ramp(Vector2i.ZERO,Vector2i.RIGHT,0)
	combat.player_spawn = Vector2i.RIGHT
	combat.enemy_spawns = [Vector2i.RIGHT*2]
	main.dungeon = combat
	main.dungeon_renderer.render_dungeon(combat)
	main.spawn_test_enemies()
	main.player.setup(combat.player_spawn,combat,main.dungeon_renderer)
	main.player.health.reset(20)
	main.player.facing = Vector2i.RIGHT
	main.player.basic_attack()
	var enemy: Skeleton = main.enemies[0]
	assert(main.player.attack_leap.ramp_path and enemy.health.current == 3)
	main.player.attack_leap.animation.pause()
	for progress in [0.25,0.5,0.75]:
		main.player.attack_leap._sample(progress)
		assert(enemy.health.current == 3 and main.player.health.current == 20)
		assert(main.player.grid_position == combat.player_spawn and enemy.grid_position == combat.enemy_spawns[0])
	assert(main.enemy_occupancy.has(combat.enemy_spawns[0]))
	main.player.attack_leap.finish()
	assert(main.resolving_turn and enemy.attack_leap.ramp_path and main.player.health.current == 18)
	Helper.complete(main)
	assert(not main.resolving_turn and not main.player.round_locked)
	main.player.basic_attack()
	assert(main.enemies.is_empty() and main.enemy_occupancy.is_empty() and main.player.health.current == 20)
	Helper.complete(main)
	main.free()
	await process_frame
	print("PASS: ",cases," player/enemy ramp paths, ",flat_approaches," unchanged flat approaches, uphill/downhill/cardinal/buffer transitions, source timing, no duplicate travel, cancellation, side-entry protection, unchanged flat attacks, real combat damage/healing/occupancy and sequential rounds")
	quit()
