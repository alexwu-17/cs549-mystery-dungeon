class_name FloorIntroduction
extends Control

signal introduction_finished
signal phase_finished
@export var fade_to_black_duration: float = 0.25
@export var text_fade_in_duration: float = 0.25
@export var text_hold_duration: float = 0.50
@export var text_fade_out_duration: float = 0.25
@export var fade_from_black_duration: float = 0.25
@onready var background: ColorRect = $BlackOverlay
@onready var title: CenterContainer = $CenterContainer
var animation: Tween
var generation: int = 0
var disposed: bool = false

func cancel() -> void:
	generation += 1
	if animation != null:
		animation.kill()
	phase_finished.emit()

func cover_immediately() -> void:
	show()
	background.modulate.a = 1.0
	title.modulate.a = 0.0

func fade_to_black() -> void:
	show()
	title.modulate.a = 0.0
	background.modulate.a = 0.0
	animation = create_tween()
	animation.tween_property(background, "modulate:a", 1.0, fade_to_black_duration)
	animation.tween_callback(func(): phase_finished.emit())
	await phase_finished

func reveal(dungeon_name: String, floor_number: int, subtitle: String = "", hold_override: float = -1.0) -> void:
	var token := generation
	$CenterContainer/VBoxContainer/DungeonName.text = dungeon_name
	$CenterContainer/VBoxContainer/FloorSubtitle.text = subtitle if not subtitle.is_empty() else "%d F" % floor_number
	cover_immediately()
	animation = create_tween()
	animation.tween_property(title, "modulate:a", 1.0, text_fade_in_duration)
	animation.tween_interval(hold_override if hold_override >= 0.0 else text_hold_duration)
	animation.tween_property(title, "modulate:a", 0.0, text_fade_out_duration)
	animation.tween_property(background, "modulate:a", 0.0, fade_from_black_duration)
	animation.tween_callback(func(): phase_finished.emit())
	await phase_finished
	if token != generation:
		return
	hide()
	introduction_finished.emit()

func _exit_tree() -> void:
	disposed = true
	cancel()
