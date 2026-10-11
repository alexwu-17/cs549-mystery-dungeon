extends Camera3D

@export var follow_enabled: bool = true
# 3.75x magnification from the original 75-degree perspective field of view.
@export_range(5.0, 100.0) var field_of_view: float = 23.128519
@export var follow_offset: Vector3 = Vector3(0, 10, 8)

var sampled_texture: Texture2D
var opaque_uvs: Array[Vector2] = []


func follow_sprite(sprite: Sprite3D) -> void:
	fov = field_of_view
	if follow_enabled:
		# Restore the original perspective framing, anchored to the player's feet.
		global_position = sprite.get_parent().global_position + follow_offset


func sprite_samples(sprite: Sprite3D) -> Array[Vector3]:
	# Sample only opaque texels inside the rendered billboard, not nearby space.
	if sampled_texture != sprite.texture:
		sampled_texture = sprite.texture
		opaque_uvs.clear()
		if sampled_texture != null:
			var image := sampled_texture.get_image()
			if image.is_compressed():
				image.decompress()
			for y in range(9):
				for x in range(9):
					var uv := Vector2((x + 0.5) / 9.0, (y + 0.5) / 9.0)
					if image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height())).a > 0.5:
						opaque_uvs.append(uv)
	var points: Array[Vector3] = []
	var rect := sprite.get_item_rect()
	for uv in opaque_uvs:
		var pixel := rect.position + rect.size * uv
		points.append(sprite.global_position + global_basis.x * pixel.x * sprite.pixel_size * sprite.global_basis.x.length() - global_basis.y * pixel.y * sprite.pixel_size * sprite.global_basis.y.length())
	return points
