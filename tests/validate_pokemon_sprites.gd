extends SceneTree

const Library = preload("res://scripts/effects/pokemon_sprite_library.gd")
const Profile = preload("res://scripts/effects/pokemon_sprite_profile.gd")
const Controller = preload("res://scripts/effects/pokemon_character_visual.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var expected := {
		"Chimchar": {"Idle": Vector3i(24,40,5), "Walk": Vector3i(32,48,7), "Attack": Vector3i(64,80,10), "Hurt": Vector3i(32,48,2), "Faint": Vector3i(32,32,4)},
		"Stunky": {"Idle": Vector3i(32,48,6), "Walk": Vector3i(32,40,4), "Attack": Vector3i(72,80,11), "Hurt": Vector3i(40,56,2), "Faint": Vector3i(32,32,4)},
		"Drapion": {"Idle": Vector3i(48,40,4), "Walk": Vector3i(48,40,4), "Attack": Vector3i(80,88,12), "Hurt": Vector3i(56,64,2), "Charge": Vector3i(48,40,10), "Strike": Vector3i(72,88,10)}
	}
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.rotation.x = deg_to_rad(-35.0)
	camera.position = Vector3(0,sin(deg_to_rad(35.0)),cos(deg_to_rad(35.0))) * 12.8
	var ground := DungeonData.new()
	ground.set_tile(Vector2i.ZERO,DungeonData.TileType.FLOOR)
	var paths := ["res://scenes/player/player.tscn", "res://scenes/enemies/test_enemy.tscn", "res://scenes/enemies/minotaur.tscn"]
	for i in range(3):
		var actor = load(paths[i]).instantiate()
		root.add_child(actor)
		var visual = actor.character_visual
		visual.set_process(false)
		var species: String = ["Chimchar","Stunky","Drapion"][i]
		assert(visual.profile.directory.ends_with(species))
		assert(visual.clips.size() == expected[species].size())
		assert(visual.clips == Library.load_species(visual.profile.directory,visual.profile.animations.values()))
		assert(visual.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		assert(not visual.sprite.flip_h and not visual.sprite.flip_v)
		for name in expected[species]:
			var spec: Vector3i = expected[species][name]
			var info: Dictionary = visual.clips[name]
			assert(info.durations.size() == spec.z)
			for pair in [[Vector2i.DOWN,0],[Vector2i.RIGHT,2],[Vector2i.UP,4],[Vector2i.LEFT,6]]:
				visual.facing = pair[0]
				visual.play_clip(name, true)
				for index in range(spec.z):
					visual.frame_index = -1
					visual.apply_frame()
					var atlas: AtlasTexture = visual.sprite.texture
					assert(atlas.region == Rect2(index*spec.x,pair[1]*spec.y,spec.x,spec.y))
					var frame: Dictionary = info.rows[pair[1]][index]
					var feet: Vector2 = visual.sprite.get_item_rect().position + Vector2(visual.foot_anchor.x, 0)
					assert(is_zero_approx(feet.x))
					assert((visual.foot_anchor - atlas.get_size()/2.0).is_equal_approx(visual.ground_reference))
					assert(visual.sprite.offset.is_equal_approx(Vector2(-visual.ground_reference.x, visual.ground_reference.y)))
					assert(atlas.has_meta("pokemon_opaque_uvs") and atlas.has_meta("pokemon_opaque_top"))
					var clearance: AttackLeap = actor.sprite_clearance if actor is Minotaur else actor.attack_leap
					var rect: Rect2 = visual.sprite.get_item_rect()
					var original_origin: Vector3 = visual.sprite.global_position - clearance.surface_offset
					var pixel: Vector2 = rect.position + rect.size/2.0
					var expected_point: Vector3 = original_origin + (camera.global_basis.x*pixel.x + camera.global_basis.y*pixel.y)*visual.original_pixel_size
					var expected_screen := camera.unproject_position(expected_point)
					visual.clear_ramp_intersection(camera,ground,Vector2i.ZERO,clearance)
					var corrected_point: Vector3 = visual.sprite.global_position + (camera.global_basis.x*pixel.x + camera.global_basis.y*pixel.y)*visual.sprite.pixel_size
					assert(camera.unproject_position(corrected_point).distance_to(expected_screen) < 0.01)
					var bounds: Rect2i = atlas.get_meta("pokemon_opaque_rect")
					for x in [bounds.position.x,bounds.end.x]:
						for y in [bounds.position.y,bounds.end.y]:
							var point: Vector3 = visual.sprite.global_position + camera.global_basis.x*(rect.position.x+x)*visual.sprite.pixel_size
							point += camera.global_basis.y*(rect.end.y-y)*visual.sprite.pixel_size
							assert(point.y >= actor.global_position.y - 0.001)

					visual.clip_time += float(info.durations[index]) + 0.0000001
		# Body offsets must remain visible rather than being cancelled by anchoring.
		visual.cancel()
		visual.face(Vector2i.DOWN)
		var source_y: Array[float] = []
		for frame in visual.clips.Idle.rows[0]:
			source_y.append(frame.body.y - frame.texture.get_height()/2.0)
		assert(source_y.min() < source_y.max())
		var idle_duration: float = visual.clips.Idle.durations[0]
		visual.action_speed = 3.0
		visual._process(idle_duration - 0.0001)
		assert(visual.frame_index == 0) # Idle never inherits held-run acceleration.
		visual._process(0.0002)
		assert(visual.frame_index == 1)
		visual.action_speed = 1.0
		visual.cancel()
		visual.walk()
		visual._process(0.05)
		var time: float = visual.clip_time
		var walk_texture: Texture2D = visual.sprite.texture
		visual.walk()
		assert(visual.clip_time == time and visual.clip == "Walk")
		assert(visual.sprite.texture == walk_texture)
		var pixel_size: float = visual.original_pixel_size
		for step in range(40):
			visual.walk()
			visual._process(0.08)
			assert(visual.action == "Walk" and visual.original_pixel_size == pixel_size)
			assert(visual.sprite.texture == visual.clips.Walk.rows[visual.row()][visual.frame_index].texture)
		visual._process(0.25)
		assert(visual.clip == "Idle")
		actor.health.reset(actor.maximum_hp)
		var hp: int = actor.health.current
		actor.receive_damage(1)
		assert(actor.health.current == hp-1 and visual.clip == "Hurt")
		visual._process(0.2)
		assert(visual.clip == "Idle")
		visual.attack()
		visual._process(0.1)
		assert(visual.clip == "Attack" and actor.health.current == hp-1)
		visual.standing()
		for facing: Vector2i in DungeonData.CARDINALS:
			visual.cancel()
			visual.face(facing)
			visual.hurt()
			assert(visual.action == "Hurt")
			visual._process(float(visual.clips.Hurt.total) + 0.001)
			assert(visual.action == "Idle" and visual.facing == facing)
			if actor is Minotaur:
				visual.spin()
				assert(visual.action == "Attack")
				visual.animation.pause()
				visual.animation.custom_step(float(visual.clips.Attack.total) + 0.001)
			else:
				actor.attack_leap.play(facing)
				assert(visual.action == "Attack")
				var leap: AttackLeap = actor.attack_leap
				assert(not leap.procedural_motion and is_equal_approx(leap.duration, visual.clips.Attack.total))
				leap.animation.pause()
				var before: Transform3D = visual.sprite.transform
				var root_before: Vector3 = actor.position
				var total: float = visual.clips.Attack.total
				var first_duration: float = visual.clips.Attack.durations[0]
				leap.animation.custom_step(first_duration + 0.0001)
				assert(visual.frame_index == 1 and leap.active)
				assert(visual.sprite.transform == before and actor.position == root_before)
				leap.animation.custom_step(total - first_duration - 0.0002)
				assert(leap.active) # Entire last frame holds for its XML duration.
				leap.animation.custom_step(0.001)
				assert(not leap.active)
			assert(visual.action == "Idle" and visual.facing == facing)
		# A missing optional action uses the configured Idle without fabricated frames.
		visual.clips = visual.clips.duplicate()
		visual.clips.erase("Hurt")
		visual.play_clip("Hurt", true)
		assert(visual.clip == "Idle")
		visual.freeze_defeated()
		visual.cancel()
		assert(not visual.frozen and visual.clip == "Idle")
		actor.free()
	# Explicit profile rollback keeps the original artwork and anchor implementation.
	var fallback = load(paths[0]).instantiate()
	fallback.get_node("VisualController").profile = null
	root.add_child(fallback)
	assert(fallback.character_visual.clips.is_empty())
	assert(fallback.attack_leap.procedural_motion and is_equal_approx(fallback.attack_leap.duration,0.24))
	assert(fallback.character_visual.sprite.texture.resource_path.ends_with("swordsman/front.png"))
	fallback.free()
	camera.free()
	await process_frame
	print("PASS: species XML dimensions/counts/timing, exact cardinal atlas rows, shared caches, fixed ground/native bob, screen-preserving clearance, XML attack completion, walk continuity, hurt HP, attack without extra damage, missing-action/placeholder fallback and reset")
	quit()
