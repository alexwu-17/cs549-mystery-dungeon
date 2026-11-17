class_name OminousWindEffect
extends Node3D
signal finished(played: bool)
var animation: Tween
var completed: bool = false
var layer: CanvasLayer
var material: ShaderMaterial
static func launch(parent: Node) -> OminousWindEffect:
	var effect := OminousWindEffect.new()
	parent.add_child(effect)
	effect.play()
	return effect
func play() -> void:
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = SpiritombFx.layout("ominous_wind").texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(sprite)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/effects/pixelfx_transition.gdshader")
	material.set_shader_parameter("frame_grid", Vector2(6,8))
	material.set_shader_parameter("uv_scale", Vector2.ONE / 1.12)
	sprite.material = material
	animation = create_tween()
	animation.tween_method(_sample,0.0,1.0,1.0)
	animation.tween_callback(func(): finish(true))
func _sample(progress: float) -> void:
	material.set_shader_parameter("frame_index", minf(47.0,floorf(progress*48.0)))
func finish(played: bool = false) -> void:
	if completed: return
	completed = true
	if animation != null: animation.kill()
	layer.hide()
	finished.emit(played)
	queue_free()
func _exit_tree() -> void:
	finish(false)
