extends Camera3D

@export var follow_enabled: bool = true
# 3.75x magnification from the original 75-degree perspective field of view.
@export_range(5.0, 100.0) var field_of_view: float = 23.128519
@export_range(10.0, 80.0) var pitch_degrees: float = 35.0
@export var follow_distance: float = Vector3(0, 10, 8).length()
var follow_offset: Vector3:
	get:
		var pitch := deg_to_rad(pitch_degrees)
		return Vector3(0, sin(pitch), cos(pitch)) * follow_distance

# Masks only: never retain decoded images or keep old floor textures alive.
const SPRITE_SAMPLE_CACHE_LIMIT := 64
var _sprite_sample_cache: Dictionary = {}
var _sample_clock: int = 0


func follow_sprite(sprite: Sprite3D) -> void:
	fov = field_of_view
	rotation_degrees.x = -pitch_degrees
	if follow_enabled:
		# Rotate the follow offset with the pitch, preserving distance and zoom.
		global_position = sprite.get_parent().global_position + follow_offset


func sprite_samples(sprite: Sprite3D) -> Array[Vector3]:
	# Sample only opaque texels inside the rendered billboard, not nearby space.
	var opaque_uvs := _sprite_opaque_uvs(sprite.texture)
	var points: Array[Vector3] = []
	var rect := sprite.get_item_rect()
	for uv in opaque_uvs:
		var pixel := Vector2(rect.position.x + rect.size.x * uv.x, rect.position.y + rect.size.y * (1.0 - uv.y))
		points.append(sprite.global_position + global_basis.x * pixel.x * sprite.pixel_size * sprite.global_basis.x.length() + global_basis.y * pixel.y * sprite.pixel_size * sprite.global_basis.y.length())
	return points


func _sprite_opaque_uvs(texture: Texture2D) -> PackedVector2Array:
	if texture == null:
		return PackedVector2Array()
	# Immutable Pokémon atlas masks are prepared once with their species library.
	if texture is AtlasTexture and texture.has_meta("pokemon_opaque_uvs"):
		return texture.get_meta("pokemon_opaque_uvs")
	var id := texture.get_instance_id()
	_sample_clock += 1
	if _sprite_sample_cache.has(id):
		var entry: Dictionary = _sprite_sample_cache[id]
		if entry.texture.get_ref() == texture:
			entry.used = _sample_clock
			return entry.uvs
		_remove_sprite_sample(id)
	var image := texture.get_image()
	# Uninitialized textures may become readable later; don't cache a failure.
	if image == null or image.is_empty():
		return PackedVector2Array()
	if image.is_compressed() and image.decompress() != OK:
		return PackedVector2Array()
	var uvs := PackedVector2Array()
	for y in range(9):
		for x in range(9):
			var uv := Vector2((x + 0.5) / 9.0, (y + 0.5) / 9.0)
			if image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height())).a > 0.5:
				uvs.append(uv)
	# Prune released resources and evict the least recently sampled mask.
	for cached_id in _sprite_sample_cache.keys():
		if _sprite_sample_cache[cached_id].texture.get_ref() == null:
			_remove_sprite_sample(cached_id)
	if _sprite_sample_cache.size() >= SPRITE_SAMPLE_CACHE_LIMIT:
		var oldest: int = _sprite_sample_cache.keys()[0]
		for cached_id in _sprite_sample_cache:
			if _sprite_sample_cache[cached_id].used < _sprite_sample_cache[oldest].used:
				oldest = cached_id
		_remove_sprite_sample(oldest)
	_sprite_sample_cache[id] = {"texture": weakref(texture), "uvs": uvs, "used": _sample_clock}
	# Handles same-resource updates/reimports as well as sprite texture replacement.
	texture.changed.connect(_remove_sprite_sample.bind(id))
	return uvs


func _remove_sprite_sample(id: int) -> void:
	if not _sprite_sample_cache.has(id):
		return
	var texture: Texture2D = _sprite_sample_cache[id].texture.get_ref()
	var callback := _remove_sprite_sample.bind(id)
	if texture != null and texture.changed.is_connected(callback):
		texture.changed.disconnect(callback)
	_sprite_sample_cache.erase(id)


func clear_sprite_sample_cache() -> void:
	for id in _sprite_sample_cache.keys():
		_remove_sprite_sample(id)
	_sample_clock = 0


func _exit_tree() -> void:
	clear_sprite_sample_cache()
