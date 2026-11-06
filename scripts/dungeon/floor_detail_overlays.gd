class_name FloorDetailOverlays
extends Node3D
## Rendering-only floor detail (Hades-style variety):
## - a soft grime band where room floors meet walls;
## - patchy green moss on corridor floors.
## Each is one merged mesh with a multiply-blend shader: no collision,
## navigation, shadows or gameplay effects, and no RNG. Patterns come from
## world position only. DungeonRenderer frees and rebuilds this node on every
## render. To remove the feature entirely, delete this file, the two shaders
## and the block marked "FloorDetailOverlays" in dungeon_renderer.gd.

const GRIME_SHADER = preload("res://shaders/floor_grime_band.gdshader")
const MOSS_SHADER = preload("res://shaders/corridor_moss.gdshader")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## Inner wall face from the FLOOR_WALL model (z = 0.786 source units * 0.5
## SOURCE_SCALE), plus a small overlap so the band meets the wall base.
const WALL_FACE := 0.42
const SURFACE_LIFT := 0.004

var grime: MeshInstance3D
var moss: MeshInstance3D
var stats := {"grime_bands": 0, "moss_tiles": 0}

static func is_wall_side(data: DungeonData, tile: Vector2i) -> bool:
	# Same rule DungeonRenderer.create_floor_tile uses to place wall meshes.
	return data.get_tile(tile) in [DungeonData.TileType.WALL, DungeonData.TileType.VOID]

func setup(data: DungeonData, renderer: DungeonRenderer) -> void:
	name = "FloorDetailOverlays"
	if renderer.floor_grime_enabled: grime = _build_grime(data, renderer)
	if renderer.corridor_moss_enabled: moss = _build_moss(data, renderer)

func _build_grime(data: DungeonData, renderer: DungeonRenderer) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := renderer.floor_grime_depth
	for tile: Vector2i in data.tiles:
		if data.get_tile(tile) != DungeonData.TileType.FLOOR or data.reserved_transitions.has(tile): continue
		# Open upper platforms have no walls to dirty.
		if renderer.is_open_upper_tile(tile): continue
		var top := renderer.get_entity_world_position(tile) + Vector3(0, SURFACE_LIFT, 0)
		for direction in DIRECTIONS:
			if not is_wall_side(data, tile + direction): continue
			var normal := Vector3(direction.x, 0, direction.y)
			var side := Vector3(-direction.y, 0, direction.x)
			var outer := top + normal * WALL_FACE
			var inner := top + normal * (WALL_FACE - depth)
			var along := (outer - side * 0.5).dot(side.abs())
			_quad(tool,
				[outer - side * 0.5, outer + side * 0.5, inner + side * 0.5, inner - side * 0.5],
				[Vector2(along, 0), Vector2(along + 1.0, 0), Vector2(along + 1.0, 1), Vector2(along, 1)])
			stats.grime_bands += 1
	if stats.grime_bands == 0: return null
	var material := ShaderMaterial.new()
	material.shader = GRIME_SHADER
	material.set_shader_parameter("strength", renderer.floor_grime_strength)
	return _instance("FloorGrime", tool.commit(), material)

func _build_moss(data: DungeonData, renderer: DungeonRenderer) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tile: Vector2i in data.tiles:
		if data.get_tile(tile) != DungeonData.TileType.CORRIDOR or data.reserved_transitions.has(tile): continue
		var top := renderer.get_entity_world_position(tile) + Vector3(0, SURFACE_LIFT * 1.5, 0)
		var half := 0.5 if renderer.is_open_upper_tile(tile) else WALL_FACE
		var points := []
		var uvs := []
		for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var edge := not data.is_walkable(tile + Vector2i(corner.x, 0)) or not data.is_walkable(tile + Vector2i(0, corner.y))
			points.append(top + Vector3(corner.x * half, 0, corner.y * half))
			uvs.append(Vector2(0, 0.0 if edge else 1.0))
		_quad(tool, points, uvs)
		stats.moss_tiles += 1
	if stats.moss_tiles == 0: return null
	var material := ShaderMaterial.new()
	material.shader = MOSS_SHADER
	material.set_shader_parameter("coverage", renderer.corridor_moss_coverage)
	material.set_shader_parameter("moss_color", renderer.corridor_moss_color)
	return _instance("CorridorMoss", tool.commit(), material)

func _quad(tool: SurfaceTool, points: Array, uvs: Array) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		tool.set_uv(uvs[index])
		tool.add_vertex(points[index])

func _instance(label: String, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("geometry_purpose", "floor_detail_overlay")
	add_child(node)
	return node
