extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func check_visual(renderer: DungeonRenderer, tile: Vector2i) -> void:
	var marker: MeshInstance3D
	for visual in renderer.fog_visuals:
		if visual.stairs and visual.tiles.has(tile):
			marker = visual.mesh
	assert(marker != null)
	var mount: Node3D = marker.get_node("StairsPlaceholder")
	var sprite: Sprite3D = mount.get_node("Illustration")
	assert(sprite.texture.get_size() == Vector2(200, 163))
	assert(sprite.texture.get_image().detect_alpha() != Image.ALPHA_NONE)
	assert(sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED)
	assert(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	assert(sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS and not sprite.shaded)
	assert(sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(mount.scale == Vector3.ONE * DungeonData.TILE_SIZE)
	assert(is_equal_approx(sprite.pixel_size * 200, 0.8))
	var foot_pixel_y := sprite.get_item_rect().end.y - 154.0
	assert(is_zero_approx(foot_pixel_y))
	assert(is_equal_approx(mount.global_position.y, marker.global_position.y + marker.mesh.size.y / 2.0 + 0.005))
	marker.hide()
	assert(not sprite.is_visible_in_tree())
	marker.show()
	assert(sprite.is_visible_in_tree())
	renderer.apply_fog()
	assert(sprite.is_visible_in_tree() == renderer.dungeon_data.is_bright(tile))

func validate() -> void:
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	for elevation in [-1, 0, 1]:
		var data := DungeonData.new()
		var tile := Vector2i(2, 2)
		data.set_tile(tile, DungeonData.TileType.STAIRS, elevation)
		renderer.render_dungeon(data)
		check_visual(renderer, tile)
		data.update_fog(tile)
		renderer.apply_fog()
		check_visual(renderer, tile)
	renderer.free()
	for mode in ["main", "demo_main", "limit_testing_main"]:
		var main = load("res://scenes/main/%s.tscn" % mode).instantiate()
		root.add_child(main)
		Helper.complete_introduction(main)
		check_visual(main.dungeon_renderer, main.dungeon.stairs_position)
		main.queue_free()
		await process_frame
	print("PASS: stairs texture/alpha, uniform sizing/anchor, elevations, inherited visibility, procedural modes")
	quit()
