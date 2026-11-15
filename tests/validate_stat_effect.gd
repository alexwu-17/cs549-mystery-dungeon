extends SceneTree

class TestVisual extends CharacterVisual:
	func _ready() -> void:
		sprite = get_node(sprite_path)

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var body := Sprite3D.new()
	body.name = "Body"
	body.texture = ImageTexture.create_from_image(Image.create(32, 40, false, Image.FORMAT_RGBA8))
	body.texture.set_meta("pokemon_opaque_rect", Rect2i(4, 5, 20, 30))
	body.pixel_size = 0.04
	target.add_child(body)
	body.position.y = 0.6
	var visual := TestVisual.new()
	visual.name = "VisualController"
	visual.sprite_path = NodePath("../Body")
	target.add_child(visual)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.rotation = Vector3(-0.8, 0.4, 0)
	camera.make_current()
	var right := camera.global_basis.x.normalized()
	var up_axis := camera.global_basis.y.normalized()
	var up := StatChangeEffect.play_above_actor(target, true)
	var down := StatChangeEffect.play_above_actor(target, false)
	var offset := Vector3(0, 0.2, 0.5)
	var shifted := StatChangeEffect.play_stat_change(target, true, offset)
	var center := body.global_position - right * 0.08
	assert(up.global_position.is_equal_approx(center) and down.global_position.is_equal_approx(center))
	assert(shifted.global_position.is_equal_approx(center + offset))
	assert(up.duration == 0.6 and up.arrows.size() == 3 and down.arrows.size() == 3)
	var initial: Array[Vector3] = []
	for index in range(3):
		var a := up.arrows[index]
		assert(is_equal_approx(a.pixel_size, 0.014) and a.hframes == 6 and a.vframes == 8)
		assert(a.no_depth_test and a.render_priority > 0 and a.modulate.a == 0.0)
		# Opposite travel directions share identical midpoint placements.
		assert((a.position + up_axis * StatChangeEffect.TRAVEL * 0.5).is_equal_approx(down.arrows[index].position - up_axis * StatChangeEffect.TRAVEL * 0.5))
		initial.append(a.position)
	assert(initial[0].dot(right) < 0 and initial[0].dot(up_axis) > 0)
	assert(initial[1].dot(right) > 0)
	assert(initial[2].dot(right) < 0 and initial[2].dot(up_axis) < 0)
	assert(up.arrow.texture.get_image().get_pixel(32, 16).g > up.arrow.texture.get_image().get_pixel(32, 16).r)
	assert(down.arrow.texture.get_image().get_pixel(32, 32).r > down.arrow.texture.get_image().get_pixel(32, 32).g)
	for effect in [up, down, shifted]:
		effect.animation.pause()
		effect.animation.custom_step(0.12)
		assert(effect.arrow.frame > 0 and is_equal_approx(effect.sheet_material.get_shader_parameter("fade_amount"), 1.0))
		for a in effect.arrows:
			assert(a.frame == effect.arrow.frame and a.modulate.a == effect.arrow.modulate.a)
	for index in range(3):
		assert((up.arrows[index].position - initial[index]).dot(up_axis) > 0)
	for effect in [up, down, shifted]:
		effect.animation.custom_step(0.49)
	await process_frame
	assert(not is_instance_valid(up) and not is_instance_valid(down) and not is_instance_valid(shifted))
	target.free()
	camera.free()
	print("PASS: three smaller stat arrows, opaque-body centering, upper-left/right/lower-left layout shared by up/down, screen-plane travel, synchronized frames/fade and cleanup")
	quit()
