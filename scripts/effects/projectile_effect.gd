class_name ProjectileEffect
extends Node3D
## Placeholder projectile presentation. Damage and targeting are resolved by Main
## before this exists; it never reports hits and never blocks the round.

const BODY_HEIGHT: float = DungeonData.TILE_SIZE * 0.5
const SECONDS_PER_TILE: float = 0.06
const PIXEL_SIZE: float = 0.02
const TYPE_COLORS := {
	"Fire": Color(1.0, 0.5, 0.12),
	"Water": Color(0.35, 0.65, 1.0),
	"Grass": Color(0.4, 0.9, 0.3),
}
static var _textures: Dictionary = {}
var animation: Tween


static func launch(parent: Node, from: Vector3, to: Vector3, move_type: String, speed: float = 1.0) -> ProjectileEffect:
	var effect := ProjectileEffect.new()
	parent.add_child(effect)
	effect.play(from, to, move_type, speed)
	return effect


func play(from: Vector3, to: Vector3, move_type: String, speed: float = 1.0) -> void:
	global_basis = Basis.IDENTITY
	global_position = from + Vector3.UP * BODY_HEIGHT
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.pixel_size = PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.render_priority = 5
	sprite.texture = _texture_for(move_type)
	add_child(sprite)
	var tiles := maxf(1.0, from.distance_to(to) / DungeonData.TILE_SIZE)
	animation = create_tween()
	animation.set_speed_scale(maxf(0.01, speed))
	animation.tween_property(self, "global_position", to + Vector3.UP * BODY_HEIGHT, tiles * SECONDS_PER_TILE)
	animation.tween_callback(queue_free)


func finish() -> void:
	if animation != null:
		animation.kill()
	queue_free()


static func _texture_for(move_type: String) -> Texture2D:
	if _textures.has(move_type):
		return _textures[move_type]
	var color: Color = TYPE_COLORS.get(move_type, Color(0.9, 0.9, 0.9))
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(16):
		for x in range(16):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if distance <= 7.0:
				var core := color.lerp(Color.WHITE, clampf(1.0 - distance / 4.0, 0.0, 0.6))
				image.set_pixel(x, y, core)
	var texture := ImageTexture.create_from_image(image)
	_textures[move_type] = texture
	return texture
