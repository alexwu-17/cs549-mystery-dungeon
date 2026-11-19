extends Control
## Displays a sequence of tutorial messages; gameplay is locked until acknowledged.
signal completed
const Arrow = preload("res://scripts/ui/tutorial_continue_arrow.gd")
var dialogue: CombatDialogue
var messages: Array[String] = []
var index := 0
var arrow: Control
var active := false
var reveal_progress := 0.0
var original_font_size := 0
const CHARACTERS_PER_SECOND := 45.0

func begin(target: CombatDialogue, lines: Array[String]) -> void:
	dialogue = target
	messages = lines
	if messages.is_empty():
		completed.emit()
		return
	active = true
	original_font_size = dialogue.text.get_theme_font_size("normal_font_size")
	dialogue.text.add_theme_font_size_override("normal_font_size", roundi(original_font_size * 1.5))
	arrow = Arrow.new()
	dialogue.add_child(arrow)
	arrow.size = Vector2(24, 24)
	_show_message()

func _show_message() -> void:
	dialogue.clear_history()
	dialogue.text.add_text(messages[index])
	dialogue.text.visible_characters = 0
	reveal_progress = 0.0
	dialogue.panel.show()
	dialogue.refresh_window()
	_position_arrow()

func _process(delta: float) -> void:
	if not active or not is_instance_valid(dialogue):
		return
	_position_arrow()
	reveal_progress += delta * CHARACTERS_PER_SECOND
	dialogue.text.visible_characters = mini(int(reveal_progress), dialogue.text.get_total_character_count())

func _position_arrow() -> void:
	if is_instance_valid(arrow):
		arrow.position = dialogue.panel.position + dialogue.panel.size - Vector2(32, 32)

func _exit_tree() -> void:
	if is_instance_valid(arrow):
		arrow.queue_free()
	if is_instance_valid(dialogue):
		dialogue.text.visible_characters = -1
		if original_font_size > 0:
			dialogue.text.add_theme_font_size_override("normal_font_size", original_font_size)
			dialogue.refresh_window()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		if dialogue.text.visible_characters < dialogue.text.get_total_character_count():
			reveal_progress = float(dialogue.text.get_total_character_count())
			dialogue.text.visible_characters = int(reveal_progress)
			return
		index += 1
		if index < messages.size():
			_show_message()
		else:
			active = false
			arrow.queue_free()
			dialogue.clear_history()
			completed.emit()
