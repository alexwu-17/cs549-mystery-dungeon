extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.rotation.x = deg_to_rad(-50)
	for pitch in [35.0,50.0]:
		camera.rotation.x = deg_to_rad(-pitch)
		for fallback in [false,true]:
			for scene in ["res://scenes/player/player.tscn", "res://scenes/enemies/test_enemy.tscn"]:
				var actor = load(scene).instantiate()
				if fallback: actor.get_node("VisualController").profile = null
				root.add_child(actor)
				var visual: CharacterVisual = actor.character_visual
				var leap: AttackLeap = actor.attack_leap
				var baseline := visual.sprite.transform
				for direction: Vector2i in DungeonData.CARDINALS:
					for elevation in [-1, 0]:
						var data := DungeonData.new()
						data.add_ramp(Vector2i.ZERO, direction, elevation)
						for index in [1, 2, 3, 3, 2, 1]:
							var tile: Vector2i = direction * index
							actor.position = Vector3(tile.x, data.surface_elevation(tile) * DungeonData.ELEVATION_HEIGHT + 0.1, tile.y)
							camera.position = actor.position + Vector3(0,sin(deg_to_rad(pitch)),cos(deg_to_rad(pitch))) * 12.8
							visual.face(direction)
							visual.clear_ramp_intersection(camera, data, tile, leap)
							if direction == Vector2i.UP and pitch > 45.0:
								assert(leap.surface_offset.length() > 0.0)
								var normal := Vector3(0, 1, 1).normalized()
								var height := (visual.sprite.get_item_rect().end.y - visual.opaque_top) * visual.sprite.pixel_size
								assert(normal.dot(visual.sprite.global_position + camera.global_basis.y * height - actor.global_position) > 0)
							elif fallback:
								assert(leap.surface_offset == Vector3.ZERO and visual.sprite.transform.is_equal_approx(baseline))
							if not fallback:
								var bounds: Rect2i = visual.sprite.texture.get_meta("pokemon_opaque_rect")
								var rect := visual.sprite.get_item_rect()
								var normal := Vector3(-direction.x,1,-direction.y).normalized()
								for x in [bounds.position.x,bounds.end.x]:
									for y in [bounds.position.y,bounds.end.y]:
										var point: Vector3 = visual.sprite.global_position + camera.global_basis.x*(rect.position.x+x)*visual.sprite.pixel_size
										point += camera.global_basis.y*(rect.end.y-y)*visual.sprite.pixel_size
										var required := normal.y * ModularDungeonVisuals.ramp_clearance_height(3) if direction == Vector2i.UP else 0.0
										assert(normal.dot(point-actor.global_position) >= required - 0.001)
							var corrected := visual.sprite.transform
							visual.clear_ramp_intersection(camera, data, tile, leap)
							assert(visual.sprite.transform.is_equal_approx(corrected)) # No accumulation.
							leap.play(direction)
							leap.animation.pause()
							leap._sample(0.5)
							var logical: Vector3 = actor.position
							visual.clear_ramp_intersection(camera, data, tile, leap)
							leap.finish()
							visual.clear_ramp_intersection(camera, data, tile, leap)
							assert(actor.position == logical)
						# Neutral resting pose returns to the exact flat baseline.
						if not fallback: visual.face(Vector2i.DOWN)
						visual.clear_ramp_intersection(camera, data, Vector2i.ZERO, leap)
						assert(leap.surface_offset == Vector3.ZERO and visual.sprite.transform.is_equal_approx(baseline))
				if not fallback:
					for direction: Vector2i in [Vector2i.UP]:
						var data := DungeonData.new()
						data.add_ramp(Vector2i.ZERO,direction,0)
						for index in [1,2,3]:
							var tile: Vector2i = direction*index
							actor.position = Vector3(tile.x,data.surface_elevation(tile)*DungeonData.ELEVATION_HEIGHT+0.1,tile.y)
							camera.position = actor.position + Vector3(0,sin(deg_to_rad(pitch)),cos(deg_to_rad(pitch)))*12.8
							for facing: Vector2i in DungeonData.CARDINALS:
								visual.facing = facing
								for clip in ["Idle","Walk","Hurt","Faint"]:
									visual.play_clip(clip,true)
									for duration in visual.clips[clip].durations:
										visual.apply_frame()
										visual.clear_ramp_intersection(camera,data,tile,leap)
										var bounds: Rect2i = visual.sprite.texture.get_meta("pokemon_opaque_rect")
										var rect := visual.sprite.get_item_rect()
										var normal := Vector3(-direction.x,1,-direction.y).normalized()
										for x in [bounds.position.x,bounds.end.x]:
											for y in [bounds.position.y,bounds.end.y]:
												var point: Vector3 = visual.sprite.global_position + camera.global_basis.x*(rect.position.x+x)*visual.sprite.pixel_size
												point += camera.global_basis.y*(rect.end.y-y)*visual.sprite.pixel_size
												assert(normal.dot(point-actor.global_position) >= normal.y*ModularDungeonVisuals.ramp_clearance_height(3)-0.001)
										visual.clip_time += duration + 0.000001
				actor.free()
	camera.free()
	print("PASS: native/placeholder player/enemy ramp clearance, four orientations, both levels/directions, no drift, leap integration, flat restoration; all native Idle/Walk/Hurt/Faint frames clear front treads")
	quit()
