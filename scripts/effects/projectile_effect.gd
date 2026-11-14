class_name ProjectileEffect
extends Node3D
## Projectile presentation. Damage and targeting are resolved by Main
## before this exists; it never reports hits and never blocks the round.

const BODY_HEIGHT: float = DungeonData.TILE_SIZE * 0.5
# Shared travel time at normal action speed; higher action speeds shorten it.
const SECONDS_PER_TILE: float = 0.2
const PIXEL_SIZE: float = 0.02
const EMBER_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/fireball.png")
const EMBER_FRAME_COUNT: int = 36
const EMBER_FPS: float = 30.0
const EMBER_SHADER: Shader = preload("res://scripts/effects/ember_projectile.gdshader")
const TYPE_COLORS := {
	"Fire": Color(1.0, 0.5, 0.12),
	"Water": Color(0.35, 0.65, 1.0),
	"Grass": Color(0.4, 0.9, 0.3),
}
static var _textures: Dictionary = {}
var animation: Tween
var sprite: Sprite3D
var ember_material: ShaderMaterial


func set_behind_source(behind: bool) -> void:
	# Front shots retain their original draw priority. Side/back shots share
	# the shooter's transparent pass and must sort below its normal priority 0.
	sprite.render_priority = -1 if behind else 5
	if ember_material != null:
		ember_material.render_priority = sprite.render_priority


static func launch(parent: Node, from: Vector3, to: Vector3, move_type: String, speed: float = 1.0, release_delay: float = 0.0, move_id: StringName = &"") -> ProjectileEffect:
	var effect := ProjectileEffect.new()
	parent.add_child(effect)
	effect.play(from, to, move_type, speed, release_delay, move_id)
	return effect


func play(from: Vector3, to: Vector3, move_type: String, speed: float = 1.0, release_delay: float = 0.0, move_id: StringName = &"") -> void:
	global_basis = Basis.IDENTITY
	global_position = from + Vector3.UP * BODY_HEIGHT
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.pixel_size = PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.render_priority = 5
	sprite.texture = _texture_for(move_type)
	add_child(sprite)
	if move_id == &"ember":
		_configure_ember(to - from)
	var tiles := maxf(1.0, from.distance_to(to) / DungeonData.TILE_SIZE)
	animation = create_tween()
	animation.set_speed_scale(maxf(0.01, speed))
	if release_delay > 0.0:
		hide()
		animation.tween_interval(release_delay)
		animation.tween_callback(show)
	animation.tween_property(self, "global_position", to + Vector3.UP * BODY_HEIGHT, tiles * SECONDS_PER_TILE)
	if move_id == &"ember":
		animation.parallel().tween_method(_set_ember_time, 0.0, tiles * SECONDS_PER_TILE, tiles * SECONDS_PER_TILE)
	animation.chain().tween_callback(queue_free)


func _configure_ember(direction: Vector3) -> void:
	sprite.texture = EMBER_TEXTURE
	sprite.hframes = 4
	sprite.vframes = 9
	# Source frames are 136x56; the flame head's pivot is (112, 28).
	# Keep that head at the release point rather than centering the long tail.
	sprite.offset = Vector2(-44, 0)
	ember_material = ShaderMaterial.new()
	ember_material.shader = EMBER_SHADER
	ember_material.render_priority = sprite.render_priority
	ember_material.set_shader_parameter("fireball_texture", EMBER_TEXTURE)
	sprite.material_override = ember_material
	_set_ember_time(0.0)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Rotate within the camera plane. World cardinal directions project at
	# different angles under perspective; billboard rotation would be discarded.
	var camera_basis := camera.global_basis.orthonormalized()
	var projected := Vector2(direction.dot(camera_basis.x), direction.dot(camera_basis.y))
	if projected.is_zero_approx():
		return
	var angle := projected.angle()
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.global_basis = Basis(
		camera_basis.x * cos(angle) + camera_basis.y * sin(angle),
		-camera_basis.x * sin(angle) + camera_basis.y * cos(angle),
		camera_basis.z)


func _set_ember_time(time: float) -> void:
	var source_frame := time * EMBER_FPS
	sprite.frame = int(source_frame) % EMBER_FRAME_COUNT
	ember_material.set_shader_parameter("frame_blend", fposmod(source_frame, 1.0))
	# Use distance traveled, not normalized flight length: an adjacent hit
	# retains its early shape instead of compressing the four-tile lifecycle.
	var tiles := time / SECONDS_PER_TILE
	var trail := smoothstep(0.625, 2.15, tiles) * (1.0 - smoothstep(2.25, 4.0, tiles))
	var fade := 1.0 - smoothstep(2.25, 4.0, tiles)
	ember_material.set_shader_parameter("trail_amount", trail)
	ember_material.set_shader_parameter("fade_amount", fade)


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
