class_name CharacterVisual
extends Node

signal presentation_finished
signal frame_changed(name: String)
@export var sprite_path: NodePath
@export_dir var asset_directory: String
@export var foot_anchor: Vector2
var facing: Vector2i = Vector2i.DOWN
var active: bool = false
var disposed: bool = false
var attacking: bool = false
var current_frame: String = "front"
var animation: Tween
var textures: Dictionary = {}
var ramp_texture: Texture2D
var opaque_top: int = 0
@onready var sprite: Sprite3D = get_node(sprite_path)

func _ready() -> void:
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
	var correction := Vector3.ZERO
	if data != null and data.ramp_tiles.has(tile):
		var segment: Dictionary = data.ramp_segments[data.ramp_tiles[tile].segment]
		var rise := DungeonData.ELEVATION_HEIGHT / (3.0 * DungeonData.TILE_SIZE)
		var normal := Vector3(-segment.direction.x * rise, 1, -segment.direction.y * rise).normalized()
		# Only a billboard leaning into the uphill surface needs clearance.
		if normal.dot(camera.global_basis.y) < 0.0:
			if ramp_texture != sprite.texture:
				ramp_texture = sprite.texture
				var image := ramp_texture.get_image()
				if image.is_compressed(): image.decompress()
				opaque_top = image.get_height()
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						if image.get_pixel(x, y).a > 0.5:
							opaque_top = y
							break
					if opaque_top != image.get_height(): break
			var origin := sprite.global_position - leap.surface_offset
			var surface: Vector3 = get_parent().global_position
			var height := (sprite.get_item_rect().end.y - opaque_top) * sprite.pixel_size * sprite.global_basis.y.length()
			var top := origin + camera.global_basis.y * height
			var clearance := normal.dot(top - surface)
			var toward_camera := (camera.global_position - origin).normalized()
			var gain := normal.dot(toward_camera)
			if clearance < 0.0 and gain > 0.001:
				correction = toward_camera * ((-clearance + 0.005) / gain)
	leap.set_surface_offset(correction)

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
	finish()
	standing()

func complete_action() -> void:
	if active:
		await presentation_finished

func _exit_tree() -> void:
	disposed = true
	finish()
