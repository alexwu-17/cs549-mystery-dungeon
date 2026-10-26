extends SceneTree
const CameraScript = preload("res://scripts/core/presentation_camera.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var camera := CameraScript.new()
	var sprite := Sprite3D.new()
	root.add_child(camera)
	root.add_child(sprite)
	var textures: Array[Texture2D] = []
	var image := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	image.set_pixel(2, 3, Color(1, 1, 1, 1))
	image.set_pixel(4, 5, Color(1, 1, 1, 0.5))
	var first := ImageTexture.create_from_image(image)
	image.set_pixel(7, 1, Color(1, 1, 1, 1))
	var second := ImageTexture.create_from_image(image)
	for index in range(8):
		sprite.texture = first if index % 2 == 0 else second
		sprite.position.x = index
		sprite.pixel_size = 0.02 + index * 0.001
		var points: Array[Vector3] = camera.sprite_samples(sprite)
		# Only (2,3), plus (7,1) for second, pass the original strict alpha > .5.
		assert(points.size() == (1 if sprite.texture == first else 2))
		var uv := Vector2(2.5 / 9.0, 3.5 / 9.0)
		var rect := sprite.get_item_rect()
		var expected := sprite.global_position + camera.global_basis.x * (rect.position.x + rect.size.x * uv.x) * sprite.pixel_size + camera.global_basis.y * (rect.position.y + rect.size.y * (1.0 - uv.y)) * sprite.pixel_size
		assert(points[0 if sprite.texture == first else 1].is_equal_approx(expected))
	assert(camera._sprite_sample_cache.size() == 2)
	# Same resource, changed pixels: changed signal must invalidate immediately.
	sprite.texture = first
	image.fill(Color.TRANSPARENT)
	first.update(image)
	assert(not camera._sprite_sample_cache.has(first.get_instance_id()))
	# Dummy rendering doesn't read back ImageTexture.update pixels correctly.
	if DisplayServer.get_name() != "headless":
		assert(camera.sprite_samples(sprite).is_empty())
	image.fill(Color.WHITE)
	first.set_image(image)
	assert(not camera._sprite_sample_cache.has(first.get_instance_id()))
	if DisplayServer.get_name() == "headless":
		# Dummy also lacks texture replacement readback; use a fresh GPU resource.
		first = ImageTexture.create_from_image(image)
		sprite.texture = first
	assert(camera.sprite_samples(sprite).size() == 81)
	sprite.texture = null
	assert(camera.sprite_samples(sprite).is_empty())
	# Resource release is not prevented by cache or changed-signal bindings.
	var transient := ImageTexture.create_from_image(image)
	var released: WeakRef = weakref(transient)
	sprite.texture = transient
	camera.sprite_samples(sprite)
	sprite.texture = null
	transient = null
	assert(released.get_ref() == null)
	# Keep resources live to exercise eviction rather than just weak-ref pruning.
	for index in range(camera.SPRITE_SAMPLE_CACHE_LIMIT + 5):
		var texture := ImageTexture.create_from_image(image)
		textures.append(texture)
		sprite.texture = texture
		camera.sprite_samples(sprite)
		assert(camera._sprite_sample_cache.size() <= camera.SPRITE_SAMPLE_CACHE_LIMIT)
	assert(camera._sprite_sample_cache.size() == camera.SPRITE_SAMPLE_CACHE_LIMIT)
	assert(not camera._sprite_sample_cache.has(first.get_instance_id()))
	# Evicted resources remain usable and all masks can be explicitly invalidated.
	sprite.texture = first
	assert(camera.sprite_samples(sprite).size() == 81)
	camera.clear_sprite_sample_cache()
	assert(camera._sprite_sample_cache.is_empty())
	assert(not first.changed.is_connected(camera._remove_sprite_sample.bind(first.get_instance_id())))
	sprite.free()
	camera.free()
	print("PASS: sprite mask parity, alternating frames, updates/replacement, weak ownership, eviction and clear")
	quit()

