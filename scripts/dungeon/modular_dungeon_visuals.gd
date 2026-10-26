class_name ModularDungeonVisuals
extends RefCounted
## Source assets stay unchanged; split surfaces are shared between tile instances.
const FLOOR: Mesh = preload("res://assets/environment/modular_dungeon/floor.obj")
const FLOOR_WALL: Mesh = preload("res://assets/environment/modular_dungeon/floor_wall.obj")
const CORNER: Mesh = preload("res://assets/environment/modular_dungeon/floor_corner.obj")
const WALL: Mesh = preload("res://assets/environment/modular_dungeon/wall.obj")
const RAMP: Mesh = preload("res://assets/environment/modular_dungeon/up_stairs.obj")
const SOURCE_SCALE: float = 0.5
const FLOOR_TOP: float = 0.217668
const FLOOR_COLOR: Color = Color("#C5BA9C")
const WALL_COLOR: Color = Color("#848590")
const FILL_COLOR: Color = Color("#6A6D78")
static var surfaces: Dictionary = {}
static var fog_materials: Dictionary = {}
static var tread_heights: Dictionary = {}
static var ramp_meshes: Dictionary = {}

static func ramp_mesh(tile_count: int, seal_seams: bool = true) -> ArrayMesh:
	var key := Vector2i(tile_count, int(seal_seams))
	if not ramp_meshes.has(key):
		var mesh := ArrayMesh.new()
		var bounds := RAMP.get_aabb()
		var rise := DungeonData.ELEVATION_HEIGHT / tile_count
		var scale := Vector3(DungeonData.TILE_SIZE / bounds.size.x, rise / bounds.size.y, DungeonData.TILE_SIZE / bounds.size.z)
		var normal_basis := Basis.from_scale(scale).inverse().transposed()
		# One complete staircase per tile, stepped upward along canonical +X.
		# Shared mesh keeps fog/occlusion operating on the complete transition.
		for tile in range(tile_count):
			for surface in range(RAMP.get_surface_count()):
				var arrays := RAMP.surface_get_arrays(surface).duplicate(true)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				for index in range(vertices.size()):
					vertices[index] = (vertices[index] - Vector3(bounds.position.x, bounds.position.y, bounds.get_center().z)) * scale + Vector3(tile * DungeonData.TILE_SIZE, tile * rise, 0)
					if not normals.is_empty(): normals[index] = (normal_basis * normals[index]).normalized()
				for index in range(0, tangents.size(), 4):
					var tangent := (Vector3(tangents[index], tangents[index + 1], tangents[index + 2]) * scale).normalized()
					tangents[index] = tangent.x
					tangents[index + 1] = tangent.y
					tangents[index + 2] = tangent.z
				arrays[Mesh.ARRAY_VERTEX] = vertices
				arrays[Mesh.ARRAY_NORMAL] = normals
				arrays[Mesh.ARRAY_TANGENT] = tangents
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.surface_set_material(mesh.get_surface_count() - 1, RAMP.surface_get_material(surface))
		if seal_seams:
			# Continuous masonry below the four authored treads in each copy.
			# Adjacent columns share faces and close recessed/beveled model ends.
			var backing := SurfaceTool.new()
			backing.begin(Mesh.PRIMITIVE_TRIANGLES)
			var steps := tile_count * 4
			var run := DungeonData.TILE_SIZE / 4.0
			var bottom := -0.16 * DungeonData.TILE_SIZE
			for step in range(steps):
				var top := (step + 1) * rise / 4.0 - minf(0.06 * rise, 0.04 * DungeonData.TILE_SIZE)
				if step == steps - 1: top = DungeonData.ELEVATION_HEIGHT - 0.02 * DungeonData.TILE_SIZE
				var block := BoxMesh.new()
				block.size = Vector3(run, top - bottom, DungeonData.TILE_SIZE)
				backing.append_from(block, 0, Transform3D(Basis.IDENTITY, Vector3((step + 0.5) * run, (top + bottom) / 2.0, 0)))
			backing.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, RAMP.surface_get_material(0))
		ramp_meshes[key] = mesh
	return ramp_meshes[key]

static func tread_fraction(index: int, tile_count: int) -> float:
	# Sample actual tread centers once per footprint, without physics bodies.
	var key := Vector2i(index, tile_count)
	if not tread_heights.has(key):
		var bounds := RAMP.get_aabb()
		var x := bounds.position.x + bounds.size.x * (index + 0.5) / tile_count
		var origin := Vector3(x, bounds.end.y + 1.0, bounds.get_center().z)
		var height := bounds.position.y
		var faces := RAMP.get_faces()
		for triangle in range(0, faces.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN, faces[triangle], faces[triangle + 1], faces[triangle + 2])
			if hit != null: height = maxf(height, hit.y)
		tread_heights[key] = (height - bounds.position.y) / bounds.size.y
	return tread_heights[key]


static func surface_mesh(source: Mesh, index: int) -> ArrayMesh:
	var key := "%s:%d" % [source.get_instance_id(), index]
	if not surfaces.has(key):
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(index))
		mesh.surface_set_material(0, source.surface_get_material(index))
		surfaces[key] = mesh
	return surfaces[key]

static func materials(source: Material, dim: Color, other: Color, albedo: Color) -> Array[Material]:
	var key := "%s:%s:%s:%s" % [source.get_instance_id() if source != null else 0, dim, other, albedo]
	if not fog_materials.has(key):
		var bright: StandardMaterial3D = source.duplicate() if source is StandardMaterial3D else StandardMaterial3D.new()
		bright.albedo_color = albedo
		var dark: StandardMaterial3D = bright.duplicate()
		dark.albedo_color = bright.albedo_color * dim
		var distant: StandardMaterial3D = bright.duplicate()
		distant.albedo_color = bright.albedo_color * other
		fog_materials[key] = [bright, dark, distant]
	var result: Array[Material] = []
	result.assign(fog_materials[key])
	return result
