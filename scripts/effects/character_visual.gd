class_name CharacterVisual
extends Node

signal defeat_finished
var defeating: bool = false
var defeat_completed: bool = false
var defeat_animation: Tween

signal presentation_finished
signal frame_changed(name: String)
@export var display_name: String = "Character"
@export var sprite_path: NodePath
@export_dir var asset_directory: String
@export var foot_anchor: Vector2
var facing: Vector2i = Vector2i.DOWN
var active: bool = false
var disposed: bool = false
var attacking: bool = false
var current_frame: String = "front"
var action_speed: float = 1.0:
	set(value):
		action_speed = value
		if animation != null and animation.is_valid():
			animation.set_speed_scale(value)
var animation: Tween
var textures: Dictionary = {}
var ramp_texture: Texture2D
var opaque_top: int = 0
var original_pixel_size: float
@onready var sprite: Sprite3D = get_node(sprite_path)

func _ready() -> void:
	original_pixel_size = sprite.pixel_size
	for name in ["front", "back", "left", "right", "attack_front", "attack_back", "attack_left", "attack_right", "charge", "spin_01", "spin_02", "spin_03", "spin_04", "spin_05", "spin_06", "spin_07", "spin_08"]:
		var path := asset_directory.path_join(name + ".png")
		if ResourceLoader.exists(path):
			textures[name] = load(path)
	standing()
	# Pixel-space offset anchors feet on the logical visual origin.
	var dimensions := sprite.texture.get_size()
	sprite.offset = Vector2(dimensions.x / 2.0 - foot_anchor.x, foot_anchor.y - dimensions.y / 2.0)

func direction_name() -> String:
	if facing == Vector2i.UP: return "back"
	if facing == Vector2i.LEFT: return "left"
	if facing == Vector2i.RIGHT: return "right"
	return "front"

func clear_ramp_intersection(camera: Camera3D, data: DungeonData, tile: Vector2i, leap: AttackLeap) -> void:
	# Recompute from the source size so clearance never accumulates magnification.
	sprite.pixel_size = original_pixel_size
	var uncorrected_origin := sprite.global_position - leap.surface_offset
	var correction := Vector3.ZERO
	var renderer: DungeonRenderer = get_parent().get("dungeon_renderer")
	if renderer != null and renderer.dungeon_data == data:
		correction = attack_surface_tread_offset() if uses_attack_surface() else renderer.get_ramp_visual_offset(tile)
	if data != null and data.ramp_tiles.has(tile) and not uses_attack_surface():
		var segment: Dictionary = data.ramp_segments[data.ramp_tiles[tile].segment]
		var rise := DungeonData.ELEVATION_HEIGHT / (3.0 * DungeonData.TILE_SIZE)
		var normal := Vector3(-segment.direction.x * rise, 1, -segment.direction.y * rise).normalized()
		# Only a billboard leaning into the uphill surface needs clearance.
		if normal.dot(camera.global_basis.y) < 0.0:
			if ramp_texture != sprite.texture:
				ramp_texture = sprite.texture
				if ramp_texture.has_meta("pokemon_opaque_top"):
					opaque_top = int(ramp_texture.get_meta("pokemon_opaque_top"))
				else:
					var image := ramp_texture.get_image()
					if image.is_compressed(): image.decompress()
					opaque_top = image.get_height()
					for y in range(image.get_height()):
						for x in range(image.get_width()):
							if image.get_pixel(x, y).a > 0.5:
								opaque_top = y
								break
						if opaque_top != image.get_height(): break
			var origin := sprite.global_position - leap.surface_offset + correction
			var surface: Vector3 = get_parent().global_position + correction
			var height := (sprite.get_item_rect().end.y - opaque_top) * sprite.pixel_size * sprite.global_basis.y.length()
			var top := origin + camera.global_basis.y * height
			var clearance := normal.dot(top - surface)
			var toward_camera := (camera.global_position - origin).normalized()
			var gain := normal.dot(toward_camera)
			if clearance < 0.0 and gain > 0.001:
				correction += toward_camera * ((-clearance + 0.005) / gain)
	correction += ground_clearance_offset(camera, data, tile, uncorrected_origin + correction)
	if renderer != null and renderer.dungeon_data == data and camera.has_method("sprite_samples") and sprite.is_visible_in_tree():
		var points: Array[Vector3] = camera.call("sprite_samples", sprite)
		for index in range(points.size()):
			points[index] += correction - leap.surface_offset
		correction += renderer.get_rear_wall_visual_offset(camera, tile, points)
	correction += final_surface_clearance_offset(camera, data, tile, uncorrected_origin + correction)
	leap.set_surface_offset(correction)
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var original_depth := -camera.to_local(uncorrected_origin).z
		var corrected_depth := -camera.to_local(uncorrected_origin + correction).z
		if original_depth > 0.001 and corrected_depth > 0.001:
			sprite.pixel_size = original_pixel_size * corrected_depth / original_depth

func face(direction: Vector2i) -> void:
	if absi(direction.x) + absi(direction.y) == 1:
		facing = direction
	if not active and not attacking:
		standing()

func show_frame(name: String) -> void:
	if textures.has(name):
		current_frame = name
		sprite.texture = textures[name]
		frame_changed.emit(name)

func standing() -> void:
	attacking = false
	show_frame(direction_name())

func attack() -> void:
	attacking = true
	show_frame("attack_" + direction_name())

func spin() -> void:
	cancel()
	active = true
	animation = create_tween()
	animation.set_speed_scale(action_speed)
	show_frame("spin_01")
	for index in range(1, 9):
		animation.tween_interval(0.08)
		if index < 8:
			animation.tween_callback(show_frame.bind("spin_%02d" % (index + 1)))
	animation.tween_callback(finish)

func finish() -> void:
	if not active:
		return
	if animation != null:
		animation.kill()
	active = false
	standing()
	presentation_finished.emit()

func cancel() -> void:
	cancel_defeat()
	sprite.show()
	finish()
	standing()

func complete_action() -> void:
	if active:
		await presentation_finished

func _exit_tree() -> void:
	disposed = true
	cancel_defeat()
	finish()


# Optional nonblocking presentation hooks; placeholders keep their original behavior.
func walk() -> void:
	pass

func hurt() -> void:
	pass

func freeze_defeated() -> void:
	pass


func ground_clearance_offset(_camera: Camera3D, _data: DungeonData, _tile: Vector2i, _origin: Vector3) -> Vector3:
	return Vector3.ZERO


func uses_attack_surface() -> bool:
	return false


func final_surface_clearance_offset(_camera: Camera3D, _data: DungeonData, _tile: Vector2i, _origin: Vector3) -> Vector3:
	return Vector3.ZERO


func attack_surface_tread_offset() -> Vector3:
	return Vector3.ZERO


func charge() -> void:
	show_frame("charge")

func swing() -> void:
	spin() # Original placeholder fallback.

func recharge() -> void:
	standing()


func defeat() -> void:
	# Original placeholder fallback has no authored knockout presentation.
	defeat_completed = true
	sprite.hide()
	defeat_finished.emit()

func finish_defeat() -> void:
	if not defeating: return
	if defeat_animation != null: defeat_animation.kill()
	defeating = false
	defeat_completed = true
	sprite.hide()
	defeat_finished.emit()

func cancel_defeat() -> void:
	defeat_completed = false
	if not defeating: return
	if defeat_animation != null: defeat_animation.kill()
	defeating = false
	sprite.show()
	defeat_finished.emit()


func get_display_name() -> String:
	return display_name
