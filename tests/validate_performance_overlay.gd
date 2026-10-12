extends SceneTree

const Overlay = preload("res://scripts/ui/performance_overlay.gd")
const Helper = preload("res://tests/round_test_helper.gd")

class RenderProbe extends CompositorEffect:
	var measured := Vector2i.ZERO
	var mutex := Mutex.new()
	func _init() -> void:
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	func _render_callback(_type: int, data: RenderData) -> void:
		var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
		mutex.lock()
		measured = buffers.get_internal_size()
		mutex.unlock()
	func read_size() -> Vector2i:
		mutex.lock()
		var result := measured
		mutex.unlock()
		return result

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	assert(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920)
	assert(ProjectSettings.get_setting("display/window/size/viewport_height") == 1080)
	assert(ProjectSettings.get_setting("display/window/size/mode", 0) == 0)
	assert(ProjectSettings.get_setting("display/window/size/resizable", true))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	assert(event.is_action_pressed("toggle_performance_overlay"))
	for scene in ["main", "demo_main", "limit_testing_main"]:
		var main = load("res://scenes/main/%s.tscn" % scene).instantiate()
		root.add_child(main)
		var overlay = main.hud.get_node("Screen/PerformanceOverlay")
		overlay.set_process(false)
		assert(overlay.visible and overlay.refresh_interval == 0.5)
		assert(overlay.get_index() < main.floor_introduction.get_index())
		assert(overlay.get_index() < main.hud.get_node("Screen/GameOver").get_index())
		assert(overlay.offset_top > main.hud.get_node("Screen/MinimapPanel").offset_bottom)
		assert(overlay.statistics.text.begins_with("FPS: %d\n" % Engine.get_frames_per_second()))
		overlay.previous_usec = 0
		overlay.elapsed_usec = 0
		overlay.frame_count = 0
		var updates: int = overlay.refresh_count
		for frame in range(1, 30): overlay.sample_frame(frame * 20000)
		assert(overlay.refresh_count == updates + 1)
		assert(is_equal_approx(overlay.average_interval_ms, 20.0))
		var tile: Vector2i = main.player.grid_position
		overlay._input(event) # During authoritative introduction lock.
		assert(not overlay.visible and main.player.transition_locked and not main.resolving_turn)
		event.echo = true
		overlay._input(event)
		assert(not overlay.visible)
		event.echo = false
		Helper.complete_introduction(main)
		overlay._input(event)
		assert(overlay.visible and main.player.grid_position == tile and not main.resolving_turn)
		main.free()
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	var probe := RenderProbe.new()
	var compositor := Compositor.new()
	compositor.compositor_effects = [probe]
	camera.compositor = compositor
	var gpu := RenderingServer.get_rendering_device() != null
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1001, 701)]:
		viewport.size = size
		for scale: float in [1.0, 0.5, 0.75, 1.25]:
			viewport.scaling_3d_scale = scale
			for frame in range(4): await process_frame
			var expected := Vector2i(int(size.x * scale), int(size.y * scale))
			assert(Overlay.internal_resolution(viewport) == expected)
			if gpu:
				await RenderingServer.frame_post_draw
				assert(probe.read_size() == expected)
	viewport.free()
	print("PASS: FPS sampling, 0.5s measured frame intervals, F3 locks/echo, modes/layering, viewport resizing/scaling; GPU buffer verification=", gpu)
	quit()
