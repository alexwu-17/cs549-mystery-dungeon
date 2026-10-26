extends SceneTree

const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	for path in ["main", "demo_main", "limit_testing_main"]:
		var main = load("res://scenes/main/%s.tscn" % path).instantiate()
		root.add_child(main)
		Helper.complete_introduction(main)
		var lights: Array[Node] = main.find_children("*", "DirectionalLight3D", true, false)
		assert(lights.size() == 1)
		var light: DirectionalLight3D = lights[0]
		assert(light.shadow_enabled and light.light_energy > 0.0)
		assert((-light.global_basis.z).y < 0.0)
		var environment: Environment = main.get_node("WorldEnvironment").environment
		assert(environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR)
		assert(is_equal_approx(environment.ambient_light_energy, 0.25))
		assert(main.get_node("Camera3D").projection == Camera3D.PROJECTION_PERSPECTIVE)
		for visual in main.dungeon_renderer.fog_visuals:
			var mesh: MeshInstance3D = visual.mesh
			assert(mesh.cast_shadow == (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (visual.wall or visual.get("filler", false)) and visual.occluded else GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
			assert(mesh.visible == (visual.fog_visible and (visual.wall or visual.get("filler", false) or not visual.occluded)))
		main.queue_free()
		await process_frame
	for path in ["res://scenes/player/player.tscn", "res://scenes/enemies/test_enemy.tscn", "res://scenes/enemies/minotaur.tscn"]:
		var actor = load(path).instantiate()
		var sprites: Array[Node] = actor.find_children("*", "Sprite3D", true, false)
		assert(sprites.size() == 1)
		var sprite: Sprite3D = sprites[0]
		assert(sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
		assert(sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS)
		assert(not sprite.shaded and sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
		assert(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		root.add_child(actor)
		assert(sprite.is_visible_in_tree())
		actor.hide()
		assert(not sprite.is_visible_in_tree())
		actor.queue_free()
		await process_frame
	print("PASS: shared lighting, native sprite shadow configuration, and visibility")
	quit()
