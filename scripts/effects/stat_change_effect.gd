class_name StatChangeEffect
extends Node3D

@export var duration: float = 0.6
@export var anchor_offset: Vector3 = Vector3.ZERO
const TRAVEL: float = DungeonData.TILE_SIZE * 0.18
const ARROW_PIXEL_SIZE: float = 0.014
const UP_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/stat_up.png")
const DOWN_TEXTURE: Texture2D = preload("res://assets/effects/pixelfx/stat_down.png")
const SHEET_SHADER: Shader = preload("res://scripts/effects/stat_change_sheet.gdshader")
var animation: Tween
var arrow: Sprite3D
var arrows: Array[Sprite3D] = []
var sheet_material: ShaderMaterial

static func play_above_actor(target: Node3D, is_increase: bool) -> StatChangeEffect:
	return play_stat_change(target, is_increase)

static func play_stat_change(target: Node3D, is_increase: bool, offset: Vector3 = Vector3.ZERO) -> StatChangeEffect:
	var effect: StatChangeEffect = load("res://scenes/effects/stat_change_effect.tscn").instantiate()
	target.add_child(effect)
	effect.play(is_increase, offset)
	return effect

func play(is_increase: bool, offset: Vector3 = Vector3.ZERO) -> void:
	anchor_offset = offset
	var camera := get_viewport().get_camera_3d()
	var screen_right := camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	var screen_up := camera.global_basis.y.normalized() if camera != null else Vector3.UP
	var center: Vector3 = get_parent().global_position + Vector3.UP * 0.4
	var half_width := 0.25
	var half_height := 0.3
	var visual: CharacterVisual = get_parent().get_node_or_null("VisualController")
	if visual != null and visual.sprite.texture != null:
		var body := visual.sprite
		var bounds := Rect2i(Vector2i.ZERO, Vector2i(body.texture.get_size()))
		if body.texture.has_meta("pokemon_opaque_rect"):
			bounds = body.texture.get_meta("pokemon_opaque_rect")
		var rect := body.get_item_rect()
		var pixel_x := (rect.position.x + bounds.position.x + bounds.size.x * 0.5) * body.pixel_size * body.global_basis.x.length()
		var pixel_y := (rect.end.y - bounds.position.y - bounds.size.y * 0.5) * body.pixel_size * body.global_basis.y.length()
		center = body.global_position + screen_right * pixel_x + screen_up * pixel_y
		half_width = maxf(0.18, bounds.size.x * body.pixel_size * body.global_basis.x.length() * 0.5)
		half_height = maxf(0.2, bounds.size.y * body.pixel_size * body.global_basis.y.length() * 0.5)
	global_basis = Basis.IDENTITY
	global_position = center + anchor_offset
	arrow = Sprite3D.new()
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.pixel_size = ARROW_PIXEL_SIZE
	arrow.shaded = false
	arrow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# The bottom-left tile anchor lies behind large billboard bodies. Draw this
	# short-lived feedback over them; parent visibility still respects fog.
	arrow.no_depth_test = true
	arrow.render_priority = 10
	arrow.texture = UP_TEXTURE if is_increase else DOWN_TEXTURE
	arrow.hframes = 6
	arrow.vframes = 8
	sheet_material = ShaderMaterial.new()
	sheet_material.shader = SHEET_SHADER
	sheet_material.render_priority = arrow.render_priority
	sheet_material.set_shader_parameter("sheet_texture", arrow.texture)
	arrow.material_override = sheet_material
	add_child(arrow)
	arrows.append(arrow)
	for index in range(2):
		var extra := arrow.duplicate() as Sprite3D
		add_child(extra)
		arrows.append(extra)
	# Same layout for up/down: upper-left, right, lower-left around opaque art.
	var placements := [Vector2(-0.9, 0.65), Vector2(0.95, 0.05), Vector2(-0.65, -0.8)]
	var travel := screen_up * TRAVEL * (1.0 if is_increase else -1.0)
	animation = create_tween().set_parallel(true)
	for index in range(arrows.size()):
		var place: Vector2 = placements[index]
		var position_on_body := screen_right * place.x * half_width + screen_up * place.y * half_height
		arrows[index].position = position_on_body - travel * 0.5
		arrows[index].modulate.a = 0.0
		animation.tween_property(arrows[index], "position", position_on_body + travel * 0.5, duration)
	_sample_frames(0.0)
	animation.tween_property(arrow, "modulate:a", 1.0, duration * 0.15)
	animation.tween_property(arrow, "modulate:a", 0.0, duration * 0.25).set_delay(duration * 0.75)
	animation.tween_method(_sample_frames, 0.0, 1.0, duration)
	animation.chain().tween_callback(queue_free)


func _sample_frames(progress: float) -> void:
	var frame := minf(progress * 48.0, 47.0)
	arrow.frame = int(frame)
	for indicator in arrows:
		indicator.frame = arrow.frame
		indicator.modulate.a = arrow.modulate.a
	sheet_material.set_shader_parameter("frame_blend", fposmod(frame, 1.0))
	sheet_material.set_shader_parameter("fade_amount", arrow.modulate.a)
