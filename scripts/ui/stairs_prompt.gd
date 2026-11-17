class_name StairsPrompt
extends CanvasLayer
signal chosen(proceed: bool)
const Arrow = preload("res://scripts/ui/stairs_choice_arrow.gd")
var dialogue: CombatDialogue
var buttons: Array[Button] = []
var arrows: Array[Control] = []
var selected: int = 0
var completed: bool = false
var choice_panel: PanelContainer
var previous_dialogue: Dictionary = {}
func _ready() -> void:
 layer = 90
 previous_dialogue = {"history":dialogue.history.duplicate(true),"sequence":dialogue.sequence,
  "round_has_messages":dialogue.round_has_messages,"visible":dialogue.panel.visible,
  "timer_remaining":dialogue.timer.time_left,"timer_stopped":dialogue.timer.is_stopped()}
 dialogue.clear_history()
 dialogue.append_event(&"stairs_question")
 dialogue.timer.stop()
 dialogue.refresh_window()
 choice_panel = PanelContainer.new()
 choice_panel.add_theme_stylebox_override("panel", dialogue.panel.get_theme_stylebox("panel").duplicate())
 add_child(choice_panel)
 var margins := MarginContainer.new()
 for edge in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+edge,12)
 choice_panel.add_child(margins)
 var list := VBoxContainer.new()
 list.add_theme_constant_override("separation",8)
 margins.add_child(list)
 for caption in ["Proceed", "Stay on current floor"]:
  var row := HBoxContainer.new()
  list.add_child(row)
  var arrow := Arrow.new()
  row.add_child(arrow)
  arrows.append(arrow)
  var button := Button.new()
  button.text = caption
  button.alignment = HORIZONTAL_ALIGNMENT_LEFT
  button.custom_minimum_size = Vector2(275,36)
  button.add_theme_font_size_override("font_size",24)
  button.focus_mode = Control.FOCUS_NONE
  for state in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
  var index := buttons.size()
  button.pressed.connect(func(): choose(index == 0))
  button.mouse_entered.connect(func(): selected = index; _refresh())
  row.add_child(button)
  buttons.append(button)
 dialogue.panel.resized.connect(_queue_position)
 get_viewport().size_changed.connect(_queue_position)
 _refresh()
 _queue_position()
func _queue_position() -> void:
 _position.call_deferred()
func _position() -> void:
 if completed or not is_instance_valid(choice_panel): return
 choice_panel.reset_size()
 var rect := dialogue.panel.get_global_rect()
 choice_panel.position = Vector2(rect.end.x-choice_panel.size.x,rect.position.y-choice_panel.size.y-12)
 choice_panel.position.x = maxf(8,choice_panel.position.x)
 choice_panel.position.y = maxf(8,choice_panel.position.y)
func _input(event: InputEvent) -> void:
 if completed: return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode in [KEY_W,KEY_UP]: selected = posmod(selected-1,2)
  elif event.keycode in [KEY_S,KEY_DOWN]: selected = posmod(selected+1,2)
  elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]: choose(selected == 0)
  elif event.keycode == KEY_ESCAPE: choose(false)
  _refresh()
 if event is InputEventKey: get_viewport().set_input_as_handled()
func _refresh() -> void:
 for i in range(arrows.size()):
  arrows[i].modulate.a = 1.0 if i == selected else 0.0
func choose(proceed: bool) -> void:
 if completed: return
 completed = true
 hide()
 _restore_dialogue()
 chosen.emit(proceed)
 queue_free()
func _restore_dialogue() -> void:
 if previous_dialogue.is_empty() or not is_instance_valid(dialogue): return
 dialogue.timer.stop()
 dialogue.history.assign(previous_dialogue.history)
 dialogue.sequence = previous_dialogue.sequence
 dialogue.round_has_messages = previous_dialogue.round_has_messages
 dialogue._render()
 dialogue.panel.visible = previous_dialogue.visible
 if not previous_dialogue.timer_stopped:
  dialogue.timer.start(maxf(0.001,previous_dialogue.timer_remaining))
 previous_dialogue.clear()
func _exit_tree() -> void:
 _restore_dialogue()
 if is_instance_valid(dialogue) and dialogue.panel.resized.is_connected(_queue_position): dialogue.panel.resized.disconnect(_queue_position)
 if get_viewport() != null and get_viewport().size_changed.is_connected(_queue_position): get_viewport().size_changed.disconnect(_queue_position)
