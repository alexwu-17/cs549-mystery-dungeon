extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void: call_deferred("validate")

func projected_width(camera: Camera3D, sprite: Sprite3D, origin: Vector3, pixel_size: float) -> float:
	var rect := sprite.get_item_rect()
	var left := origin + camera.global_basis.x * rect.position.x * pixel_size * sprite.global_basis.x.length()
	var right := origin + camera.global_basis.x * rect.end.x * pixel_size * sprite.global_basis.x.length()
	return camera.unproject_position(left).distance_to(camera.unproject_position(right))

func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	var renderer: DungeonRenderer = main.dungeon_renderer
	var camera: Camera3D = main.presentation_camera
	var assembled := ModularDungeonVisuals.ramp_mesh(3)
	assert(assembled.get_surface_count() == ModularDungeonVisuals.RAMP.get_surface_count() * 3 + 1)
	assert(assembled.get_faces().size() == ModularDungeonVisuals.RAMP.get_faces().size() * 3 + 3 * 4 * 36)
	for part in range(3):
		var vertices: PackedVector3Array = assembled.surface_get_arrays(part)[Mesh.ARRAY_VERTEX]
		var bounds := AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices: bounds = bounds.expand(vertex)
		assert(bounds.size.is_equal_approx(Vector3.ONE))
		assert(is_equal_approx(bounds.position.x, part) and is_equal_approx(bounds.position.y, part))
	for direction: Vector2i in DungeonData.CARDINALS:
		for elevation in [-1, 0]:
			var data := DungeonData.new()
			data.add_ramp(Vector2i.ZERO, direction, elevation)
			renderer.render_dungeon(data)
			var ramp: Dictionary
			for visual in renderer.fog_visuals:
				if visual.tiles.size() == 3: ramp = visual
			assert(ramp.asset and ramp.mesh.mesh == ModularDungeonVisuals.ramp_mesh(3))
			var mesh: MeshInstance3D = ramp.mesh
			var bounds := mesh.get_aabb()
			var start := mesh.transform * Vector3(bounds.position.x, 0, bounds.get_center().z)
			var end := mesh.transform * Vector3(bounds.end.x, bounds.end.y, bounds.get_center().z)
			assert(is_equal_approx(start.y, elevation * 3.0 + 0.1))
			assert(is_equal_approx(end.y, (elevation + 1) * 3.0 + 0.1))
			assert(Vector2(end.x - start.x, end.z - start.z).is_equal_approx(Vector2(direction) * 3.0))
			assert(is_equal_approx(bounds.size.z * mesh.basis.z.length(), 1.0))
			for index in [1, 2, 3, 3, 2, 1]:
				var tile: Vector2i = direction * index
				main.player.setup(tile, data, renderer)
				var logical: Vector3 = main.player.position
				camera.follow_sprite(main.player.get_node("PlayerSprite"))
				main.player.character_visual.clear_ramp_intersection(camera, data, tile, main.player.attack_leap)
				assert(main.player.position == logical)
				assert(main.player.attack_leap.surface_offset.y + 0.0001 >= renderer.get_ramp_visual_offset(tile).y)
				var visual_position: Vector3 = main.player.get_node("PlayerSprite").position
				main.player.character_visual.clear_ramp_intersection(camera, data, tile, main.player.attack_leap)
				assert(main.player.get_node("PlayerSprite").position.is_equal_approx(visual_position))
				assert(is_equal_approx(logical.y, elevation * 3.0 + (index - 0.5) + 0.1))
			data.update_fog(direction)
			renderer.apply_fog(elevation)
			assert(ramp.fog_state == 0)
			main.player.character_visual.clear_ramp_intersection(camera, data, Vector2i.ZERO, main.player.attack_leap)
			assert(main.player.attack_leap.surface_offset == Vector3.ZERO)
	# Actual player billboard and current perspective camera, corridor walls on both sides.
	var corridor := DungeonData.new()
	for x in range(-2, 3): corridor.set_tile(Vector2i(x, 0), DungeonData.TileType.CORRIDOR)
	renderer.render_dungeon(corridor)
	main.player.setup(Vector2i.ZERO, corridor, renderer)
	camera.follow_sprite(main.player.get_node("PlayerSprite"))
	var front: Dictionary
	var rear: Dictionary
	for visual in renderer.fog_visuals:
		if visual.wall and visual.tiles[0] == Vector2i.ZERO:
			var center: Vector3 = visual.mesh.global_transform * visual.mesh.get_aabb().get_center()
			if center.z > 0: front = visual
			else: rear = visual
	assert(not front.is_empty() and not rear.is_empty())
	var sprite: Sprite3D = main.player.get_node("PlayerSprite")
	var width_before := projected_width(camera, sprite, sprite.global_position - main.player.attack_leap.surface_offset, main.player.character_visual.original_pixel_size)
	var logical: Vector3 = main.player.position
	main.player.character_visual.clear_ramp_intersection(camera, corridor, Vector2i.ZERO, main.player.attack_leap)
	assert(main.player.position == logical) # Shallower pitches may need no rear-wall offset.
	assert(is_equal_approx(projected_width(camera, sprite, sprite.global_position, sprite.pixel_size), width_before))
	var corrected: Vector3 = sprite.position
	main.player.character_visual.clear_ramp_intersection(camera, corridor, Vector2i.ZERO, main.player.attack_leap)
	assert(sprite.position.is_equal_approx(corrected))
	var inverse: Transform3D = rear.mesh.global_transform.affine_inverse()
	for point: Vector3 in camera.sprite_samples(sprite):
		assert(not rear.mesh.get_aabb().has_point(inverse * point))
	renderer.update_occlusion(camera, Vector2i.ZERO, camera.sprite_samples(main.player.get_node("PlayerSprite")))
	assert(front.occluded and front.mesh.visible and is_equal_approx(front.mesh.transparency, 0.8))
	assert(not rear.occluded and rear.mesh.visible and rear.mesh.transparency == 0.0)
	assert(front.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	renderer.apply_fog()
	assert(front.mesh.visible and is_equal_approx(front.mesh.transparency, 0.8))
	# Preserve fog shading while fading, then restore without a stale override.
	assert(front.mesh.get_surface_override_material(0) == front.materials[0][1])
	renderer.update_occlusion(camera, Vector2i.ZERO, [])
	assert(not front.occluded and front.mesh.transparency == 0.0 and rear.mesh.transparency == 0.0)
	assert(front.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	var room := DungeonData.new()
	room.rooms = [Rect2i(0, 0, 5, 5)]
	for y in range(5):
		for x in range(5): room.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)
	renderer.render_dungeon(room)
	main.player.setup(Vector2i(2, 2), room, renderer)
	camera.follow_sprite(sprite)
	main.player.character_visual.clear_ramp_intersection(camera, room, Vector2i(2, 2), main.player.attack_leap)
	assert(main.player.attack_leap.surface_offset == Vector3.ZERO)
	assert(is_equal_approx(sprite.pixel_size, main.player.character_visual.original_pixel_size))
	assert(is_equal_approx(projected_width(camera, sprite, sprite.global_position, sprite.pixel_size), width_before))
	main.free()
	print("PASS: three stair copies per ramp, four orientations/both elevations, tread clearance, front/rear walls, constant projected sprite size in corridor/room, fog/restoration")
	quit()
