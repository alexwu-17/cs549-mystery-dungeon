extends SceneTree


func _initialize() -> void:
	call_deferred("validate")


func validate() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	var camera: Camera3D = main.presentation_camera
	var sprite: Sprite3D = main.player.get_node("PlayerSprite")
	assert(camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	assert(is_equal_approx(tan(deg_to_rad(75.0) / 2) / tan(deg_to_rad(camera.fov) / 2), 3.75))
	assert(not main.hud.get_node("Screen/GameOver").visible)
	for tile in [Vector2i(2, 2), Vector2i(7, 2), Vector2i(9, 2)]:
		main.player.setup(tile, main.dungeon, main.dungeon_renderer)
		main.refresh_fog()
		assert(camera.global_position.is_equal_approx(main.player.global_position + camera.follow_offset))
	assert(not camera.sprite_samples(sprite).is_empty())
	main.player.receive_damage(100)
	assert(main.game_over and main.hud.get_node("Screen/GameOver").visible)
	assert(is_equal_approx(main.hud.get_node("Screen/GameOver").color.a, 0.7))
	var dead_tile: Vector2i = main.player.grid_position
	main.player.try_move(Vector2i.RIGHT)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	main.player.basic_attack()
	load("res://tests/round_test_helper.gd").complete(main)
	assert(main.player.grid_position == dead_tile)
	var restart := InputEventKey.new()
	restart.physical_keycode = KEY_R
	restart.pressed = true
	main._unhandled_input(restart)
	load("res://tests/round_test_helper.gd").complete_introduction(main)
	assert(not main.game_over and not main.hud.get_node("Screen/GameOver").visible)
	assert(main.player.health.current == 20 and main.floor_number == 1 and main.player.level == 5)
	assert(main.hud.minimap.dungeon == main.dungeon)
	assert(camera.global_position.is_equal_approx(main.player.global_position + camera.follow_offset))
	# Test exact oriented bounds, protected categories, and fog composition.
	var data := DungeonData.new()
	data.rooms = [Rect2i(0, 0, 1, 1), Rect2i(0, 2, 2, 1)]
	data.set_tile(Vector2i.ZERO, DungeonData.TileType.FLOOR)
	data.set_tile(Vector2i(0, 2), DungeonData.TileType.FLOOR, 1)
	data.set_tile(Vector2i(1, 2), DungeonData.TileType.STAIRS, 1)
	data.add_ramp(Vector2i(5, 0), Vector2i.RIGHT, 0)
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	renderer.render_dungeon(data)
	data.update_fog(Vector2i.ZERO)
	renderer.apply_fog()
	var blocked: Dictionary
	for visual in renderer.fog_visuals:
		if visual.tiles == [Vector2i(0, 2)]:
			blocked = visual
	var mesh: MeshInstance3D = blocked.mesh
	mesh.rotation.y = 0.4
	mesh.scale = Vector3(0.7, 1, 0.8)
	var sight := (mesh.global_position - camera.global_position).normalized()
	var points: Array[Vector3] = [mesh.global_position + sight * 4]
	renderer.update_occlusion(camera, Vector2i.ZERO, points)
	assert(blocked.occluded and not mesh.visible)
	assert(mesh.material_override == renderer.other_elevation_material)
	# Fog refresh must not undo occlusion or expose hidden stairs.
	renderer.apply_fog()
	assert(not mesh.visible)
	for visual in renderer.fog_visuals:
		if visual.stairs:
			assert(not visual.mesh.visible)
		if not visual.candidate:
			assert(not visual.occluded)
	points[0] += camera.global_basis.x * 2
	renderer.update_occlusion(camera, Vector2i.ZERO, points)
	assert(not blocked.occluded and mesh.visible)
	# A mesh behind the sprite must never count as obstruction.
	points[0] = mesh.global_position - sight * 2
	renderer.update_occlusion(camera, Vector2i.ZERO, points)
	assert(not blocked.occluded)
	points[0] = mesh.global_position + sight * 4
	renderer.update_occlusion(camera, Vector2i(0, 2), points)
	assert(not blocked.occluded) # Own room/support tile.
	# Higher corridors also obstruct, including when the player is in a corridor.
	data.set_tile(Vector2i(2, 2), DungeonData.TileType.CORRIDOR, 1)
	data.set_tile(Vector2i(2, 0), DungeonData.TileType.CORRIDOR, 0)
	renderer.render_dungeon(data)
	data.update_fog(Vector2i.ZERO)
	renderer.apply_fog()
	var corridor: Dictionary
	for visual in renderer.fog_visuals:
		if visual.tiles == [Vector2i(2, 2)]:
			corridor = visual
	var corridor_mesh: MeshInstance3D = corridor.mesh
	var corridor_sight := (corridor_mesh.global_position - camera.global_position).normalized()
	points[0] = corridor_mesh.global_position + corridor_sight * 4
	for player_tile in [Vector2i.ZERO, Vector2i(2, 0)]:
		renderer.update_occlusion(camera, player_tile, points)
		assert(corridor.occluded and not corridor_mesh.visible)
		assert(corridor_mesh.material_override == renderer.other_elevation_material)
	points[0] += camera.global_basis.x * 2
	renderer.update_occlusion(camera, Vector2i(2, 0), points)
	assert(not corridor.occluded and corridor_mesh.visible)
	points[0] = corridor_mesh.global_position + corridor_sight * 4
	renderer.update_occlusion(camera, Vector2i(2, 2), points)
	assert(not corridor.occluded and corridor_mesh.visible) # Support/same height.
	# All five transition tiles participate; the slope remains one visual unit.
	data.set_tile(Vector2i(3, 0), DungeonData.TileType.CORRIDOR, -1)
	var transition_meshes := 0
	for visual in renderer.fog_visuals:
		if not data.reserved_transitions.has(visual.tiles[0]):
			continue
		transition_meshes += 1
		assert(visual.candidate)
		var transition_mesh: MeshInstance3D = visual.mesh
		var center := transition_mesh.global_transform * transition_mesh.get_aabb().get_center()
		var transition_sight := (center - camera.global_position).normalized()
		points[0] = center + transition_sight * 4
		# The lower buffer at height zero must not hide for a same-level player.
		renderer.update_occlusion(camera, Vector2i.ZERO, points)
		if data.get_tile(visual.tiles[0]) == DungeonData.TileType.RAMP or data.get_elevation(visual.tiles[0]) > 0:
			assert(visual.occluded and not transition_mesh.visible)
			var fog_material = transition_mesh.material_override
			renderer.apply_fog()
			assert(not transition_mesh.visible and transition_mesh.material_override == fog_material)
		else:
			assert(not visual.occluded)
		renderer.update_occlusion(camera, Vector2i(3, 0), points)
		assert(visual.occluded and not transition_mesh.visible) # All five tiles above -1.
		# Support geometry is protected, including the continuous ramp mesh.
		for support_tile: Vector2i in visual.tiles:
			renderer.update_occlusion(camera, support_tile, points)
			assert(not visual.occluded and transition_mesh.visible)
		points[0] += camera.global_basis.x * 10
		renderer.update_occlusion(camera, Vector2i.ZERO, points)
		assert(not visual.occluded and transition_mesh.visible)
	assert(transition_meshes == 3) # Two buffers plus one three-tile slope.
	# Track actual rendered heights on a standardized ramp in both directions,
	# including -1 and 0 surfaces rather than only the legacy fixture's 0/+1.
	data.set_tile(Vector2i(4, 0), DungeonData.TileType.CORRIDOR, -1)
	data.ramp_segments.clear()
	data.ramp_tiles.clear()
	data.reserved_transitions.clear()
	data.add_ramp(Vector2i(5, 0), Vector2i.RIGHT, -1)
	renderer.render_dungeon(data)
	for x in [5, 6, 7, 8, 9, 8, 7, 6, 5]:
		main.player.setup(Vector2i(x, 0), data, renderer)
		camera.follow_sprite(sprite)
		assert(camera.global_position.is_equal_approx(main.player.global_position + camera.follow_offset))
		assert(is_equal_approx(main.player.position.y, data.surface_elevation(Vector2i(x, 0)) * DungeonData.ELEVATION_HEIGHT + DungeonRenderer.FLOOR_THICKNESS / 2))
	renderer.render_dungeon(data)
	for visual in renderer.fog_visuals:
		assert(not visual.occluded)
	renderer.free()
	main.free()
	await process_frame
	print("PASS: overlay/restart, camera elevation/centering, transformed occlusion/restoration/protection/fog")
	quit()
