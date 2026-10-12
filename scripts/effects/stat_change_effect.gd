class_name StatChangeEffect
extends Node3D

@export var duration: float = 0.3
@export var anchor_offset: Vector3 = Vector3.ZERO
const TRAVEL: float = DungeonData.TILE_SIZE * 0.5
const ARROW_PIXEL_SIZE: float = 0.04 * 0.6
var animation: Tween
var arrow: Sprite3D

static func play_stat_change(target: Node3D, is_increase: bool, offset: Vector3 = Vector3.ZERO) -> StatChangeEffect:
	var effect: StatChangeEffect = load("res://scenes/effects/stat_change_effect.tscn").instantiate()
	target.add_child(effect)
	effect.play(is_increase, offset)
	return effect

func play(is_increase: bool, offset: Vector3 = Vector3.ZERO) -> void:
	anchor_offset = offset
	var camera := get_viewport().get_camera_3d()
	var screen_right := camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	# Keep the arrow's lower edge near the tile surface and its center left of
	# the target. A world-aligned basis makes local Y motion strictly vertical.
	global_basis = Basis.IDENTITY
	global_position = get_parent().global_position + anchor_offset - screen_right * DungeonData.TILE_SIZE * 0.35 + Vector3.UP * DungeonData.TILE_SIZE * 0.4
	arrow = Sprite3D.new()
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.pixel_size = ARROW_PIXEL_SIZE
	arrow.shaded = false
	# The bottom-left tile anchor lies behind large billboard bodies. Draw this
	# short-lived feedback over them; parent visibility still respects fog.
	arrow.no_depth_test = true
	arrow.render_priority = 10
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var color := Color(0.15, 1, 0.25) if is_increase else Color(1, 0.15, 0.1)
	for y in range(32):
		for x in range(24):
			var row := y if is_increase else 31 - y
			if (row < 12 and absi(x - 12) <= row) or (row >= 12 and x >= 8 and x <= 16):
				image.set_pixel(x, y, color)
	arrow.texture = ImageTexture.create_from_image(image)
	add_child(arrow)
	arrow.position.y = 0.0 if is_increase else TRAVEL
	arrow.modulate.a = 0.0
	animation = create_tween().set_parallel(true)
	animation.tween_property(arrow, "position:y", TRAVEL if is_increase else 0.0, duration)
	animation.tween_property(arrow, "modulate:a", 1.0, duration * 0.15)
	animation.tween_property(arrow, "modulate:a", 0.0, duration * 0.25).set_delay(duration * 0.75)
	animation.chain().tween_callback(queue_free)
