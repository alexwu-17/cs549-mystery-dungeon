extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
const Snapshots = preload("res://tests/validate_terraces.gd")
func _initialize() -> void: call_deferred("validate")

static func environment_values(environment: Environment) -> Dictionary:
	var result: Dictionary = {}
	for property in environment.get_property_list():
		var key: String = property.name
		if key.begins_with("resource_") or not (int(property.usage)&PROPERTY_USAGE_STORAGE): continue
		result[key] = environment.get(key)
	return result

static func visual_values(main: Node) -> Array:
	var result: Array = []
	for visual in main.dungeon_renderer.fog_visuals:
		result.append([visual.mesh.visible,visual.mesh.transparency,visual.mesh.cast_shadow,visual.fog_state,visual.occluded,visual.materials])
	return result

func validate() -> void:
	for path in ["main","demo_main","limit_testing_main"]:
		TestDungeonFactory.rng.seed = 4
		var main = load("res://scenes/main/%s.tscn"%path).instantiate()
		root.add_child(main)
		Helper.complete_introduction(main)
		var lighting: DungeonLighting = main.get_node("LightingPresets")
		var light: DirectionalLight3D = lighting.sun
		# Demo starts on the Spring HD-2D preset; the shared scene and Limit Testing keep the exact baseline.
		assert(lighting.selected_preset == (3 if path == "demo_main" else 0))
		var original_scene = load("res://scenes/main/main.tscn").instantiate()
		if path == "demo_main":
			assert(lighting.world.environment.glow_enabled and lighting.world.environment.fog_enabled and lighting.world.camera_attributes is CameraAttributesPractical)
			lighting.apply_preset(0)
		assert(light.transform == original_scene.get_node("DirectionalLight3D").transform)
		assert(environment_values(lighting.world.environment) == environment_values(original_scene.get_node("WorldEnvironment").environment))
		assert(lighting.world.camera_attributes == original_scene.get_node("WorldEnvironment").camera_attributes)
		original_scene.free()
		var before := Snapshots.snapshot(main.dungeon)
		var rng_state: int = TestDungeonFactory.rng.state
		var turn_state: int = main.turn_rng.state
		var camera: Transform3D = main.presentation_camera.transform
		var visuals := visual_values(main)
		var environment := environment_values(lighting.world.environment)
		for index in [1,2,3,0,3,2,1,0]:
			lighting.apply_preset(index)
			assert(main.find_children("*","DirectionalLight3D",true,false).size() == 1)
			assert(light.shadow_enabled and light.directional_shadow_max_distance == 40.0)
			assert((-light.global_basis.z).y < -0.5)
			var settings := lighting.world.environment
			assert(settings.ssao_enabled == (index >= 2))
			assert(not settings.sdfgi_enabled and not settings.ssil_enabled and not settings.volumetric_fog_enabled and not settings.ssr_enabled)
			# Only D enables the screen-space HD-2D stack: glow, depth fog, adjustments, filmic, far blur.
			assert(settings.glow_enabled == (index == 3) and settings.fog_enabled == (index == 3) and settings.adjustment_enabled == (index == 3))
			assert(settings.tonemap_mode == (Environment.TONE_MAPPER_FILMIC if index == 3 else Environment.TONE_MAPPER_LINEAR))
			if index == 3:
				var attributes := lighting.world.camera_attributes as CameraAttributesPractical
				assert(attributes != null and attributes.dof_blur_far_enabled and not attributes.dof_blur_near_enabled)
				# Engine properties store 32-bit floats; exported preset values are doubles.
				assert(is_equal_approx(attributes.dof_blur_far_distance, lighting.preset_d.far_blur_distance) and is_equal_approx(attributes.dof_blur_amount, lighting.preset_d.far_blur_amount))
				assert(is_equal_approx(settings.fog_density, lighting.preset_d.fog_density) and is_equal_approx(settings.glow_intensity, lighting.preset_d.glow_intensity))
			else:
				assert(lighting.world.camera_attributes == lighting.baseline_camera_attributes)
			assert(settings.reflected_light_source == lighting.baseline_environment.reflected_light_source)
			assert(Snapshots.snapshot(main.dungeon) == before and TestDungeonFactory.rng.state == rng_state and main.turn_rng.state == turn_state)
			assert(main.presentation_camera.transform == camera and visual_values(main) == visuals)
			if index == 0:
				assert(environment_values(settings) == environment)
				for property in lighting.baseline_light: assert(light.get(property) == lighting.baseline_light[property])
		var event := InputEventKey.new()
		event.keycode = KEY_F4
		event.pressed = true
		lighting._unhandled_key_input(event)
		assert(lighting.selected_preset == 1 and Snapshots.snapshot(main.dungeon) == before)
		event.echo = true
		lighting._unhandled_key_input(event)
		assert(lighting.selected_preset == 1)
		main.start_new_run()
		Helper.complete_introduction(main)
		assert(lighting.selected_preset == 1 and not lighting.world.environment.ssao_enabled)
		# Scene resources are untouched by a live preset selection.
		var other = load("res://scenes/main/main.tscn").instantiate()
		assert(environment_values(other.get_node("WorldEnvironment").environment) == environment)
		other.free()
		main.free()
	print("PASS: three inherited modes, four presets with Demo Spring HD-2D default, exact baseline roundtrip, isolated resources, F4/no echo/no turn, restart persistence, unchanged fog/materials/camera/data/RNG, bounded effects")
	quit()
