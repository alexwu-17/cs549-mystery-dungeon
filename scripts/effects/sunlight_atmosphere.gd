class_name SunlightAtmosphere
extends Node3D
## One room-sized world-space shaft, reused as rooms change. No gameplay writes.
enum Mode { ORIGINAL, MESH, VOLUMETRIC }
const MESH_SHADER = preload("res://shaders/sunlight_mesh.gdshader")
const FOG_SHADER = preload("res://shaders/sunlight_mist.gdshader")
const GROUND_MIST = preload("res://scripts/effects/ground_mist.gd")
var ground_mist: MeshInstance3D
var selected_mode: int = Mode.MESH
@export_range(1.0,10.0,0.1) var beam_length: float = 6.0
@export_range(0.3,3.0,0.1) var beam_width: float = 1.6
@export var beam_color := Color(1.0,0.98,0.95)
@export var mist_color := Color(1.0,0.98,0.93)
@export_range(0.0,3.0,0.05) var mesh_intensity: float = 1.6
@export_range(0.0,0.35,0.01) var mesh_opacity: float = 0.16
@export_range(0.0,0.1,0.005) var mist_density: float = 0.055
@export_range(0.0,64.0,0.1) var scattering_energy: float = 48.0
@export var auto_place_demo: bool = true
@export var anchor_tile := Vector2i.ZERO
var main: Node3D
var lighting: DungeonLighting
var mesh_effect: MeshInstance3D
var mist: FogVolume
var mesh_material: ShaderMaterial
var mist_material: ShaderMaterial
var receiver := Vector3.ZERO
var receiver_tile := Vector2i.ZERO
var direction := Vector3.DOWN
var placement_safe: bool = false
var blocked_by: String = ""
var mask_image: Image
var mask_texture: ImageTexture
var mask_bounds: Rect2i
var mask_updates: int = 0
var _floor_id: int = 0
var _player_tile := Vector2i(-99999,-99999)
var _source_environment: Environment
var _owned_environment: Environment
var _sun_fog_energy: float = 1.0
var _room_id: int = -99999
var _room_cache: Dictionary = {}
var room_placements: int = 0
var effective_width: float = 1.6
var effective_length: float = 6.0
var _room_coverage: bool = false
var _sun_bounds: Array[AABB] = []
var _sun_cells: Dictionary = {}
var supporting_beams: Array[Dictionary] = []

func _ready() -> void:
	ground_mist = GROUND_MIST.new()
	add_child(ground_mist)
	mesh_effect = MeshInstance3D.new()
	mesh_effect.name = "SunlightMesh"
	mesh_effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_material = ShaderMaterial.new()
	mesh_material.shader = MESH_SHADER
	mesh_effect.material_override = mesh_material
	add_child(mesh_effect)
	mist = FogVolume.new()
	mist.name = "LocalizedMist"
	mist_material = ShaderMaterial.new()
	mist_material.shader = FOG_SHADER
	mist.material = mist_material
	add_child(mist)
	mesh_effect.hide()
	mist.hide()
	call_deferred("bind_main",get_parent())

func bind_main(owner_main: Node3D) -> void:
	main = owner_main
	lighting = main.get_node("LightingPresets")
	if not lighting.preset_changed.is_connected(_lighting_changed): lighting.preset_changed.connect(_lighting_changed)
	_update_context()
	apply_mode(selected_mode)

func _process(_delta: float) -> void:
	if is_instance_valid(main) and main.get("dungeon") != null: _update_context()

func _update_context() -> void:
	var data: DungeonData = main.dungeon
	if data == null: return
	if data.get_instance_id() != _floor_id:
		_floor_id = data.get_instance_id()
		_room_cache.clear()
		_room_id = -99999
		_index_sun_bounds()
		var bounds := data.map_bounds
		if not bounds.has_area() and not data.rooms.is_empty():
			bounds = data.rooms[0]
			for room in data.rooms: bounds = bounds.merge(room)
		mask_bounds = bounds.grow(2) if bounds.has_area() else Rect2i(data.player_spawn-Vector2i(12,12),Vector2i(24,24))
		ground_mist.build(main,mask_bounds)
		mask_image = Image.create(mask_bounds.size.x,mask_bounds.size.y,false,Image.FORMAT_L8)
		mask_texture = ImageTexture.create_from_image(mask_image)
		for material in [mist_material]:
			material.set_shader_parameter("bright_mask",mask_texture)
			material.set_shader_parameter("mask_origin",Vector2(mask_bounds.position))
			material.set_shader_parameter("mask_size",Vector2(mask_bounds.size))
		if not auto_place_demo: place_at(anchor_tile)
		_player_tile = Vector2i(-99999,-99999)
	if main.player.grid_position != _player_tile:
		_player_tile = main.player.grid_position
		if auto_place_demo:
			var room_id := data.get_room_id(_player_tile)
			if room_id != _room_id:
				_room_id = room_id
				if room_id >= 0: _place_room(data,room_id)
		refresh_visibility()

func _place_room(data: DungeonData, room_id: int) -> void:
	_room_coverage = true
	supporting_beams.clear()
	if _room_cache.has(room_id):
		var saved: Dictionary = _room_cache[room_id]
		receiver_tile = saved.tile
		receiver = saved.receiver
		effective_width = saved.width
		effective_length = saved.length
		placement_safe = saved.safe
		blocked_by = saved.blocked
		supporting_beams.assign(saved.supports)
		rebuild(false)
		return
	room_placements += 1
	var room: Rect2i = data.rooms[room_id]
	var center := Vector2(room.position)+Vector2(room.size-Vector2i.ONE)*0.5
	# Salted coordinates/visual seed only; no gameplay RNG consumption.
	var salt := _visual_hash(room.position,room_id)
	center += Vector2(float(salt % 101)/100.0-0.5,float((salt/101) % 101)/100.0-0.5)*1.2
	var center_tile := Vector2i(roundi(center.x),roundi(center.y))
	var candidates: Array[Vector2i] = []
	if data.is_walkable(center_tile): candidates.append(center_tile)
	for y in range(room.position.y+1,room.end.y-1):
		for x in range(room.position.x+1,room.end.x-1):
			var tile := Vector2i(x,y)
			if data.is_walkable(tile) and tile != center_tile: candidates.append(tile)
	var across := (-lighting.sun.global_basis.z).cross(-main.presentation_camera.global_basis.z).normalized()
	var footprint := Vector3(across.x,0,across.z).normalized()
	var reach_x := maxf(0.2,(room.size.x-2.0)*0.5-0.12)/maxf(absf(footprint.x),0.05)
	var reach_z := maxf(0.2,(room.size.y-2.0)*0.5-0.12)/maxf(absf(footprint.z),0.05)
	var room_width := clampf(minf(reach_x,reach_z)/0.65,0.4,6.0)
	effective_length = maxf(beam_length,minf(10.0,room.size.y*1.2))
	for width: float in [room_width,room_width*0.8,minf(beam_width,room_width)]:
		effective_width = width
		for tile in candidates:
			receiver_tile = tile
			receiver = main.dungeon_renderer.get_entity_world_position(tile)+Vector3(0,0.12,0)
			if tile == center_tile:
				receiver += Vector3(center.x-tile.x,0,center.y-tile.y)*DungeonData.TILE_SIZE
			rebuild()
			if placement_safe: break
		if placement_safe: break
	if placement_safe:
		_plan_supports(data,room_id,candidates,across)
		rebuild(false)
	_room_cache[room_id] = {"tile":receiver_tile,"receiver":receiver,"width":effective_width,"length":effective_length,"safe":placement_safe,"blocked":blocked_by,"supports":supporting_beams.duplicate(true)}
	if not placement_safe: push_warning("Sunlight: no clear placement in room %d; beam hidden."%room_id)

func place_at(tile: Vector2i) -> void:
	_room_coverage = false
	supporting_beams.clear()
	effective_width = beam_width
	effective_length = beam_length
	receiver_tile = tile
	receiver = main.dungeon_renderer.get_entity_world_position(tile)+Vector3(0,0.12,0)
	rebuild()

func rebuild(check_clearance: bool = true) -> void:
	if not is_instance_valid(lighting): return
	direction = -lighting.sun.global_basis.z.normalized()
	var camera: Camera3D = main.presentation_camera
	var across := direction.cross(-camera.global_basis.z).normalized()
	if across.is_zero_approx(): across = Vector3.RIGHT
	if check_clearance: placement_safe = direction.y < -0.25 and _clear_sun_path(across)
	var start := receiver-direction*effective_length
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_shaft(tool,receiver,effective_width,effective_length,across,1.0)
	if placement_safe:
		for beam in supporting_beams:
			_append_shaft(tool,beam.receiver,beam.width,beam.length,across,0.5)
	mesh_effect.mesh = tool.commit()
	mesh_material.set_shader_parameter("beam_color",beam_color)
	mesh_material.set_shader_parameter("intensity",mesh_intensity)
	mesh_material.set_shader_parameter("opacity",mesh_opacity*(0.7 if _room_coverage else 1.0))
	mist.position = (start+receiver)*0.5
	mist.size = (start-receiver).abs()+Vector3.ONE*effective_width*1.5
	mist_material.set_shader_parameter("beam_start",start)
	mist_material.set_shader_parameter("beam_direction",direction)
	mist_material.set_shader_parameter("beam_receiver",receiver)
	mist_material.set_shader_parameter("beam_length",effective_length)
	mist_material.set_shader_parameter("beam_width",effective_width)
	mist_material.set_shader_parameter("density",mist_density)
	mist_material.set_shader_parameter("mist_color",mist_color)
	_update_visible()

func _append_shaft(tool: SurfaceTool, target: Vector3, width: float, length: float, across: Vector3, strength: float) -> void:
	var start := target-direction*length
	for angle in [-0.22,0.22]:
		var side := across.rotated(direction,angle)
		var a := start-side*width*0.3
		var b := start+side*width*0.3
		var c := target+side*width*0.65
		var d := target-side*width*0.65
		for pair in [[a,Vector2(0,0)],[b,Vector2(1,0)],[c,Vector2(1,1)],[a,Vector2(0,0)],[c,Vector2(1,1)],[d,Vector2(0,1)]]:
			tool.set_color(Color(1,1,1,strength))
			tool.set_uv(pair[1])
			tool.add_vertex(pair[0])

func _visual_hash(tile: Vector2i, salt: int) -> int:
	return int((tile.x*73856093 ^ tile.y*19349663 ^ main.dungeon_renderer.floor_visual_seed*83492791 ^ salt*2654435761) & 0x7fffffff)

func _plan_supports(data: DungeonData, room_id: int, candidates: Array[Vector2i], across: Vector3) -> void:
	var primary := receiver
	var width := effective_width
	var length := effective_length
	var blocked := blocked_by
	var desired := _visual_hash(data.rooms[room_id].position,room_id+71)%3
	var ordered := candidates.duplicate()
	ordered.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		var ha := _visual_hash(a,room_id+113)
		var hb := _visual_hash(b,room_id+113)
		return ha < hb if ha != hb else (a.y < b.y if a.y != b.y else a.x < b.x))
	for tile in ordered:
		if supporting_beams.size() >= desired: break
		receiver = main.dungeon_renderer.get_entity_world_position(tile)+Vector3(0,0.12,0)
		if receiver.distance_to(primary) < maxf(1.2,width*0.45): continue
		var separated := true
		for beam in supporting_beams:
			if receiver.distance_to(beam.receiver) < 1.3: separated = false
		if not separated: continue
		effective_width = width*0.32
		effective_length = length*0.8
		if _clear_sun_path(across):
			supporting_beams.append({"tile":tile,"receiver":receiver,"width":effective_width,"length":effective_length})
	receiver = primary
	effective_width = width
	effective_length = length
	blocked_by = blocked

func _clear_sun_path(across: Vector3) -> bool:
	# Conservative static visual-bound tests, never physics or gameplay collision.
	# Block the whole fake shaft rather than allow it through a solid overhang.
	blocked_by = ""
	var footprint_side := Vector3(across.x,0,across.z).normalized()
	var margin := footprint_side.abs()*effective_width*0.65
	var top := receiver-direction*effective_length
	var minimum := receiver.min(top)-margin
	var maximum := receiver.max(top)+margin
	var candidates: Dictionary = {}
	for y in range(floori(minimum.z+0.5),floori(maximum.z+0.5)+1):
		for x in range(floori(minimum.x+0.5),floori(maximum.x+0.5)+1):
			for index: int in _sun_cells.get(Vector2i(x,y),[]): candidates[index] = true
	for offset: float in [-0.65,-0.325,0.0,0.325,0.65]:
		var origin := receiver+footprint_side*effective_width*offset
		var end := origin-direction*effective_length
		for index: int in candidates:
			var bounds: AABB = _sun_bounds[index]
			if bounds.grow(-0.005).intersects_segment(origin,end) != null:
				blocked_by = str(bounds)
				return false
	return true

func _index_sun_bounds() -> void:
	_sun_bounds.clear()
	_sun_cells.clear()
	for visual in main.dungeon_renderer.fog_visuals:
		var node: MeshInstance3D = visual.mesh
		var bounds: AABB = node.global_transform*node.get_aabb()
		var index := _sun_bounds.size()
		_sun_bounds.append(bounds)
		for y in range(floori(bounds.position.z+0.5),floori(bounds.end.z+0.5)+1):
			for x in range(floori(bounds.position.x+0.5),floori(bounds.end.x+0.5)+1):
				var cell := Vector2i(x,y)
				if not _sun_cells.has(cell): _sun_cells[cell] = []
				_sun_cells[cell].append(index)

func refresh_visibility() -> void:
	if mask_image == null: return
	mask_image.fill(Color.BLACK)
	var data: DungeonData = main.dungeon
	ground_mist.refresh(data)
	for tile: Vector2i in data.bright_tiles:
		if mask_bounds.has_point(tile): mask_image.set_pixelv(tile-mask_bounds.position,Color.WHITE)
		for offset in DungeonData.CARDINALS:
			var neighbor: Vector2i = tile+offset
			if not data.is_walkable(neighbor) and mask_bounds.has_point(neighbor): mask_image.set_pixelv(neighbor-mask_bounds.position,Color.WHITE)
	mask_texture.update(mask_image)
	mask_updates += 1
	_update_visible()

func _update_visible() -> void:
	var bright: bool = is_instance_valid(main) and main.get("dungeon") != null and main.dungeon.is_bright(receiver_tile)
	bright = bright and (not auto_place_demo or _room_id >= 0)
	mesh_effect.visible = placement_safe and bright and selected_mode == Mode.MESH
	mist.visible = placement_safe and bright and selected_mode == Mode.VOLUMETRIC

func apply_mode(mode: int) -> void:
	# Retained for controlled comparison tests, not bound to gameplay input/UI.
	assert(mode >= 0 and mode <= 2)
	_restore_environment()
	selected_mode = mode
	if not is_instance_valid(lighting): return
	if mode == Mode.VOLUMETRIC:
		_source_environment = lighting.world.environment
		_owned_environment = _source_environment.duplicate(true)
		_owned_environment.volumetric_fog_enabled = true
		_owned_environment.volumetric_fog_density = 0.0
		_owned_environment.volumetric_fog_length = 24.0
		_owned_environment.volumetric_fog_ambient_inject = 0.0
		_owned_environment.volumetric_fog_gi_inject = 0.0
		_owned_environment.volumetric_fog_anisotropy = 0.35
		_owned_environment.volumetric_fog_temporal_reprojection_amount = 0.8
		lighting.world.environment = _owned_environment
		_sun_fog_energy = lighting.sun.light_volumetric_fog_energy
		lighting.sun.light_volumetric_fog_energy = scattering_energy
	_update_visible()

func _restore_environment() -> void:
	if is_instance_valid(lighting) and _owned_environment != null:
		if lighting.world.environment == _owned_environment: lighting.world.environment = _source_environment
		lighting.sun.light_volumetric_fog_energy = _sun_fog_energy
	_owned_environment = null
	_source_environment = null

func _lighting_changed(_index: int, _title: String) -> void:
	_restore_environment()
	_room_cache.clear()
	if auto_place_demo and _room_id >= 0: _place_room(main.dungeon,_room_id)
	else: rebuild()
	apply_mode(selected_mode)

func _exit_tree() -> void: _restore_environment()
