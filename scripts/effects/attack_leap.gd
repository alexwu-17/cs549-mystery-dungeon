class_name AttackLeap
extends Node

signal presentation_started
signal presentation_finished
@export var visual_path: NodePath
@export var duration: float = 0.24
@export var hop_height: float = DungeonData.TILE_SIZE * 0.15
var active: bool = false
var animation: Tween
var visual: Node3D
var starting_transform: Transform3D
var displacement: Vector3

func play(direction: Vector2i) -> void:
	if active or absi(direction.x) + absi(direction.y) != 1:
		return
	visual = get_node(visual_path) as Node3D
	starting_transform = visual.transform
	# Convert world grid displacement into the visual parent's coordinates.
	displacement = visual.get_parent().global_basis.inverse() * Vector3(direction.x, 0, direction.y) * DungeonData.TILE_SIZE
	active = true
	presentation_started.emit()
	animation = create_tween()
	animation.tween_method(_sample, 0.0, 1.0, duration)
	animation.tween_callback(finish)

func _sample(progress: float) -> void:
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
	presentation_finished.emit()

func _exit_tree() -> void:
	finish()
