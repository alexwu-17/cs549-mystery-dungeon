extends PanelContainer

@export var refresh_interval: float = 0.5
@onready var statistics: Label = $Statistics
var previous_usec: int = 0
var elapsed_usec: int = 0
var frame_count: int = 0
var refresh_count: int = 0
var average_interval_ms: float = 0.0

func _ready() -> void:
	previous_usec = Time.get_ticks_usec()
	refresh_statistics()

func _process(_delta: float) -> void:
	sample_frame(Time.get_ticks_usec())

func sample_frame(now_usec: int) -> void:
	elapsed_usec += maxi(0, now_usec - previous_usec)
	previous_usec = now_usec
	frame_count += 1
	if elapsed_usec >= refresh_interval * 1000000.0:
		average_interval_ms = float(elapsed_usec) / frame_count / 1000.0
		refresh_statistics()
		elapsed_usec = 0
		frame_count = 0

func refresh_statistics() -> void:
	var resolution := internal_resolution(get_viewport())
	statistics.text = "FPS: %d\nRender Resolution: %d×%d\nFrame Interval (avg): %.1f ms" % [Engine.get_frames_per_second(), resolution.x, resolution.y, average_interval_ms]
	refresh_count += 1

static func internal_resolution(viewport: Viewport) -> Vector2i:
	# The output texture already reflects Window/SubViewport stretch and resize.
	# Match Godot 4.4 RendererViewport::_configure_3d_render_buffers integer sizing.
	var target := Vector2i(viewport.get_texture().get_size())
	var scale := viewport.scaling_3d_scale
	if absf(scale - 1.0) <= 0.0001:
		return target
	var size := Vector2i(maxi(1, int(target.x * scale)), maxi(1, int(target.y * scale)))
	if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR or scale > 1.0:
		size.x = mini(size.x, 16384)
		size.y = mini(size.y, 16384)
	return size

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_performance_overlay") and not event.is_echo():
		visible = not visible
		get_viewport().set_input_as_handled()
