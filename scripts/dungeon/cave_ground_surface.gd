class_name CaveGroundSurface
extends RefCounted
## Floor-lifetime chunk geometry and tiny fog palette. No process callback.
const SHADER = preload("res://shaders/cave_ground.gdshader")
var chunks: Array[MeshInstance3D] = []
var cells: Dictionary = {}
var palette: Image
var palette_texture: ImageTexture
var material: ShaderMaterial
var bounds: Rect2i
var weathered: bool
var visual_seed: int
var slope_profiles: Dictionary = {}
var _corners: Dictionary = {}
var _plateaus: Dictionary = {}
var stats := {"triangles": 0, "top_rectangles": 0, "weathered_tops": 0, "omitted_sides": 0, "palette_uploads": 0}

func setup(parent: Node3D, records: Array[Dictionary], visual_bounds: Rect2i, renderer: DungeonRenderer) -> void:
	bounds = visual_bounds
	weathered = renderer.cave_weathered_edges_enabled
	visual_seed = renderer.floor_visual_seed
	slope_profiles = renderer.cave_rock_profiles.get("ground",{})
	palette = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	palette.fill(ModularDungeonVisuals.FILL_COLOR * renderer.dim_material.albedo_color)
	palette_texture = ImageTexture.create_from_image(palette)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("fog_palette", palette_texture)
	material.set_shader_parameter("palette_origin", Vector2(bounds.position))
	material.set_shader_parameter("palette_size", Vector2(bounds.size))
	material.set_shader_parameter("stone_detail", CaveStoneMaterial.detail())
	material.set_shader_parameter("stone_enabled", renderer.cave_stone_mapping_enabled)
	var groups: Dictionary = {}
	for record in records:
		cells[record.cell] = record
		var tile: Vector2i = record.cell
		var chunk := Vector2i(floori(float(tile.x) / renderer.cave_batch_chunk_size), floori(float(tile.y) / renderer.cave_batch_chunk_size))
		if not groups.has(chunk): groups[chunk] = []
		groups[chunk].append(tile)
	for key in groups:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var available: Dictionary = {}
		for tile in groups[key]:
			if flat(tile): available[tile] = true
		# Greedy coplanar rectangles stop at chunk boundaries. Fog is independent
		# of triangulation, sampled from the exact owning cell in the shader.
		for tile: Vector2i in groups[key]:
			if available.has(tile):
				var width := 1
				var height := 1
				while compatible(tile + Vector2i(width,0), tile, available): width += 1
				while true:
					var row := true
					for x in range(width):
						if not compatible(tile + Vector2i(x,height),tile,available): row = false
					if not row: break
					height += 1
				for y in range(height):
					for x in range(width): available.erase(tile+Vector2i(x,y))
				var top := plateau_height(tile)
				var a := Vector3(tile.x-0.5,top,tile.y-0.5)
				quad(tool,a,a+Vector3(width,0,0),a+Vector3(width,0,height),a+Vector3(0,0,height),Vector3.UP)
				stats.top_rectangles += 1
			elif not flat(tile):
				var corners := top_corners(tile)
				var inner := PackedVector3Array()
				for corner in corners:
					inner.append(Vector3(lerpf(corner.x,tile.x,0.56),plateau_height(tile),lerpf(corner.z,tile.y,0.56)))
				quad(tool,inner[0],inner[1],inner[2],inner[3],Vector3.UP)
				# Broad half-pyramid sides meet the actual neighboring height;
				# the angular central plateau remains at the original tile height.
				for edge in range(4):
					var next := (edge+1)%4
					quad(tool,inner[edge],corners[edge],corners[next],inner[next],Vector3.UP)
				stats.weathered_tops += 1
			# Only exposed side bands. Neighbors across chunk boundaries count too.
			var corners := top_corners(tile)
			for edge in range(4):
				var direction: Vector2i = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][edge]
				var neighbor := tile + direction
				var low_a: float = cells[tile].bottom
				var low_b := low_a
				var a: Vector3 = corners[edge]
				var b: Vector3 = corners[(edge+1)%4]
				if cells.has(neighbor):
					low_a = maxf(low_a,corner_height(Vector2i(roundi(a.x+0.5),roundi(a.z+0.5)),cells[neighbor]))
					low_b = maxf(low_b,corner_height(Vector2i(roundi(b.x+0.5),roundi(b.z+0.5)),cells[neighbor]))
				if low_a >= a.y-0.00001 and low_b >= b.y-0.00001:
					stats.omitted_sides += 1
					continue
				low_a = minf(low_a,a.y)
				low_b = minf(low_b,b.y)
				quad(tool,a,b,Vector3(b.x,low_b,b.z),Vector3(a.x,low_a,a.z),Vector3(direction.x,0,direction.y))
		var mesh := tool.commit()
		if mesh == null: continue
		var node := MeshInstance3D.new()
		node.name = "CaveSurface_%d_%d" % [key.x,key.y]
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("geometry_purpose", "continuous_cave_ground")
		parent.add_child(node)
		chunks.append(node)

func compatible(tile: Vector2i, origin: Vector2i, available: Dictionary) -> bool:
	return available.has(tile) and is_equal_approx(plateau_height(tile),plateau_height(origin))

func plateau_height(tile: Vector2i) -> float:
	# Fill tiny enclosed depressions instead of producing an inverted pyramid
	# in every low cell surrounded by higher rock. Preserve broad angular tops.
	if _plateaus.has(tile): return _plateaus[tile]
	var heights: Array[float] = []
	for point in top_corners(tile): heights.append(point.y)
	heights.sort()
	var height := maxf(cells[tile].top,heights[1])
	_plateaus[tile] = height
	return height

func corner_height(corner: Vector2i, record: Dictionary) -> float:
	var top: float = record.top
	if not weathered or not slope_profiles.has(record.cell): return top
	var offset: Vector2i = corner-record.cell
	var index := 0 if offset.y == 0 and offset.x == 0 else (1 if offset.y == 0 else (2 if offset.x == 1 else 3))
	return slope_profiles[record.cell][index].y

func top_corners(tile: Vector2i) -> PackedVector3Array:
	if _corners.has(tile): return _corners[tile]
	var result := PackedVector3Array()
	for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
		var corner: Vector2i = tile+offset
		result.append(Vector3(corner.x-0.5,corner_height(corner,cells[tile]),corner.y-0.5))
	_corners[tile] = result
	return result

func flat(tile: Vector2i) -> bool:
	var height := plateau_height(tile)
	for point in top_corners(tile):
		if not is_equal_approx(point.y,height): return false
	return true

func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.is_zero_approx(): return
	if normal.dot(outward) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	tool.set_normal(normal)
	# Godot front faces use clockwise winding (opposite the cross-product normal).
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)
	stats.triangles += 1

func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	triangle(tool,a,b,c,outward)
	triangle(tool,a,c,d,outward)

func set_shade(record: Dictionary, shade: Color) -> bool:
	var pixel: Vector2i = record.cell-bounds.position
	var color := ModularDungeonVisuals.FILL_COLOR * shade
	color.a = record.tint * 0.5
	# Keep the requested color, avoiding repeated uploads due to RGBA8 rounding.
	if record.get("palette_color",Color(-1,-1,-1,-1)) == color: return false
	record["palette_color"] = color
	palette.set_pixelv(pixel,color)
	return true

func upload_palette() -> void:
	palette_texture.update(palette)
	stats.palette_uploads += 1
