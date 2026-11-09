class_name DamageNumbers
extends Control
## Nonblocking screen-space feedback; no damage, turn or fog-state ownership.
const LIFETIME := 0.8
const RISE := 48.0
var popups: Array[Dictionary] = []
var watched: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func watch(actor: Node3D, visual: CharacterVisual, health: EntityHealth) -> void:
	var id := actor.get_instance_id()
	if watched.has(id):
		return
	var callback := _on_damage.bind(weakref(actor), weakref(visual))
	watched[id] = {"health": weakref(health), "callback": callback}
	health.damaged.connect(callback)
	actor.tree_exiting.connect(_forget_actor.bind(id), CONNECT_ONE_SHOT)


func _forget_actor(id: int) -> void:
	if not watched.has(id):
		return
	var health: EntityHealth = watched[id].health.get_ref()
	if health != null and health.damaged.is_connected(watched[id].callback):
		health.damaged.disconnect(watched[id].callback)
	watched.erase(id)


func _on_damage(amount: int, actor_ref: WeakRef, visual_ref: WeakRef) -> void:
	if not is_inside_tree():
		return
	var actor: Node3D = actor_ref.get_ref()
	var visual: CharacterVisual = visual_ref.get_ref()
	var camera := get_viewport().get_camera_3d()
	if amount <= 0 or actor == null or visual == null or visual.disposed or camera == null or not actor.is_visible_in_tree():
		return
	var label := Label.new()
	label.text = "-%d" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.reset_size()
	var entry := {"label": label, "actor": actor_ref, "offset": actor.to_local(visual.damage_number_anchor(camera)), "elapsed": 0.0}
	popups.append(entry)
	_place(entry, camera)
	set_process(true)


func _place(entry: Dictionary, camera: Camera3D) -> void:
	var actor: Node3D = entry.actor.get_ref()
	var label: Label = entry.label
	var anchor := actor.to_global(entry.offset)
	label.visible = actor.is_visible_in_tree() and not camera.is_position_behind(anchor)
	var progress := clampf(float(entry.elapsed) / LIFETIME, 0.0, 1.0)
	var screen := get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(anchor)
	label.position = screen + Vector2(-label.size.x / 2.0, -label.size.y - 8.0 - RISE * progress)
	label.modulate.a = 1.0 - progress


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for index in range(popups.size() - 1, -1, -1):
		var entry := popups[index]
		entry.elapsed += maxf(0.0, delta)
		var actor: Node3D = entry.actor.get_ref()
		if actor == null or not actor.is_inside_tree() or float(entry.elapsed) >= LIFETIME:
			remove_child(entry.label)
			entry.label.queue_free()
			popups.remove_at(index)
		elif camera != null:
			_place(entry, camera)
		else:
			entry.label.hide()
	set_process(not popups.is_empty())


func clear() -> void:
	for entry in popups:
		remove_child(entry.label)
		entry.label.queue_free()
	popups.clear()
	set_process(false)


func _exit_tree() -> void:
	for id in watched.keys():
		_forget_actor(id)
	popups.clear() # Child labels are freed by the scene; no outstanding Tweens/awaits.
