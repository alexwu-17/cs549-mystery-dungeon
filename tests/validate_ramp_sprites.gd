extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.rotation.x = deg_to_rad(-50)
	for scene in ["res://scenes/player/player.tscn", "res://scenes/enemies/test_enemy.tscn"]:
		var actor = load(scene).instantiate()
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
					camera.position = actor.position + Vector3(0, 10, 8)
					visual.face(direction)
					visual.clear_ramp_intersection(camera, data, tile, leap)
					if direction == Vector2i.UP:
						assert(leap.surface_offset.length() > 0.0)
						var normal := Vector3(0, 1, 1).normalized()
						var height := (visual.sprite.get_item_rect().end.y - visual.opaque_top) * visual.sprite.pixel_size
						assert(normal.dot(visual.sprite.global_position + camera.global_basis.y * height - actor.global_position) > 0)
					else:
						assert(leap.surface_offset == Vector3.ZERO and visual.sprite.transform.is_equal_approx(baseline))
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
				visual.clear_ramp_intersection(camera, data, Vector2i.ZERO, leap)
				assert(leap.surface_offset == Vector3.ZERO and visual.sprite.transform.is_equal_approx(baseline))
		actor.free()
	camera.free()
	print("PASS: player/skeleton ramp clearance, four orientations, both levels/directions, no drift, leap integration, flat restoration")
	quit()
