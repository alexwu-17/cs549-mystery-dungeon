class_name ProjectileImpactEffect
extends Node3D
## Hit feedback completes before Main applies damage and begins Hurt.
signal impact_finished(played: bool)

const DURATION: float = CharacterVisual.DAMAGE_HURT_DURATION
# PixelFX fire-ring defaults to reach=92: fit the ring diameter to one tile.
const EMBER_RING_DIAMETER: float = 184.0
const EMBER_GROUND_CLEARANCE: float = 0.025
const EMBER_SMOKE_RISE: float = DungeonData.TILE_SIZE * 2.0
const EMBER_BURST: Texture2D = preload("res://assets/effects/pixelfx/ember_body_burst.png")
const EMBER_SMOKE: Texture2D = preload("res://assets/effects/pixelfx/ember_smoke.png")
const SHEET_SHADER: Shader = preload("res://scripts/effects/projectile_impact_sheet.gdshader")
const TEXTURES := {
	&"electro_ball": preload("res://assets/effects/pixelfx/electro_ball_hit.png"),
	&"healing_bloom": preload("res://assets/effects/pixelfx/healing_bloom.png"),
	&"recovery": preload("res://assets/effects/pixelfx/recovery.png"),
	&"shadow_ball": preload("res://assets/effects/pixelfx/shadow_ball_hit.png"),
	&"ember": preload("res://assets/effects/pixelfx/ember_hit.png"),
	&"razor_leaf": preload("res://assets/effects/pixelfx/razor_leaf_hit.png"),
	&"bubble": preload("res://assets/effects/pixelfx/bubble_hit.png"),
	&"scratch": preload("res://assets/effects/pixelfx/scratch_hit.png"),
	&"tackle": preload("res://assets/effects/pixelfx/basic_hit.png"),
	&"pound": preload("res://assets/effects/pixelfx/basic_hit.png"),
}
var bullet_seed: bool = false
var animation: Tween
var sprite: Sprite3D
var material: ShaderMaterial
var completed: bool = false
var duration: float = DURATION
var frame_count: int = 48
var grounded_fire: bool = false
var burst_sprite: Sprite3D
var burst_material: ShaderMaterial
var smoke_clouds: Array[Dictionary] = []
var electric_sprite: Sprite3D
var electric_material: ShaderMaterial
var electric_frames: int = 0


static func play_on_actor(target: Node3D, move_id: StringName) -> ProjectileImpactEffect:
	if not TEXTURES.has(move_id) and move_id != &"bullet_seed": return null
	var effect := ProjectileImpactEffect.new()
	target.add_child(effect)
	effect.play(target, move_id)
	return effect


func play(target: Node3D, move_id: StringName) -> void:
	if move_id in [&"tackle", &"pound"]: duration = 0.12
	var visual: CharacterVisual = target.get_node("VisualController")
	var body := visual.sprite
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(body.texture.get_size()))
	if body.texture.has_meta("pokemon_opaque_rect"):
		bounds = body.texture.get_meta("pokemon_opaque_rect")
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	var up := camera.global_basis.y if camera != null else Vector3.UP
	var rect := body.get_item_rect()
	var pixel_x := body.pixel_size * body.global_basis.x.length()
	var pixel_y := body.pixel_size * body.global_basis.y.length()
	global_basis = Basis.IDENTITY
	global_position = body.global_position + right * (rect.position.x + bounds.position.x + bounds.size.x * 0.5) * pixel_x + up * (rect.end.y - bounds.position.y - bounds.size.y * 0.5) * pixel_y
	var body_center := global_position
	sprite = Sprite3D.new()
	bullet_seed = move_id == &"bullet_seed"
	sprite.texture = ProjectileEffect._texture_for("Grass") if bullet_seed else TEXTURES[move_id]
	sprite.hframes = 6
	sprite.vframes = 8
	if move_id == &"scratch":
		sprite.hframes = 7
		sprite.vframes = 7
	if bullet_seed:
		sprite.hframes = 1
		sprite.vframes = 1
	grounded_fire = move_id == &"ember"
	if grounded_fire:
		# Full upstream fire ring, grounded and sized to roughly one tile.
		sprite.hframes = 9
		sprite.vframes = 14
		frame_count = 118
		duration = 0.5
		# Align source ground origin (112,92) to the authoritative tile surface.
		sprite.offset = Vector2(0, 28)
		var renderer: DungeonRenderer = target.get("dungeon_renderer")
		if renderer != null:
			global_position = renderer.get_entity_world_position(target.grid_position) + Vector3.UP * EMBER_GROUND_CLEARANCE
		else:
			global_position = target.global_position + Vector3.UP * EMBER_GROUND_CLEARANCE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test = true
	sprite.render_priority = 12
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body_width := bounds.size.x * pixel_x
	var width := clampf(body_width * (1.2 if move_id == &"bubble" else 1.05), 0.18, 0.8)
	if move_id == &"razor_leaf": width *= 2.0
	if move_id == &"bubble": width *= 1.4
	if move_id in [&"tackle", &"pound"]: width *= 2.5
	sprite.pixel_size = width / 64.0
	if bullet_seed:
		sprite.pixel_size = maxf(body_width, bounds.size.y * pixel_y) * 1.8 / 16.0
	if grounded_fire: sprite.pixel_size = DungeonData.TILE_SIZE / EMBER_RING_DIAMETER
	if move_id == &"shadow_ball":
		var info := SpiritombFx.layout(str(move_id) + "_hit")
		sprite.hframes = info.columns
		sprite.vframes = info.rows
		frame_count = info.frames
		var size: Vector2 = info.size
		var pivot: Vector2 = info.pivot
		sprite.offset = Vector2(size.x / 2.0 - pivot.x,pivot.y - size.y / 2.0)
		sprite.pixel_size = 0.009
		duration = 0.65
	if move_id == &"electro_ball":
		var info := SpiritombFx.layout("electro_ball_hit")
		sprite.hframes = info.columns
		sprite.vframes = info.rows
		frame_count = info.frames
		var size: Vector2 = info.size
		var pivot: Vector2 = info.pivot
		sprite.offset = Vector2(size.x * 0.5 - pivot.x, pivot.y - size.y * 0.5)
		sprite.pixel_size = maxf(body_width, 0.3) / 55.0 * 0.5
		duration = 0.45
	if move_id == &"recovery":
		var info := SpiritombFx.layout("recovery")
		sprite.hframes = info.columns
		sprite.vframes = info.rows
		frame_count = info.frames
		duration = 1.9
		# Upstream ring rises 43 pixels from its foot pivot. Fit to native body height.
		sprite.pixel_size = maxf(0.2, bounds.size.y * pixel_y) / 43.0
		var size: Vector2 = info.size
		var pivot: Vector2 = info.pivot
		sprite.offset = Vector2(size.x * 0.5 - pivot.x, pivot.y - size.y * 0.5)
		# The opaque box includes tails/asymmetric poses. Center on the native
		# foot anchor instead, which is stable across Charge animation frames.
		global_position = body.global_position + right * (rect.position.x + visual.foot_anchor.x) * pixel_x + up * (rect.end.y - visual.foot_anchor.y) * pixel_y
	if move_id == &"healing_bloom":
		var info := SpiritombFx.layout("healing_bloom")
		sprite.hframes = info.columns
		sprite.vframes = info.rows
		frame_count = info.frames
		duration = 3.3 / 1.5
		sprite.pixel_size = maxf(0.8, bounds.size.y * pixel_y * 1.3) * 1.1 / 70.0
		var size: Vector2 = info.size
		var pivot: Vector2 = info.pivot
		sprite.offset = Vector2(size.x * 0.5 - pivot.x, pivot.y - size.y * 0.5)
		global_position = body.global_position + right * (rect.position.x + visual.foot_anchor.x) * pixel_x + up * (rect.end.y - visual.foot_anchor.y) * pixel_y
	add_child(sprite)
	material = ShaderMaterial.new()
	material.shader = ProjectileEffect.BULLET_SEED_SHADER if bullet_seed else SHEET_SHADER
	material.render_priority = sprite.render_priority
	material.set_shader_parameter("sheet_texture", sprite.texture)
	material.set_shader_parameter("atlas_grid", Vector2(sprite.hframes, sprite.vframes))
	material.set_shader_parameter("last_frame", float(frame_count - 1))
	if move_id == &"recovery":
		# Fit the narrowest part of the rising hoop (24 source pixels) around
		# the body, with at least 35% extra width over the previous effect.
		material.set_shader_parameter("horizontal_scale", maxf(1.35, body_width * 1.25 / (24.0 * sprite.pixel_size)))
	if bullet_seed: material.set_shader_parameter("impact", true)
	sprite.material_override = material
	if grounded_fire:
		_add_ember_layers(body_center, body_width)
	if move_id == &"electro_ball":
		var info := SpiritombFx.layout("electro_ball_shock")
		electric_frames = info.frames
		electric_sprite = _layer_sprite(info.texture, info.columns, info.rows, maxf(body_width / 20.0, bounds.size.y * pixel_y / 30.0) * 0.5, 13)
		var size: Vector2 = info.size
		var pivot: Vector2 = info.pivot
		electric_sprite.offset = Vector2(size.x * 0.5 - pivot.x, pivot.y - size.y * 0.5)
		electric_material = electric_sprite.material_override
		electric_material.set_shader_parameter("last_frame", float(electric_frames - 1))
	_sample(0.0)
	animation = create_tween()
	animation.tween_method(_sample, 0.0, 1.0, duration)
	animation.tween_callback(_complete)


func _add_ember_layers(body_center: Vector3, body_width: float) -> void:
	burst_sprite = _layer_sprite(EMBER_BURST, 7, 7, maxf(0.2, body_width) / 90.0, 13)
	burst_sprite.offset = Vector2(0, 26)
	burst_sprite.global_position = body_center
	burst_material = burst_sprite.material_override
	for index in range(3):
		var cloud := _layer_sprite(EMBER_SMOKE, 7, 7, maxf(0.2, body_width) / 48.0, 11)
		var cloud_material: ShaderMaterial = cloud.material_override
		smoke_clouds.append({"sprite":cloud,"material":cloud_material,"origin":body_center,"delay":0.08+index*0.08,"drift":(index-1)*0.12})


func _layer_sprite(texture: Texture2D, columns: int, rows: int, pixel_size: float, priority: int) -> Sprite3D:
	var layer := Sprite3D.new()
	layer.texture = texture
	layer.hframes = columns
	layer.vframes = rows
	layer.pixel_size = pixel_size
	layer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	layer.shaded = false
	layer.no_depth_test = true
	layer.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	layer.render_priority = priority
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)
	var layer_material := ShaderMaterial.new()
	layer_material.shader = SHEET_SHADER
	layer_material.render_priority = priority
	layer_material.set_shader_parameter("sheet_texture",texture)
	layer_material.set_shader_parameter("atlas_grid",Vector2(columns,rows))
	layer_material.set_shader_parameter("last_frame",47.0)
	layer.material_override = layer_material
	return layer


func _sample_layer(layer: Sprite3D, layer_material: ShaderMaterial, progress: float) -> void:
	var frame := minf(progress*48.0,47.0)
	layer.frame = int(frame)
	layer_material.set_shader_parameter("frame_blend",fposmod(frame,1.0))
	layer_material.set_shader_parameter("fade_amount",1.0-smoothstep(0.65,1.0,progress))


func _complete() -> void:
	if completed: return
	completed = true
	impact_finished.emit(true)
	queue_free()


func _sample(progress: float) -> void:
	if electric_sprite != null:
		# Burst on arrival, then a brief body-sized electric crackle; no status effect.
		var shock_progress := clampf((progress - 0.35) / 0.65, 0.0, 1.0)
		electric_sprite.visible = progress >= 0.35
		var shock_frame := minf(shock_progress * electric_frames, float(electric_frames - 1))
		electric_sprite.frame = int(shock_frame)
		electric_material.set_shader_parameter("frame_blend", fposmod(shock_frame, 1.0))
		electric_material.set_shader_parameter("fade_amount", 1.0 - smoothstep(0.7, 1.0, shock_progress))
	if bullet_seed:
		material.set_shader_parameter("progress", progress)
		return
	var frame := minf(progress * frame_count, float(frame_count - 1))
	sprite.frame = int(frame)
	material.set_shader_parameter("frame_blend", fposmod(frame, 1.0))
	material.set_shader_parameter("fade_amount", 1.0 if grounded_fire else 1.0 - smoothstep(0.65, 1.0, progress))
	if burst_sprite != null:
		_sample_layer(burst_sprite,burst_material,progress)
		var camera := get_viewport().get_camera_3d()
		var right := camera.global_basis.x if camera != null else Vector3.RIGHT
		for cloud in smoke_clouds:
			var age := clampf((progress-float(cloud.delay))/(1.0-float(cloud.delay)),0.0,1.0)
			cloud.sprite.visible = progress >= float(cloud.delay)
			cloud.sprite.global_position = Vector3(cloud.origin)+Vector3.UP*EMBER_SMOKE_RISE*age+right*float(cloud.drift)*age
			_sample_layer(cloud.sprite,cloud.material,age)


func finish() -> void:
	if animation != null: animation.kill()
	if not completed:
		completed = true
		impact_finished.emit(false)
	queue_free()
