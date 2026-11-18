class_name OutOfBoundsScenery
extends Node3D
## Continuous procedural terrain around the logical map: low rolling ground at
## the map edge rising to mountains with distance. Rendering only: no tiles,
## elevations, spawns, traversal or generator RNG change; noise is seeded from
## the renderer's visual seed plus the floor's spawn and stairs positions (read
## only), so each floor gets its own range. Built once per floor as spatial chunks.
##
## The terrain covers the west, north and east sides. Nothing rises south of the
## map, where the fixed camera sits; heights fade to the ground toward that line.

const SHADER = preload("res://shaders/out_of_bounds_terrain.gdshader")
## Vertex spacing in world units (one tile is 1.0).
const SPACING := 0.5
## Chunk size in world units, so off-screen parts are frustum-culled.
const CHUNK_SIZE := 16.0
## The surface stays this far above the border rocks it covers.
const CLEARANCE := 0.02
## Distance from the map edge over which foothills reach full height.
const FOOTHILL_RISE := 3.0
## How much the ridged layer shapes the mountains versus the rolling layer.
const RIDGE_BLEND := 0.6
const PEAK_SHARPNESS := 1.4

var material: ShaderMaterial
var chunks: Array[MeshInstance3D] = []
var diagnostics := {"vertices": 0, "triangles": 0, "mesh_nodes": 0, "max_height": 0.0}
var shade_lift: float = 0.0
var region: Rect2 # World-space XZ extent of the terrain grid.
var map_rect: Rect2 # World-space XZ edge of the logical map.
var south_cut: float = 0.0 # No terrain beyond this Z (south of the map).
var ground_level: float = 0.0
var _shade := Color.WHITE
var _columns: int = 0
var _rows: int = 0
var _heights := PackedFloat32Array()
var _floor_corners: Dictionary = {}
var _rolling := FastNoiseLite.new()
var _ridged := FastNoiseLite.new()
var _settings: Dictionary = {}


func setup(data: DungeonData, backdrop: CaveTerrainBackdrop, renderer: DungeonRenderer) -> void:
	set_meta("geometry_purpose", "out_of_bounds_scenery")
	shade_lift = renderer.out_of_bounds_shade_lift
	material = ShaderMaterial.new()
	material.shader = SHADER
	_settings = {
		"mountain": renderer.out_of_bounds_mountain_height,
		"foothill": renderer.out_of_bounds_foothill_height,
		"rise": maxf(0.5, renderer.out_of_bounds_rise_distance),
		"south_fade": maxf(0.5, renderer.out_of_bounds_south_fade),
	}
	_configure_noise(renderer, layout_key(data))
	ground_level = TerrainFillVisuals.wall_top_offset(0.1, 0.5)
	map_rect = Rect2(Vector2(data.map_bounds.position) - Vector2.ONE * 0.5, Vector2(data.map_bounds.size))
	south_cut = map_rect.end.y
	var extent := float(renderer.out_of_bounds_extent)
	region = Rect2(map_rect.position - Vector2.ONE * extent, Vector2(map_rect.size.x + 2.0 * extent, south_cut - (map_rect.position.y - extent)))
	# The surface must cover every border rock beneath it. Each cell corner takes
	# the highest top of its neighboring external cells, so the bilinear floor
	# over a cell never dips below that cell's rock.
	for record in backdrop.records:
		if not record.external: continue
		var cell: Vector2i = record.cell
		for corner in [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]:
			_floor_corners[corner] = maxf(float(_floor_corners.get(corner, ground_level)), float(record.top))
	_columns = roundi(region.size.x / SPACING) + 1
	_rows = roundi(region.size.y / SPACING) + 1
	_heights.resize(_columns * _rows)
	for row in range(_rows):
		for column in range(_columns):
			var point := _grid_point(column, row)
			_heights[row * _columns + column] = height_at(point.x, point.y)
	_build_chunks()
	set_meta("geometry_bounds", Rect2i(Vector2i(region.position.ceil()), Vector2i(region.size.floor())))


## Deterministic per-floor key from read-only layout positions.
static func layout_key(data: DungeonData) -> int:
	var spawn := data.player_spawn
	var stairs := data.stairs_position
	return posmod(spawn.x * 73856093 ^ spawn.y * 19349663 ^ stairs.x * 83492791 ^ stairs.y * 50331653, 1000003)


func _configure_noise(renderer: DungeonRenderer, layout: int) -> void:
	# Independent of generation RNG: visual seed plus the per-floor layout key.
	var feature := maxf(2.0, renderer.out_of_bounds_feature_size)
	var base_seed := posmod(renderer.floor_visual_seed * 7919 + layout * 31, 2147483647)
	_rolling.seed = base_seed + 17
	_rolling.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rolling.fractal_type = FastNoiseLite.FRACTAL_FBM
	_rolling.fractal_octaves = 4
	_rolling.fractal_gain = renderer.out_of_bounds_roughness
	_rolling.frequency = 1.0 / feature
	_ridged.seed = base_seed + 101
	_ridged.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridged.fractal_octaves = 4
	_ridged.fractal_gain = renderer.out_of_bounds_roughness
	_ridged.frequency = 1.0 / (feature * 1.3)


func _grid_point(column: int, row: int) -> Vector2:
	return region.position + Vector2(column, row) * SPACING


## Distance in world units from a point to the logical map rectangle (0 inside).
func map_distance(x: float, z: float) -> float:
	var dx := maxf(maxf(map_rect.position.x - x, x - map_rect.end.x), 0.0)
	var dz := maxf(maxf(map_rect.position.y - z, z - map_rect.end.y), 0.0)
	return Vector2(dx, dz).length()


## Bilinear floor from cell-corner rock tops; the apron height elsewhere.
func floor_at(x: float, z: float) -> float:
	var fx := x + 0.5
	var fz := z + 0.5
	var cx := floori(fx)
	var cz := floori(fz)
	var tx := fx - cx
	var tz := fz - cz
	var a := float(_floor_corners.get(Vector2i(cx, cz), ground_level))
	var b := float(_floor_corners.get(Vector2i(cx + 1, cz), ground_level))
	var c := float(_floor_corners.get(Vector2i(cx, cz + 1), ground_level))
	var d := float(_floor_corners.get(Vector2i(cx + 1, cz + 1), ground_level))
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


## Terrain surface height at a world XZ point (also defined over the map, for normals).
func height_at(x: float, z: float) -> float:
	var distance := map_distance(x, z)
	var rolling := clampf((_rolling.get_noise_2d(x, z) + 1.0) * 0.5, 0.0, 1.0)
	var ridged := clampf((_ridged.get_noise_2d(x, z) + 1.0) * 0.5, 0.0, 1.0)
	var foothills: float = _settings.foothill * smoothstep(0.0, FOOTHILL_RISE, distance) * rolling
	var shape := pow(lerpf(rolling, ridged, RIDGE_BLEND), PEAK_SHARPNESS)
	var mountains: float = _settings.mountain * smoothstep(0.0, _settings.rise, distance) * shape
	var south := 1.0 - smoothstep(south_cut - _settings.south_fade, south_cut, z)
	return maxf(floor_at(x, z) + CLEARANCE, ground_level + (foothills + mountains) * south)


func _grid_height(column: int, row: int) -> float:
	return _heights[clampi(row, 0, _rows - 1) * _columns + clampi(column, 0, _columns - 1)]


func _grid_normal(column: int, row: int) -> Vector3:
	var left := maxi(column - 1, 0)
	var right := mini(column + 1, _columns - 1)
	var up := maxi(row - 1, 0)
	var down := mini(row + 1, _rows - 1)
	var dx := (_grid_height(right, row) - _grid_height(left, row)) / (float(right - left) * SPACING)
	var dz := (_grid_height(column, down) - _grid_height(column, up)) / (float(down - up) * SPACING)
	return Vector3(-dx, 1.0, -dz).normalized()


func _include_quad(column: int, row: int) -> bool:
	# Outside the map only; the region already ends at the southern map edge.
	var center := _grid_point(column, row) + Vector2.ONE * SPACING * 0.5
	return not map_rect.has_point(center)


func _build_chunks() -> void:
	var groups: Dictionary = {}
	for row in range(_rows - 1):
		for column in range(_columns - 1):
			if not _include_quad(column, row): continue
			var center := _grid_point(column, row) + Vector2.ONE * SPACING * 0.5
			var key := Vector2i(floori(center.x / CHUNK_SIZE), floori(center.y / CHUNK_SIZE))
			if not groups.has(key): groups[key] = []
			groups[key].append(Vector2i(column, row))
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		var local: Dictionary = {}
		for quad: Vector2i in groups[key]:
			var corners := [quad, quad + Vector2i.RIGHT, quad + Vector2i.DOWN, quad + Vector2i.ONE]
			var ids: Array[int] = []
			for corner: Vector2i in corners:
				if not local.has(corner):
					local[corner] = vertices.size()
					var point := _grid_point(corner.x, corner.y)
					vertices.append(Vector3(point.x, _grid_height(corner.x, corner.y), point.y))
					normals.append(_grid_normal(corner.x, corner.y))
				ids.append(local[corner])
			# Godot front faces are clockwise seen from the normal side.
			indices.append_array([ids[0], ids[1], ids[2], ids[1], ids[3], ids[2]])
		_add_skirts(groups[key], vertices, normals, indices)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.name = "OutOfBoundsTerrain_%d_%d" % [key.x, key.y]
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("geometry_purpose", "out_of_bounds_scenery")
		add_child(node)
		chunks.append(node)
		diagnostics.vertices += vertices.size()
		diagnostics.triangles += indices.size() / 3
		for vertex in vertices: diagnostics.max_height = maxf(diagnostics.max_height, vertex.y)
	diagnostics.mesh_nodes = chunks.size()


func _add_skirts(quads: Array, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	# Close the outer west/north/east edges down to the ground base, so no gap
	# opens behind tall mountains at the end of the region.
	for quad: Vector2i in quads:
		var edges: Array = []
		if quad.x == 0: edges.append([quad + Vector2i.DOWN, quad, Vector3.LEFT])
		if quad.x == _columns - 2: edges.append([quad + Vector2i.RIGHT, quad + Vector2i.ONE, Vector3.RIGHT])
		if quad.y == 0: edges.append([quad, quad + Vector2i.RIGHT, Vector3.FORWARD])
		for edge in edges:
			var a: Vector2i = edge[0]
			var b: Vector2i = edge[1]
			var outward: Vector3 = edge[2]
			var pa := _grid_point(a.x, a.y)
			var pb := _grid_point(b.x, b.y)
			var top_a := Vector3(pa.x, _grid_height(a.x, a.y), pa.y)
			var top_b := Vector3(pb.x, _grid_height(b.x, b.y), pb.y)
			var base := vertices.size()
			vertices.append_array([top_a, top_b, Vector3(pa.x, CaveTerrainBackdrop.GROUND_BASE, pa.y), Vector3(pb.x, CaveTerrainBackdrop.GROUND_BASE, pb.y)])
			normals.append_array([outward, outward, outward, outward])
			var first := [base, base + 1, base + 2]
			var second := [base + 1, base + 3, base + 2]
			for triangle in [first, second]:
				var cross := (vertices[triangle[1]] - vertices[triangle[0]]).cross(vertices[triangle[2]] - vertices[triangle[0]])
				if cross.dot(outward) > 0.0: triangle = [triangle[0], triangle[2], triangle[1]]
				indices.append_array(triangle)


func apply_shade(shade: Color) -> void:
	if material == null: return
	# Distant terrain is sky-lit: lift the border palette toward white by a fixed share.
	_shade = shade.lerp(Color.WHITE, shade_lift)
	_shade.a = 1.0
	material.set_shader_parameter("fog_shade", Vector3(_shade.r, _shade.g, _shade.b))


func current_shade() -> Color:
	return _shade
