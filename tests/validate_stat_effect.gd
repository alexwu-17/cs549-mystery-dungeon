extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.rotation = Vector3(-0.8, 0.4, 0)
	camera.make_current()
	var up := StatChangeEffect.play_stat_change(target, true)
	var down := StatChangeEffect.play_stat_change(target, false)
	var shifted := StatChangeEffect.play_stat_change(target, true, Vector3(0, 0.2, 0.5))
	var base := target.global_position - camera.global_basis.x.normalized() * DungeonData.TILE_SIZE * 0.35 + Vector3.UP * DungeonData.TILE_SIZE * 0.4
	assert(up.global_position.is_equal_approx(base) and down.global_position.is_equal_approx(base))
	assert(shifted.global_position.is_equal_approx(base + Vector3(0, 0.2, 0.5)))
	assert(is_equal_approx(up.duration, 0.3) and is_equal_approx(up.arrow.pixel_size, 0.024))
	assert(up.arrow.position == Vector3.ZERO and is_equal_approx(down.arrow.position.y, DungeonData.TILE_SIZE * 0.5))
	assert(up.arrow.modulate.a == 0 and down.arrow.modulate.a == 0)
	assert(up.arrow.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(up.arrow.no_depth_test and up.arrow.render_priority > 0)
	var up_image := up.arrow.texture.get_image()
	var down_image := down.arrow.texture.get_image()
	assert(up_image.get_pixel(12, 0).g > up_image.get_pixel(12, 0).r)
	assert(down_image.get_pixel(12, 31).r > down_image.get_pixel(12, 31).g)
	for effect in [up, down, shifted]:
		effect.animation.pause()
		effect.animation.custom_step(0.06)
	assert(up.arrow.position.y > 0 and down.arrow.position.y < StatChangeEffect.TRAVEL)
	assert(is_equal_approx(up.arrow.modulate.a, 1.0) and is_equal_approx(down.arrow.modulate.a, 1.0))
	for effect in [up, down, shifted]:
		effect.animation.custom_step(0.20)
		assert(effect.arrow.position.x == 0 and effect.arrow.position.z == 0)
		assert(effect.arrow.modulate.a > 0 and effect.arrow.modulate.a < 1)
	assert(up.global_position.is_equal_approx(base))
	for effect in [up, down, shifted]:
		effect.animation.custom_step(0.04)
	assert(is_equal_approx(up.arrow.position.y, StatChangeEffect.TRAVEL))
	assert(is_zero_approx(down.arrow.position.y))
	assert(is_equal_approx(shifted.arrow.position.y, StatChangeEffect.TRAVEL))
	for effect in [up, down, shifted]:
		effect.animation.custom_step(0.01)
	await process_frame
	assert(not is_instance_valid(up) and not is_instance_valid(down) and not is_instance_valid(shifted))
	target.free()
	camera.free()
	print("PASS: 60% arrows, 0.3s, camera-left anchors/offsets, fixed X/Z, half-tile vertical motion, fade-in/out/cleanup")
	quit()
