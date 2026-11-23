class_name OutOfBoundsScenery
extends Node3D
## Continuous procedural terrain around the logical map. The map sits on a
## plateau: at its west, north and east edges the ground drops into a lowland of
## small ridged mountains whose tops stay near map level, so the fixed gameplay
## camera (which only reaches a few tiles past the edge) looks down onto whole
## mountains. The flat border ground, apron and out-of-map filler on those sides
## are omitted by the renderer while this node owns them. Rendering only: no tiles,
## elevations, spawns, traversal or generator RNG change; noise is seeded from
## the renderer's visual seed plus the floor's spawn and stairs positions (read
## only), so each floor gets its own range. Built once per floor as spatial chunks.
##
## The terrain covers the west, north and east sides. Nothing rises south of the
## map, where the fixed camera sits; heights fade to the ground toward that line.

const SHADER = preload("res://shaders/out_of_bounds_terrain.gdshader")
## Vertex spacing in world units (one tile is 1.0); fine enough for small ridges.
const SPACING := 0.25
## Chunk size in world units, so off-screen parts are frustum-culled.
const CHUNK_SIZE := 16.0
## Where the terrain meets the remaining south border rocks it stays this far above them.
const CLEARANCE := 0.02
## How much the ridged layer shapes the mountains versus the rolling layer.
const RIDGE_BLEND := 0.6
## How far the strip tucked under the edge rock drops below the rim.
const TUCK_DROP := 1.5
## The terrain edge sits this far below the edge-rock tops.
const RIM_SINK := 0.06
const PEAK_SHARPNESS := 1.4

var material: ShaderMaterial
var chunks: Array[MeshInstance3D] = []
var diagnostics := {"vertices": 0, "triangles": 0, "mesh_nodes": 0, "max_height": 0.0}
var shade_lift: float = 0.0
var region: Rect2 # World-space XZ extent of the terrain grid.
var map_rect: Rect2 # World-space XZ edge of the logical map.
var kept: Dictionary = {} # Map cells the layout keeps as cave rock; no terrain over them.
var _distance := PackedFloat32Array() # Per cell: distance from its centre to the nearest kept cell centre.
var _distance_origin := Vector2i.ZERO
var _distance_size := Vector2i.ZERO
var _quad_drawn := PackedByteArray() # Per grid quad: 1 when it is part of the terrain surface.
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
var shadows: bool = true


func setup(data: DungeonData, backdrop: CaveTerrainBackdrop, renderer: DungeonRenderer) -> void:
	set_meta("geometry_purpose", "out_of_bounds_scenery")
	shade_lift = renderer.out_of_bounds_shade_lift
	material = ShaderMaterial.new()
	material.shader = SHADER
	RockTextureSet.ensure()
	material.set_shader_parameter("rock_layers", RockTextureSet.layers)
	material.set_shader_parameter("macro_noise", RockTextureSet.macro)
	_settings = {
		"depth": maxf(0.0, renderer.out_of_bounds_lowland_depth),
		"rim": maxf(0.1, renderer.out_of_bounds_rim_width),
		"mountain": maxf(0.0, renderer.out_of_bounds_mountain_height),
		"rise": maxf(0.1, renderer.out_of_bounds_rise_distance),
		"south_fade": maxf(0.5, renderer.out_of_bounds_south_fade),
		"ledge": maxf(0.0, renderer.out_of_bounds_ledge_width),
	}
	_configure_noise(renderer, layout_key(data))
	ground_level = TerrainFillVisuals.wall_top_offset(0.1, 0.5)
	# Valley floors darken toward the lowland; crests lighten toward the map rim.
	material.set_shader_parameter("height_low", lowland_level())
	material.set_shader_parameter("height_high", ground_level + 0.1)
	shadows = renderer.out_of_bounds_cast_shadows
	map_rect = Rect2(Vector2(data.map_bounds.position) - Vector2.ONE * 0.5, Vector2(data.map_bounds.size))
	kept = renderer.kept_cells_for(data)
	south_cut = map_rect.end.y
	var extent := float(renderer.out_of_bounds_extent)
	region = Rect2(map_rect.position - Vector2.ONE * extent, Vector2(map_rect.size.x + 2.0 * extent, south_cut - (map_rect.position.y - extent)))
	# Only the south border rocks remain; where the terrain fades back to map
	# level near the southern edge it must sit on or above them. Each cell corner
	# takes the highest top of its neighboring external cells.
	# Kept layout rocks also give the rim its height, so the terrain edge meets
	# the top of the one-tile rock buffer instead of leaving a step open to the sky.
	for record in backdrop.records:
		if not record.external and not kept.has(record.cell): continue
		var cell: Vector2i = record.cell
		for corner in [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]:
			_floor_corners[corner] = maxf(float(_floor_corners.get(corner, ground_level)), float(record.top))
	_build_distance()
	_columns = roundi(region.size.x / SPACING) + 1
	_rows = roundi(region.size.y / SPACING) + 1
	_heights.resize(_columns * _rows)
	_fill_heights()
	_mark_quads()
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


## Two-pass chamfer distance between cell centres over the region (kept cells 0).
func _build_distance() -> void:
	_distance_origin = Vector2i(floori(region.position.x), floori(region.position.y)) - Vector2i.ONE
	_distance_size = Vector2i(ceili(region.size.x), ceili(region.size.y)) + Vector2i.ONE * 3
	var w := _distance_size.x
	_distance.resize(w * _distance_size.y)
	var far := 1e6 if not kept.is_empty() else 0.0
	for y in range(_distance_size.y):
		for x in range(w):
			_distance[y * w + x] = 0.0 if kept.has(_distance_origin + Vector2i(x, y)) else far
	if kept.is_empty(): return
	var forward := [[-1, 0, 1.0], [0, -1, 1.0], [-1, -1, 1.41421356], [1, -1, 1.41421356]]
	for y in range(_distance_size.y):
		for x in range(w):
			_relax(x, y, forward)
	var backward := [[1, 0, 1.0], [0, 1, 1.0], [1, 1, 1.41421356], [-1, 1, 1.41421356]]
	for y in range(_distance_size.y - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			_relax(x, y, backward)


func _relax(x: int, y: int, steps: Array) -> void:
	var w := _distance_size.x
	var best := _distance[y * w + x]
	for step in steps:
		var nx: int = x + step[0]
		var ny: int = y + step[1]
		if nx < 0 or ny < 0 or nx >= w or ny >= _distance_size.y: continue
		best = minf(best, _distance[ny * w + nx] + step[2])
	_distance[y * w + x] = best


func _cell_distance(cell: Vector2i) -> float:
	var local := (cell - _distance_origin).clamp(Vector2i.ZERO, _distance_size - Vector2i.ONE)
	return _distance[local.y * _distance_size.x + local.x]


## Distance from a world XZ point to the edge of the kept layout cells.
func map_distance(x: float, z: float) -> float:
	var cx := floori(x)
	var cz := floori(z)
	var tx := x - cx
	var tz := z - cz
	var a := _cell_distance(Vector2i(cx, cz))
	var b := _cell_distance(Vector2i(cx + 1, cz))
	var c := _cell_distance(Vector2i(cx, cz + 1))
	var d := _cell_distance(Vector2i(cx + 1, cz + 1))
	return maxf(0.0, lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz) - 0.5)


func is_kept_point(x: float, z: float) -> bool:
	return kept.has(Vector2i(floori(x + 0.5), floori(z + 0.5)))


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


## Local distance-grid index of a cell coordinate, clamped to the grid.
func _local_x(cell_x: int) -> int:
	return clampi(cell_x - _distance_origin.x, 0, _distance_size.x - 1)


func _local_z(cell_z: int) -> int:
	return clampi(cell_z - _distance_origin.y, 0, _distance_size.y - 1) * _distance_size.x


## Heights for every grid vertex. Same result as height_at() plus the tuck drop,
## with the per-axis cell lookups hoisted out of the inner loop.
func _fill_heights() -> void:
	var ledge := float(_settings.ledge)
	var tucking := not kept.is_empty()
	var cx0 := PackedInt32Array(); var cx1 := PackedInt32Array(); var tx := PackedFloat32Array()
	var ux0 := PackedInt32Array(); var ux1 := PackedInt32Array()
	for column in range(_columns):
		var x := region.position.x + column * SPACING
		var cell := floori(x)
		cx0.append(_local_x(cell)); cx1.append(_local_x(cell + 1)); tx.append(x - cell)
		# Cells touching the vertex: one, or two when it lies on a cell edge.
		var edge := x + 0.5
		var on_edge := absf(edge - roundf(edge)) < 0.001
		ux0.append(_local_x(roundi(edge) - 1 if on_edge else floori(edge)))
		ux1.append(_local_x(roundi(edge) if on_edge else floori(edge)))
	for row in range(_rows):
		var z := region.position.y + row * SPACING
		var cell_z := floori(z)
		var z0 := _local_z(cell_z)
		var z1 := _local_z(cell_z + 1)
		var tz := z - cell_z
		var edge_z := z + 0.5
		var on_edge_z := absf(edge_z - roundf(edge_z)) < 0.001
		var uz0 := _local_z(roundi(edge_z) - 1 if on_edge_z else floori(edge_z))
		var uz1 := _local_z(roundi(edge_z) if on_edge_z else floori(edge_z))
		for column in range(_columns):
			var a := _distance[z0 + cx0[column]]
			var b := _distance[z0 + cx1[column]]
			var c := _distance[z1 + cx0[column]]
			var d := _distance[z1 + cx1[column]]
			var t := tx[column]
			var distance := maxf(0.0, lerpf(lerpf(a, b, t), lerpf(c, d, t), tz) - 0.5)
			var x := region.position.x + column * SPACING
			var height := _surface(x, z, maxf(0.0, distance - ledge))
			# Vertices with only kept cells around them sit under the edge rock:
			# the tucked strip slopes down there so it never shows above the rock.
			if tucking and _distance[uz0 + ux0[column]] == 0.0 and _distance[uz0 + ux1[column]] == 0.0 and _distance[uz1 + ux0[column]] == 0.0 and _distance[uz1 + ux1[column]] == 0.0:
				height -= TUCK_DROP
			_heights[row * _columns + column] = height


## Which grid quads the terrain draws: those outside kept cells, plus a strip one
## quad wide just inside kept cells along a terrain-owned neighbor, tucked under
## the edge rock so no crack opens along the shared edge.
func _mark_quads() -> void:
	var quad_columns := _columns - 1
	_quad_drawn.resize(quad_columns * (_rows - 1))
	_quad_drawn.fill(1)
	if kept.is_empty(): return
	var own := PackedInt32Array(); var left := PackedInt32Array(); var right := PackedInt32Array(); var fx := PackedFloat32Array()
	for column in range(quad_columns):
		var x := region.position.x + (column + 0.5) * SPACING + 0.5
		var cell := floori(x)
		own.append(_local_x(cell)); left.append(_local_x(cell - 1)); right.append(_local_x(cell + 1)); fx.append(x - cell)
	for row in range(_rows - 1):
		var z := region.position.y + (row + 0.5) * SPACING + 0.5
		var cell_z := floori(z)
		var own_z := _local_z(cell_z)
		var up_z := _local_z(cell_z - 1)
		var down_z := _local_z(cell_z + 1)
		var fz := z - cell_z
		for column in range(quad_columns):
			if _distance[own_z + own[column]] != 0.0: continue
			var f := fx[column]
			var tuck := (f < SPACING and _distance[own_z + left[column]] != 0.0) or (f > 1.0 - SPACING and _distance[own_z + right[column]] != 0.0) \
				or (fz < SPACING and _distance[up_z + own[column]] != 0.0) or (fz > 1.0 - SPACING and _distance[down_z + own[column]] != 0.0)
			if not tuck: _quad_drawn[row * quad_columns + column] = 0


## World height of the lowland floor, below the map rim.
func lowland_level() -> float:
	return ground_level - float(_settings.depth)


## Terrain surface height at a world XZ point (also defined over the map, for normals).
## The rim stays at map level at the edge, drops to the lowland over the rim width,
## and small ridged mountains rise from the lowland toward map level. Near the
## southern edge everything blends back up to the remaining border ground.
func height_at(x: float, z: float) -> float:
	# A flat ledge at map level runs along the layout before the rim drops.
	return _surface(x, z, maxf(0.0, map_distance(x, z) - float(_settings.ledge)))


func _surface(x: float, z: float, distance: float) -> float:
	var south := smoothstep(south_cut - _settings.south_fade, south_cut, z)
	# Over and at the edge of kept cells: the rock buffer's height, no noise needed.
	# Just under the rock tops, so the terrain edge never shows as a lip above them.
	if distance <= 0.0:
		var edge := floor_at(x, z) - RIM_SINK
		return lerpf(edge, maxf(edge + CLEARANCE, ground_level), south)
	var rolling := clampf((_rolling.get_noise_2d(x, z) + 1.0) * 0.5, 0.0, 1.0)
	var ridged := clampf((_ridged.get_noise_2d(x, z) + 1.0) * 0.5, 0.0, 1.0)
	var shape := pow(lerpf(rolling, ridged, RIDGE_BLEND), PEAK_SHARPNESS)
	var mountains: float = _settings.mountain * smoothstep(0.0, _settings.rise, distance) * shape
	var drop := smoothstep(0.0, _settings.rim, distance)
	# The rim height only matters until the drop completes.
	var rim := floor_at(x, z) - RIM_SINK if drop < 1.0 else 0.0
	var height := lerpf(rim, lowland_level() + mountains, drop)
	if south <= 0.0: return height # Floor lookups only matter near the southern edge.
	return lerpf(height, maxf(floor_at(x, z) + CLEARANCE, ground_level), south)


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


## Quad index ranges [start, end) per chunk along one axis.
func _chunk_ranges(origin: float, count: int) -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	var current := -1
	var begin := 0
	for index in range(count):
		var chunk := floori((origin + (index + 0.5) * SPACING) / CHUNK_SIZE)
		if chunk != current:
			if index > begin or current != -1: ranges.append(Vector2i(begin, index))
			current = chunk
			begin = index
	ranges.append(Vector2i(begin, count))
	return ranges.filter(func(r: Vector2i) -> bool: return r.y > r.x)


func _build_chunks() -> void:
	# Normals once for the whole grid (central differences, clamped at the edges).
	var grid_normals := PackedVector3Array()
	grid_normals.resize(_columns * _rows)
	for row in range(_rows):
		var up := maxi(row - 1, 0) * _columns
		var down := mini(row + 1, _rows - 1) * _columns
		var row_span := float(mini(row + 1, _rows - 1) - maxi(row - 1, 0)) * SPACING
		for column in range(_columns):
			var left := maxi(column - 1, 0)
			var right := mini(column + 1, _columns - 1)
			var dx := (_heights[row * _columns + right] - _heights[row * _columns + left]) / (float(right - left) * SPACING)
			var dz := (_heights[down + column] - _heights[up + column]) / row_span
			grid_normals[row * _columns + column] = Vector3(-dx, 1.0, -dz).normalized()
	var column_ranges := _chunk_ranges(region.position.x, _columns - 1)
	var row_ranges := _chunk_ranges(region.position.y, _rows - 1)
	# Quads over kept layout cells are skipped (see _mark_quads).
	for rows in row_ranges:
		for columns in column_ranges:
			# Every grid vertex of the block, row by row; quads inside the map are
			# simply not indexed, so their vertices are never drawn.
			var width: int = columns.y - columns.x + 1
			var height: int = rows.y - rows.x + 1
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			vertices.resize(width * height)
			normals.resize(width * height)
			for r in range(height):
				var row: int = rows.x + r
				var z := region.position.y + row * SPACING
				for c in range(width):
					var column: int = columns.x + c
					vertices[r * width + c] = Vector3(region.position.x + column * SPACING, _heights[row * _columns + column], z)
					normals[r * width + c] = grid_normals[row * _columns + column]
			var indices := PackedInt32Array()
			indices.resize((width - 1) * (height - 1) * 6)
			var count := 0
			for r in range(height - 1):
				for c in range(width - 1):
					if _quad_drawn[(rows.x + r) * (_columns - 1) + columns.x + c] == 0: continue
					var a := r * width + c
					# Godot front faces are clockwise seen from the normal side.
					indices[count] = a
					indices[count + 1] = a + 1
					indices[count + 2] = a + width
					indices[count + 3] = a + 1
					indices[count + 4] = a + width + 1
					indices[count + 5] = a + width
					count += 6
			if count == 0: continue
			indices.resize(count)
			_add_skirts(columns, rows, vertices, normals, indices)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var corner := _grid_point(columns.x, rows.x)
			var key := Vector2i(floori((corner.x + SPACING * 0.5) / CHUNK_SIZE), floori((corner.y + SPACING * 0.5) / CHUNK_SIZE))
			var node := MeshInstance3D.new()
			node.name = "OutOfBoundsTerrain_%d_%d" % [key.x, key.y]
			node.mesh = mesh
			node.material_override = material
			# Ridge shadows are what make the lowland readable from above.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.set_meta("geometry_purpose", "out_of_bounds_scenery")
			add_child(node)
			chunks.append(node)
			diagnostics.vertices += vertices.size()
			diagnostics.triangles += indices.size() / 3
			diagnostics.max_height = maxf(diagnostics.max_height, mesh.get_aabb().end.y)
	diagnostics.mesh_nodes = chunks.size()


func _add_skirts(columns: Vector2i, rows: Vector2i, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	# Close the outer west/north/east edges below the lowland, so no gap opens
	# behind the last mountains at the end of the region.
	var edges: Array = []
	for row in range(rows.x, rows.y):
		if columns.x == 0: edges.append([Vector2i(0, row + 1), Vector2i(0, row), Vector3.LEFT])
		if columns.y == _columns - 1: edges.append([Vector2i(_columns - 1, row), Vector2i(_columns - 1, row + 1), Vector3.RIGHT])
	if rows.x == 0:
		for column in range(columns.x, columns.y): edges.append([Vector2i(column, 0), Vector2i(column + 1, 0), Vector3.FORWARD])
	var base_height := skirt_base()
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		var outward: Vector3 = edge[2]
		var pa := _grid_point(a.x, a.y)
		var pb := _grid_point(b.x, b.y)
		var base := vertices.size()
		vertices.append_array([Vector3(pa.x, _grid_height(a.x, a.y), pa.y), Vector3(pb.x, _grid_height(b.x, b.y), pb.y), Vector3(pa.x, base_height, pa.y), Vector3(pb.x, base_height, pb.y)])
		normals.append_array([outward, outward, outward, outward])
		for triangle in [[base, base + 1, base + 2], [base + 1, base + 3, base + 2]]:
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


func skirt_base() -> float:
	return minf(CaveTerrainBackdrop.GROUND_BASE, lowland_level() - 2.0)
