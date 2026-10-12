class_name CombatDialogue
extends Control

const Formatter = preload("res://scripts/ui/combat_message_formatter.gd")
@export var history_limit: int = 200
@export var visible_lines: int = 3
@export var inactivity_seconds: float = 4.0
var history: Array[Dictionary] = []
var sequence: int = 0
var round_has_messages: bool = false
@onready var panel: PanelContainer = $DialoguePanel
@onready var text: RichTextLabel = $DialoguePanel/MarginContainer/MessageText
@onready var timer: Timer = $HideTimer

func _ready() -> void:
	panel.hide()
	timer.timeout.connect(panel.hide)
	text.resized.connect(_queue_window)
	_queue_window()

func append_event(kind: StringName, data: Dictionary = {}, context: Dictionary = {}) -> void:
	var message := Formatter.format_event(kind, data)
	if message.is_empty():
		return
	_store(kind, message, context)
	history[-1]["data"] = data.duplicate(true)
	round_has_messages = true
	panel.show()
	timer.start(inactivity_seconds)
	_render()

func _store(kind: StringName, message: String, context: Dictionary) -> void:
	sequence += 1
	history.append({"sequence": sequence, "type": kind, "message": message, "context": context.duplicate(true)})
	while history.size() > maxi(1, history_limit):
		history.pop_front()

func end_round() -> void:
	if round_has_messages:
		_store(&"separator", "", {})
		_render()
	round_has_messages = false

func abandon_round() -> void:
	round_has_messages = false

func clear_history() -> void:
	history.clear()
	sequence = 0
	round_has_messages = false
	timer.stop()
	panel.hide()
	text.clear()

func _render() -> void:
	text.clear()
	for index in range(history.size()):
		if index > 0:
			text.add_text("\n")
		var entry: Dictionary = history[index]
		if entry.type == &"separator":
			text.push_color(Color(0.5, 0.55, 0.65))
			text.add_text("\u2500".repeat(12))
			text.pop()
		else:
			# Plain text is added safely; future formatting can use push/pop tags.
			text.add_text(entry.message)
	_queue_window()

func _queue_window() -> void:
	call_deferred("refresh_window")

func refresh_window() -> void:
	var font := text.get_theme_font("normal_font")
	var font_size := text.get_theme_font_size("normal_font_size")
	var spacing := text.get_theme_constant("line_separation")
	var height := font.get_height(font_size) * maxi(1, visible_lines) + spacing * maxi(0, visible_lines - 1)
	text.custom_minimum_size.y = height
	panel.offset_top = -height - 24.0 - 18.0
	# Use shaped/rendered line offsets, not message count or character truncation.
	var first := maxi(0, text.get_line_count() - maxi(1, visible_lines))
	text.get_v_scroll_bar().value = text.get_line_offset(first)
