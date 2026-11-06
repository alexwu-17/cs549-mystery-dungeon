extends PanelContainer
## Read-only view. Updating this panel never spends PP or schedules an action.

const MoveDisplayData = preload("res://scripts/ui/move_display_data.gd")
const SLOT_COUNT := 4
const SLOT_ACTIONS := [&"move_slot_1", &"move_slot_2", &"move_slot_3", &"move_slot_4"]
const BUILTIN_ICONS := {
	"Fire": preload("res://assets/ui/moves/fire.svg"),
	"Water": preload("res://assets/ui/moves/water.svg"),
	"Grass": preload("res://assets/ui/moves/grass.svg"),
	"Normal": preload("res://assets/ui/moves/normal.svg"),
	"Physical": preload("res://assets/ui/moves/physical.svg"),
	"Special": preload("res://assets/ui/moves/special.svg"),
	"Status": preload("res://assets/ui/moves/status.svg"),
}
var moves: Array[MoveDisplayData] = []
var rows: Array[HBoxContainer] = []
var details: PanelContainer
var detail_body: VBoxContainer
var hovered_slot: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", _panel_style())
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", 0)
	add_child(list)
	for index in range(SLOT_COUNT):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(252, 40)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 10)
		row.mouse_entered.connect(_show_details.bind(index))
		row.mouse_exited.connect(_hide_details)
		list.add_child(row)
		rows.append(row)
	details = PanelContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_stylebox_override("panel", _panel_style())
	details.z_index = 1
	details.hide()
	# A sibling avoids PanelContainer resizing the tooltip as panel content.
	get_parent().add_child.call_deferred(details)
	detail_body = VBoxContainer.new()
	detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_body.add_theme_constant_override("separation", 8)
	details.add_child(detail_body)
	_refresh()


func _exit_tree() -> void:
	if is_instance_valid(details):
		details.queue_free()


func set_moves(entries: Array[MoveDisplayData]) -> void:
	moves.assign(entries.slice(0, SLOT_COUNT))
	if is_node_ready():
		_refresh()
		if hovered_slot >= 0:
			_show_details(hovered_slot)


func _refresh() -> void:
	for index in range(SLOT_COUNT):
		var row := rows[index]
		_clear(row)
		var key := _label(_slot_key(index))
		key.custom_minimum_size.x = 32
		key.add_theme_font_size_override("font_size", 26)
		key.add_theme_color_override("font_color", Color(0.72, 0.81, 0.93))
		row.add_child(key)
		if index >= moves.size() or moves[index] == null or moves[index].move_name.is_empty():
			row.add_child(_label("—", true))
			continue
		var move := moves[index]
		row.add_child(_icon(move.attribute_icon, move.attribute_name))
		row.add_child(_label(move.move_name, true))
		var pp := _label("%d/%d" % [move.current_pp, move.maximum_pp])
		pp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pp.custom_minimum_size.x = 62
		if move.current_pp <= 0:
			pp.modulate = Color(0.8, 0.55, 0.55)
		row.add_child(pp)


func _slot_key(index: int) -> String:
	for event in InputMap.action_get_events(SLOT_ACTIONS[index]):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			var letter := OS.get_keycode_string(code)
			# Unicode negative squared capitals supply the boxed key appearance.
			if letter.length() == 1 and code >= KEY_A and code <= KEY_Z:
				return String.chr(0x1F170 + code - KEY_A)
			return letter
	return "—"


func _show_details(index: int) -> void:
	hovered_slot = index
	if index >= moves.size() or moves[index] == null or moves[index].move_name.is_empty():
		details.hide()
		return
	var move := moves[index]
	_clear(detail_body)
	detail_body.add_child(_label(move.move_name))
	var attributes := HBoxContainer.new()
	attributes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attributes.add_theme_constant_override("separation", 8)
	attributes.add_child(_icon(move.attribute_icon, move.attribute_name))
	attributes.add_child(_label(move.attribute_name))
	attributes.add_child(_icon(move.category_icon, move.category))
	attributes.add_child(_label(move.category))
	detail_body.add_child(attributes)
	detail_body.add_child(_label(move.damage_text))
	var description := _label(move.description)
	description.custom_minimum_size.x = 280
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.add_child(description)
	details.reset_size()
	details.show()
	_position_details.call_deferred()


func _position_details() -> void:
	if not is_instance_valid(details) or hovered_slot < 0 or not details.visible:
		return
	var viewport_size := get_viewport_rect().size
	var origin := Vector2(global_position.x + size.x + 10, rows[hovered_slot].global_position.y)
	if origin.x + details.size.x > viewport_size.x - 12:
		origin.x = global_position.x - details.size.x - 10
	origin.x = clampf(origin.x, 12, maxf(12, viewport_size.x - details.size.x - 12))
	origin.y = clampf(origin.y, 12, maxf(12, viewport_size.y - details.size.y - 12))
	details.global_position = origin


func _hide_details() -> void:
	hovered_slot = -1
	details.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_instance_valid(details) and not is_visible_in_tree():
		_hide_details()


func _label(value: String, expand: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _icon(texture: Texture2D, fallback: String) -> Control:
	if texture == null:
		texture = BUILTIN_ICONS.get(fallback)
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return icon
	# Explicit text fallback until the move's type/category artwork is supplied.
	var badge := _label(fallback.left(3).to_upper())
	badge.custom_minimum_size = Vector2(32, 24)
	badge.add_theme_font_size_override("font_size", 12)
	return badge


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.075, 0.94)
	style.border_color = Color(0.35, 0.43, 0.53, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
