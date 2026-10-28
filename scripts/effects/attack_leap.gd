class_name AttackLeap
extends Node

signal presentation_started
signal presentation_finished
signal presentation_progressed(elapsed: float)
@export var visual_path: NodePath
@export var duration: float = 0.24
@export var procedural_motion: bool = true
@export var hop_height: float = DungeonData.TILE_SIZE * 0.15
var active: bool = false
var action_speed: float = 1.0:
	set(value):
		action_speed = value
		if animation != null and animation.is_valid():
			animation.set_speed_scale(value)
var animation: Tween
var visual: Node3D
var starting_transform: Transform3D
var displacement: Vector3
var surface_offset: Vector3 = Vector3.ZERO
# Optional native ramp presentation; never changes the actor's logical root.
var ramp_path: bool = false
var attack_world_offset: Vector3 = Vector3.ZERO
var attack_plane_normal: Vector3 = Vector3.UP
var attack_tread_offset: Vector3 = Vector3.ZERO
var attack_tread_clearance: float = 0.0
var _source_tread: Vector3 = Vector3.ZERO
var _target_tread: Vector3 = Vector3.ZERO
var _tread_height: float = 0.0
var _path_delta: Vector3 = Vector3.ZERO
var _from_ramp: bool = false
var _to_ramp: bool = false
var _rush_time: float = 0.0
var _hit_time: float = 0.0
var _return_time: float = 0.0

func set_surface_offset(offset: Vector3) -> void:
	# Additive presentation correction, also applied to the Tween's baseline.
	var target := get_node(visual_path) as Node3D
	var delta: Vector3 = target.get_parent().global_basis.inverse() * (offset - surface_offset)
	target.position += delta
	if active:
		starting_transform.origin += delta
	surface_offset = offset

func play(direction: Vector2i) -> void:
	if active or absi(direction.x) + absi(direction.y) != 1:
		return
	visual = get_node(visual_path) as Node3D
	starting_transform = visual.transform
	# Convert world grid displacement into the visual parent's coordinates.
	displacement = visual.get_parent().global_basis.inverse() * Vector3(direction.x, 0, direction.y) * DungeonData.TILE_SIZE
	ramp_path = false
	attack_world_offset = Vector3.ZERO
	active = true
	presentation_started.emit()
	animation = create_tween()
	animation.set_speed_scale(action_speed)
	animation.tween_method(_sample, 0.0, 1.0, duration)
	animation.tween_callback(finish)

func _sample(progress: float) -> void:
	if ramp_path:
		_sample_ramp_path(progress * duration)
	presentation_progressed.emit(progress * duration)
	if not procedural_motion:
		return
	var forward := 1.0 - absf(2.0 * progress - 1.0)
	var hop := sin(PI * progress) * hop_height
	var local_up: Vector3 = visual.get_parent().global_basis.inverse() * Vector3.UP
	visual.position = starting_transform.origin + displacement * forward + local_up * hop

func finish() -> void:
	if not active:
		return
	if animation != null:
		animation.kill()
	if is_instance_valid(visual):
		visual.transform = starting_transform
	active = false
	ramp_path = false
	attack_world_offset = Vector3.ZERO
	attack_plane_normal = Vector3.UP
	attack_tread_offset = Vector3.ZERO
	attack_tread_clearance = 0.0
	presentation_finished.emit()

func _exit_tree() -> void:
	finish()


func configure_ramp_path(data: DungeonData, tile: Vector2i, direction: Vector2i, renderer: DungeonRenderer, rush: float, hit: float, returning: float) -> void:
	if not active or data == null or renderer == null or renderer.dungeon_data != data:
		return
	var target := tile + direction
	if not data.can_traverse(tile, target): return
	_from_ramp = data.get_tile(tile) == DungeonData.TileType.RAMP
	_to_ramp = data.get_tile(target) == DungeonData.TileType.RAMP
	# Flat attackers keep their exact existing presentation, even beside a ramp.
	if not _from_ramp: return
	_path_delta = renderer.get_entity_world_position(target) - renderer.get_entity_world_position(tile)
	_source_tread = renderer.get_ramp_visual_offset(tile)
	_target_tread = renderer.get_ramp_visual_offset(target)
	_tread_height = ModularDungeonVisuals.ramp_clearance_height(1 if data.legacy_ramp and not data.ramp_tiles.has(tile) else 3)
	if is_zero_approx(_path_delta.y): return
	_rush_time = clampf(rush, 0.0, duration)
	_hit_time = clampf(hit, _rush_time + 0.000001, duration)
	_return_time = clampf(returning, _hit_time, duration - 0.000001)
	ramp_path = true
	_sample_ramp_path(0.0)


func _sample_ramp_path(elapsed: float) -> void:
	var forward := 0.0
	if elapsed >= _return_time:
		forward = 1.0 - smoothstep(_return_time, duration, elapsed)
	elif elapsed >= _hit_time:
		forward = 1.0
	elif elapsed > _rush_time:
		forward = smoothstep(_rush_time, _hit_time, elapsed)
	var height_fraction := forward
	# Buffers are flat up to their shared edge; the ramp begins halfway between centers.
	if not _from_ramp: height_fraction = maxf(0.0, 2.0 * forward - 1.0)
	elif not _to_ramp: height_fraction = minf(1.0, 2.0 * forward)
	var offset := Vector3(_path_delta.x * forward, _path_delta.y * height_fraction, _path_delta.z * forward)
	visual.position += visual.get_parent().global_basis.inverse() * (offset - attack_world_offset)
	attack_world_offset = offset
	attack_tread_offset = _source_tread.lerp(_target_tread,forward)
	# Keep the billboard clear of neighboring treads while its feet cross a buffer edge.
	# The world path above still becomes flat at the authoritative shared edge.
	attack_tread_clearance = _tread_height
	var rise := _path_delta.y * (1.0 if _from_ramp and _to_ramp else 2.0)
	attack_plane_normal = Vector3(-_path_delta.x * rise, 1.0, -_path_delta.z * rise).normalized()
