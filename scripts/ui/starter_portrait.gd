extends Control
## Menu-only native animation with one fixed scale and ground reference.
var clips: Dictionary
var walking: bool = false
var elapsed: float = 0.0
var frame_index: int = 0
var pixel_scale: float
var ground_reference: Vector2


func configure(source: Dictionary, height: float) -> void:
	clips = source
	var idle: AtlasTexture = clips.Idle.rows[0][0].texture
	var bounds: Rect2i = idle.get_meta("pokemon_opaque_rect")
	pixel_scale = height / bounds.size.y
	ground_reference = Vector2(bounds.get_center().x, bounds.end.y) - idle.get_size() / 2.0
	custom_minimum_size = Vector2(bounds.size.x * pixel_scale, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func set_walking(active: bool) -> void:
	if walking == active:
		return
	walking = active
	elapsed = 0.0
	frame_index = 0
	set_process(active)
	queue_redraw()


func _process(delta: float) -> void:
	if not walking:
		return
	var info: Dictionary = clips.Walk
	elapsed = fmod(elapsed + delta, float(info.total))
	var time := elapsed
	var next := 0
	while next < info.durations.size() - 1 and time >= float(info.durations[next]):
		time -= float(info.durations[next])
		next += 1
	if next != frame_index:
		frame_index = next
		queue_redraw()


func _draw() -> void:
	if clips.is_empty():
		return
	var info: Dictionary = clips.Walk if walking else clips.Idle
	var texture: Texture2D = info.rows[0][frame_index].texture
	var origin := Vector2(size.x / 2.0, size.y) - (texture.get_size() / 2.0 + ground_reference) * pixel_scale
	draw_texture_rect(texture, Rect2(origin, texture.get_size() * pixel_scale), false)
