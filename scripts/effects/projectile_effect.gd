class_name ProjectileEffect
extends Node3D
## Grid targeting belongs to Main; arrival gates when Main applies the result.
signal flight_finished(arrived: bool)

const BODY_HEIGHT: float = DungeonData.TILE_SIZE * 0.5
# Shared travel time at normal action speed; higher action speeds shorten it.
const SECONDS_PER_TILE: float = 0.2
const PIXEL_SIZE: float = 0.02
const EMBER_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/fireball.png")
const EMBER_FRAME_COUNT: int = 36
const EMBER_FPS: float = 30.0
const EMBER_SHADER: Shader = preload("res://scripts/effects/ember_projectile.gdshader")
const SHEET_SHADER: Shader = preload("res://scripts/effects/projectile_sheet.gdshader")
const DRAGON_BREATH_VISUAL_SCALE: float = 3.0
const DRAGON_BREATH_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/dragon_breath.png")
const BUBBLE_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/bubble.png")
const LEAF_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/razor_leaf.png")
const LEAF_FRONT_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/razor_leaf_front.png")
const GROUND_SHADOW = preload("res://scripts/effects/projectile_ground_shadow.gd")
const TYPE_COLORS := {
	"Fire": Color(1.0, 0.5, 0.12),
	"Water": Color(0.35, 0.65, 1.0),
	"Grass": Color(0.4, 0.9, 0.3),
}
static var _textures: Dictionary = {}
const BULLET_SEED_SHADER: Shader = preload("res://scripts/effects/bullet_seed.gdshader")
var spirit_move: StringName = &""
var spirit_frames: int = 48
var spirit_travel_duration: float = 1.0
var animation: Tween
var sprite: Sprite3D
var ember_material: ShaderMaterial
var sheet_material: ShaderMaterial
var ground_shadow: MeshInstance3D
var flight_direction := Vector3.ZERO
var flight_completed: bool = false
var impact_pending: bool = false
var dragon_breath: bool = false
var breath_origin := Vector3.ZERO
var breath_duration: float = 0.4
var seed_material: ShaderMaterial
var seed_projection: float = 1.0
var ember_light: OmniLight3D


func set_behind_source(behind: bool) -> void:
	# Front shots retain their original draw priority. Side/back shots share
	# the shooter's transparent pass and must sort below its normal priority 0.
	sprite.render_priority = -1 if behind else 5
	if ember_material != null:
		ember_material.render_priority = sprite.render_priority
	if sheet_material != null:
		sheet_material.render_priority = sprite.render_priority
	if sprite.material_override != null:
		sprite.material_override.render_priority = sprite.render_priority


static func launch(parent: Node, from: Vector3, to: Vector3, move_type: String, speed: float = 1.0, release_delay: float = 0.0, move_id: StringName = &"") -> ProjectileEffect:
	var effect := ProjectileEffect.new()
	parent.add_child(effect)
	effect.play(from, to, move_type, speed, release_delay, move_id)
	return effect


func play(from: Vector3, to: Vector3, move_type: String, speed: float = 1.0, release_delay: float = 0.0, move_id: StringName = &"") -> void:
	flight_direction = to - from
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
	if move_id in [&"shadow_ball", &"electro_ball"]:
		_configure_spiritomb(to - from, move_id)
	elif move_id == &"bullet_seed":
		_configure_bullet_seed(to - from)
	elif move_id == &"ember":
		_configure_ember(to - from)
	elif move_id in [&"bubble", &"razor_leaf", &"dragon_breath"]:
		_configure_sheet(to - from, move_id)
	var tiles := maxf(1.0, from.distance_to(to) / DungeonData.TILE_SIZE)
	var travel_time := tiles * SECONDS_PER_TILE
	if move_id == &"electro_ball": travel_time *= 0.5
	spirit_travel_duration = travel_time
	animation = create_tween()
	animation.set_speed_scale(maxf(0.01, speed))
	if release_delay > 0.0:
		hide()
		animation.tween_interval(release_delay)
		animation.tween_callback(show)
	animation.tween_property(self, "global_position", to + Vector3.UP * BODY_HEIGHT, travel_time)
	if move_id == &"ember":
		animation.parallel().tween_method(_set_ember_time, 0.0, tiles * SECONDS_PER_TILE, travel_time)
	elif seed_material != null:
		animation.parallel().tween_method(_set_seed_time, 0.0, tiles * SECONDS_PER_TILE, travel_time)
	elif sheet_material != null:
		animation.parallel().tween_method(_set_sheet_time, 0.0, travel_time, travel_time)
	animation.chain().tween_callback(_arrive)


func _arrive() -> void:
	if flight_completed:
		return
	flight_completed = true
	if ember_light != null: ember_light.light_energy = 0.0
	flight_finished.emit(true)
	queue_free()


func _configure_spiritomb(direction: Vector3, move_id: StringName) -> void:
	spirit_move = move_id
	var info := SpiritombFx.layout(str(move_id))
	spirit_frames = info.frames
	sprite.texture = info.texture
	sprite.hframes = info.columns
	sprite.vframes = info.rows
	var size: Vector2 = info.size
	var pivot: Vector2 = info.pivot
	sprite.offset = Vector2(size.x / 2.0 - pivot.x, pivot.y - size.y / 2.0)
	sprite.pixel_size = 0.022 if move_id == &"electro_ball" else 0.0126
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet_material = ShaderMaterial.new()
	sheet_material.shader = SHEET_SHADER
	sheet_material.render_priority = sprite.render_priority
	sheet_material.set_shader_parameter("sheet_texture",sprite.texture)
	sheet_material.set_shader_parameter("atlas_grid",Vector2(info.columns,info.rows))
	sheet_material.set_shader_parameter("last_frame",float(spirit_frames-1))
	sheet_material.set_shader_parameter("camera_facing", move_id != &"electro_ball")
	sheet_material.set_shader_parameter("stable_atlas", true)
	# Keep one immutable quad; the shader changes frames without Sprite3D mesh
	# rebuilds. Cover the camera-facing plane rather than its old vertical AABB.
	sprite.extra_cull_margin = 2.0
	sprite.ignore_occlusion_culling = true
	sprite.material_override = sheet_material
	if move_id == &"electro_ball": _orient_to_lane(direction)
	_set_sheet_time(0.0)

func _configure_bullet_seed(direction: Vector3) -> void:
	# One travelling effect and one arrival: the five bullets never deal separate hits.
	sprite.pixel_size = DungeonData.TILE_SIZE * 1.2 / 16.0
	sprite.offset = Vector2(-6.08, 0) # Leading seed at UV x=0.88 is the lane endpoint.
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seed_material = ShaderMaterial.new()
	seed_material.shader = BULLET_SEED_SHADER
	seed_material.render_priority = sprite.render_priority
	var camera := get_viewport().get_camera_3d()
	if camera != null and not direction.is_zero_approx():
		var lane := direction.normalized()
		seed_projection = Vector2(lane.dot(camera.global_basis.x), lane.dot(camera.global_basis.y)).length()
	_set_seed_time(0.0)
	sprite.material_override = seed_material
	_orient_to_lane(direction)


func _set_seed_time(time: float) -> void:
	# Reveal each seed/wake only after it has passed the shooter's mouth.
	var traveled := time / SECONDS_PER_TILE * DungeonData.TILE_SIZE * seed_projection
	seed_material.set_shader_parameter("release_edge", 0.88 - traveled / (DungeonData.TILE_SIZE * 1.2))


func _configure_ember(direction: Vector3) -> void:
	sprite.texture = EMBER_TEXTURE
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	ember_light = OmniLight3D.new()
	ember_light.light_color = Color(1.0, 0.97, 0.82)
	ember_light.shadow_enabled = false
	ember_light.light_specular = 0.15
	ember_light.light_volumetric_fog_energy = 0.0
	add_child(ember_light)
	_set_ember_time(0.0)
	_orient_to_lane(direction)


func _configure_sheet(direction: Vector3, move_id: StringName) -> void:
	dragon_breath = move_id == &"dragon_breath"
	sprite.texture = DRAGON_BREATH_TEXTURE if dragon_breath else (BUBBLE_TEXTURE if move_id == &"bubble" else LEAF_TEXTURE)
	if move_id == &"razor_leaf" and absf(direction.z) > absf(direction.x):
		# World Z is grid up/down; only side shots use the tilted blade plane.
		sprite.texture = LEAF_FRONT_TEXTURE
	sprite.hframes = 6
	sprite.vframes = 8
	# 64x48 frames with the leading bubble/leaf anchored at (48, 24).
	sprite.offset = Vector2(-16, 0)
	if dragon_breath:
		breath_origin = global_position
		breath_duration = maxf(SECONDS_PER_TILE, direction.length() * SECONDS_PER_TILE)
		var camera := get_viewport().get_camera_3d()
		var projected_length := direction.length()
		if camera != null:
			projected_length = Vector2(direction.dot(camera.global_basis.x), direction.dot(camera.global_basis.y)).length()
		sprite.pixel_size = maxf(0.001, projected_length / 170.0) * DRAGON_BREATH_VISUAL_SCALE
		sprite.offset = Vector2(80, -2) # Frost Breath mouth at (12,50) in184x104.
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet_material = ShaderMaterial.new()
	sheet_material.shader = SHEET_SHADER
	sheet_material.render_priority = sprite.render_priority
	sheet_material.set_shader_parameter("sheet_texture", sprite.texture)
	sprite.material_override = sheet_material
	_set_sheet_time(0.0)
	_orient_to_lane(direction)


func _set_sheet_time(time: float) -> void:
	if spirit_move != &"":
		var source := fposmod(time * 30.0,spirit_frames)
		sprite.frame = 0
		sheet_material.set_shader_parameter("source_frame",source)
		sheet_material.set_shader_parameter("frame_blend", fposmod(source,1.0))
		var fade := 1.0 if impact_pending else 1.0 - smoothstep(0.75,1.0,time / spirit_travel_duration)
		sheet_material.set_shader_parameter("fade_amount", fade)
		return
	# These sheets encode growth over a four-tile flight, not a repeating loop.
	var source_frame := minf(time * (40.0 if dragon_breath else 60.0), 47.0)
	sprite.frame = int(source_frame)
	sheet_material.set_shader_parameter("frame_blend", fposmod(source_frame, 1.0))
	if dragon_breath:
		# The breath stays at the shooter's mouth while its visible cone reaches
		# the planned endpoint. Scale the art up but crop it earlier so its
		# enlarged cone never extends beyond the same two-tile lane.
		sprite.global_position = breath_origin
		sheet_material.set_shader_parameter("cutoff_x", lerpf(12.0, 12.0 + 170.0 / DRAGON_BREATH_VISUAL_SCALE, clampf(time / breath_duration, 0.0, 1.0)) / 184.0)
	var fade := 1.0 if dragon_breath else 1.0 - smoothstep(2.75, 4.0, time / SECONDS_PER_TILE)
	if impact_pending:
		fade = maxf(0.35, fade)
	sheet_material.set_shader_parameter("fade_amount", fade)
	if ground_shadow != null:
		ground_shadow.update_projection(global_position, time)


func add_ground_shadow(data: DungeonData, renderer: Node3D) -> void:
	if sheet_material == null or dragon_breath or spirit_move != &"":
		return
	ground_shadow = GROUND_SHADOW.new()
	add_child(ground_shadow)
	ground_shadow.setup(data, renderer, sprite.texture, flight_direction, sprite.texture == BUBBLE_TEXTURE)
	ground_shadow.update_projection(global_position, 0.0)


func _orient_to_lane(direction: Vector3) -> void:
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
	if impact_pending:
		fade = maxf(0.35, fade)
	ember_material.set_shader_parameter("trail_amount", trail)
	ember_material.set_shader_parameter("fade_amount", fade)
	# Cosmetic illumination only: no fog/discovery updates or material changes.
	# The same envelope drives artwork and light, including the hit opacity floor.
	if ember_light != null:
		ember_light.light_energy = (0.55 + 0.95 * trail) * fade
		ember_light.omni_range = maxf(0.05, DungeonData.TILE_SIZE * (0.9 + 1.1 * trail) * sqrt(fade))


func finish() -> void:
	if ember_light != null: ember_light.light_energy = 0.0
	if animation != null:
		animation.kill()
	if not flight_completed:
		flight_completed = true
		flight_finished.emit(false)
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
