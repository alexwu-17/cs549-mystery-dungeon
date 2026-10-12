class_name Minotaur
extends Node3D

const HealthScript = preload("res://scripts/entities/health.gd")
const StatEffect = preload("res://scripts/effects/stat_change_effect.gd")
enum State { HUNTING, CHARGING, COOLDOWN, DEAD }
signal attack_requested(damage: int)
signal defeated
signal presentation_event(kind: StringName)
@export var maximum_hp: int = 30
@export var attack_damage: int = 18
var health: HealthScript = HealthScript.new()
var state: State = State.HUNTING
var grid_position: Vector2i
var facing: Vector2i = Vector2i.DOWN
var threatened_tiles: Array[Vector2i] = []
var markers: Array[MeshInstance3D] = []
var dungeon_data: DungeonData
var dungeon_renderer: DungeonRenderer

func setup(center: Vector2i, data: DungeonData, renderer: DungeonRenderer) -> void:
	grid_position = center
	dungeon_data = data
	dungeon_renderer = renderer
	health.reset(maximum_hp)
	health.died.connect(_on_death)
	position = renderer.get_entity_world_position(center)

func footprint() -> Array[Vector2i]:
	return footprint_at(grid_position)

func footprint_at(center: Vector2i) -> Array[Vector2i]:
	# grid_position is the upper tile; facing never rotates the body.
	var tiles: Array[Vector2i] = [center, center + Vector2i.DOWN]
	return tiles

func occupies(tile: Vector2i) -> bool:
	return health.current > 0 and footprint().has(tile)

func can_occupy(center: Vector2i, player_tile: Vector2i) -> bool:
	var step := center - grid_position
	for tile in footprint_at(center):
		if tile == player_tile or not dungeon_data.is_walkable(tile):
			return false
		if step != Vector2i.ZERO and not dungeon_data.can_traverse(tile - step, tile):
			return false
	return true

func attack_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var body := footprint()
	for occupied in body:
		for y in range(-1, 2):
			for x in range(-1, 2):
				var tile := occupied + Vector2i(x, y)
				if not body.has(tile) and not tiles.has(tile) and dungeon_data.is_walkable(tile):
					tiles.append(tile)
	return tiles

func face_player(player_tile: Vector2i) -> void:
	var delta := player_tile - grid_position
	if absi(delta.x) > absi(delta.y):
		facing = Vector2i(signi(delta.x), 0)
	elif delta.y != 0:
		facing = Vector2i(0, signi(delta.y))
	elif delta.x != 0:
		facing = Vector2i(signi(delta.x), 0)

func take_turn(player_tile: Vector2i) -> void:
	if state == State.DEAD:
		return
	if state == State.CHARGING:
		var hit := threatened_tiles.has(player_tile)
		clear_charge()
		state = State.COOLDOWN
		print("MINOTAUR CHARGE: ", "HIT" if hit else "MISSED")
		if hit:
			attack_requested.emit(attack_damage)
		else:
			presentation_event.emit(&"charge_miss")
		return
	if state == State.COOLDOWN:
		state = State.HUNTING
		face_player(player_tile)
		presentation_event.emit(&"cooldown")
		print("MINOTAUR COOLDOWN")
		return
	face_player(player_tile)
	if attack_tiles().has(player_tile):
		state = State.CHARGING
		threatened_tiles = attack_tiles()
		show_charge()
		presentation_event.emit(&"charging")
		print("MINOTAUR CHARGING: ", threatened_tiles)
		return
	var delta := player_tile - grid_position
	var horizontal := Vector2i(signi(delta.x), 0)
	var vertical := Vector2i(0, signi(delta.y))
	var steps: Array[Vector2i] = []
	if absi(delta.x) >= absi(delta.y):
		steps.assign([horizontal, vertical])
	else:
		steps.assign([vertical, horizontal])
	for step in steps:
		if step != Vector2i.ZERO and can_occupy(grid_position + step, player_tile):
			grid_position += step
			facing = step
			position = dungeon_renderer.get_entity_world_position(grid_position)
			print("MINOTAUR MOVE: ", grid_position)
			return

func show_charge() -> void:
	StatEffect.play_stat_change(self, true)
	for tile in threatened_tiles:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.025, 0.9)
		marker.mesh = box
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1, 0.22, 0.05)
		marker.material_override = material
		add_child(marker)
		marker.global_position = dungeon_renderer.get_entity_world_position(tile) + Vector3(0, 0.035, 0)
		markers.append(marker)

func clear_charge() -> void:
	for marker in markers:
		marker.free()
	markers.clear()
	threatened_tiles.clear()

func refresh_visibility() -> void:
	visible = false
	for tile in footprint():
		visible = visible or dungeon_data.is_bright(tile)
	for index in range(markers.size()):
		markers[index].visible = dungeon_data.is_walkable(threatened_tiles[index]) and dungeon_data.is_bright(threatened_tiles[index])

func receive_damage(amount: int) -> void:
	health.damage(amount)
	print("MINOTAUR HP: ", health.current, "/", health.maximum)

func _on_death() -> void:
	state = State.DEAD
	clear_charge()
	for child in get_children():
		if child is StatChangeEffect:
			child.free()
	visible = false
	defeated.emit()


func complete_action() -> void:
	# The stat arrow is decorative; charge timing belongs to take_turn.
	pass
