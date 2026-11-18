class_name OutOfBoundsScenery
extends Node3D
## Decorative ridge, tree and bush models beyond the logical map. Rendering only:
## no tiles, elevations, spawns, traversal or generator RNG are read for placement
## choices other than coordinate hashing. Chunked MultiMesh batches, no per-cell nodes.

const MODELS: Array[Mesh] = [
	preload("res://assets/environment/out_of_bounds/oob_1.obj"),
	preload("res://assets/environment/out_of_bounds/oob_2.obj"),
	preload("res://assets/environment/out_of_bounds/oob_3.obj"),
]
const SHADER = preload("res://shaders/out_of_bounds_spring.gdshader")
const TREE: Mesh = preload("res://assets/environment/out_of_bounds/vegetation/tree/tree.obj")
const BUSH: Mesh = preload("res://assets/environment/out_of_bounds/vegetation/bush/bush.obj")
const VEGETATION_SHADER = preload("res://shaders/out_of_bounds_vegetation.gdshader")
## Candidate ground points per ridge model: the top vertex nearest each interior
## cell center of this grid (border cells hold the ridge side walls).
const SURFACE_GRID := 6
## Vegetation bases sit slightly inside the ridge so trunks never float.
const SINK := 0.08
const BUSH_HEIGHT_SHARE := 0.3
const CANOPY_GREENS: Array[Color] = [Color(0.42, 0.70, 0.34), Color(0.36, 0.62, 0.30), Color(0.50, 0.74, 0.38)]
const BUSH_GREENS: Array[Color] = [Color(0.30, 0.56, 0.30), Color(0.36, 0.63, 0.33), Color(0.42, 0.66, 0.36)]
const BLOSSOM := Color(0.96, 0.74, 0.84)
const TRUNK_COLOR := Color(0.42, 0.29, 0.20)
static var _surface_points: Dictionary = {}
const NEAR_FOOTPRINT := 2
const FAR_FOOTPRINT := 4
const CHUNK_SIZE := 16
var batches: Array[MultiMeshInstance3D] = []
var material: ShaderMaterial
var placements: Array[Dictionary] = []
var diagnostics := {"near": 0, "far": 0, "triangles": 0, "mesh_nodes": 0, "trees": 0, "bushes": 0, "vegetation_triangles": 0}
var vegetation: Array[Dictionary] = []
var vegetation_batches: Array[MultiMeshInstance3D] = []
var vegetation_materials: Array[ShaderMaterial] = []
var vegetation_meshes: Dictionary = {}
var shade_lift: float = 0.0
var _shade := Color.WHITE


func setup(data: DungeonData, backdrop: CaveTerrainBackdrop, renderer: DungeonRenderer) -> void:
	set_meta("geometry_purpose", "out_of_bounds_scenery")
	shade_lift = renderer.out_of_bounds_shade_lift
	material = ShaderMaterial.new()
	material.shader = SHADER
	var tops: Dictionary = {}
	for record in backdrop.records:
		if record.external: tops[record.cell] = float(record.top)
	var detailed: Rect2i = backdrop.get_meta("geometry_bounds")
	var outer: Rect2i = backdrop.scenery_apron.visual_bounds if is_instance_valid(backdrop.scenery_apron) else detailed
	# The apron guard follows the camera and can be very large; instance counts must not.
	outer = outer.intersection(detailed.grow(renderer.out_of_bounds_far_extent))
	var apron_top := TerrainFillVisuals.wall_top_offset(0.1, 0.5)
	# Near band: every whole 2x2 block of detailed external cells. Far band: 4x4
	# blocks over the apron, thinned by hash so the horizon stays irregular.
	_plan_band(detailed, data.map_bounds, data.map_bounds, NEAR_FOOTPRINT, 1.0, tops, apron_top, renderer, false)
	_plan_band(outer, detailed, data.map_bounds, FAR_FOOTPRINT, renderer.out_of_bounds_far_density, tops, apron_top, renderer, true)
	# One MultiMesh per (spatial chunk, model): a map-wide MultiMesh cannot be
	# frustum-culled, so distant off-screen ridges would always be drawn.
	var groups: Dictionary = {}
	for index in range(placements.size()):
		var block: Rect2i = placements[index].block
		var key := Vector3i(floori(float(block.position.x) / CHUNK_SIZE), floori(float(block.position.y) / CHUNK_SIZE), placements[index].model)
		if not groups.has(key): groups[key] = []
		groups[key].append(index)
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var node := MultiMeshInstance3D.new()
		node.name = "OutOfBoundsRidges_%d_%d_m%d" % [key.x, key.y, key.z + 1]
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = MODELS[key.z]
		node.multimesh.instance_count = groups[key].size()
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("geometry_purpose", "out_of_bounds_scenery")
		add_child(node)
		batches.append(node)
		for local_index in range(groups[key].size()):
			var index: int = groups[key][local_index]
			node.multimesh.set_instance_transform(local_index, placements[index].transform)
			placements[index]["batch"] = batches.size() - 1
			placements[index]["instance"] = local_index
			diagnostics.triangles += MODELS[key.z].get_faces().size() / 3
	if renderer.out_of_bounds_vegetation_enabled:
		_plan_vegetation(data.map_bounds, renderer)
		_build_vegetation()
	diagnostics.mesh_nodes = batches.size() + vegetation_batches.size()
	set_meta("geometry_bounds", outer)


## Source-space top-surface points of a ridge model, lowest first. Pure function
## of the immutable imported mesh, so it is cached for the session.
static func surface_points(model: int) -> Array[Vector3]:
	if not _surface_points.has(model):
		var mesh := MODELS[model]
		var aabb := mesh.get_aabb()
		var best: Dictionary = {}
		for surface in range(mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if vertex.y <= aabb.position.y + 0.02: continue # Base slab.
				var u := (vertex.x - aabb.position.x) / aabb.size.x
				var v := (vertex.z - aabb.position.z) / aabb.size.z
				var cell := Vector2i(clampi(floori(u * SURFACE_GRID), 0, SURFACE_GRID - 1), clampi(floori(v * SURFACE_GRID), 0, SURFACE_GRID - 1))
				if cell.x == 0 or cell.y == 0 or cell.x == SURFACE_GRID - 1 or cell.y == SURFACE_GRID - 1: continue
				var center := Vector2(aabb.position.x + (cell.x + 0.5) / SURFACE_GRID * aabb.size.x, aabb.position.z + (cell.y + 0.5) / SURFACE_GRID * aabb.size.z)
				var distance := Vector2(vertex.x, vertex.z).distance_squared_to(center)
				if not best.has(cell) or distance < float(best[cell].distance):
					best[cell] = {"distance": distance, "point": vertex}
		var points: Array[Vector3] = []
		for cell in best: points.append(best[cell].point)
		points.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y or (a.y == b.y and (a.x < b.x or (a.x == b.x and a.z < b.z))))
		_surface_points[model] = points
	return _surface_points[model]


static func _mix(value: int, salt: int) -> int:
	var x := posmod(value ^ (salt * 73244475 + 0x2545F491), 2147483647)
	x = posmod((x ^ (x >> 16)) * 73244475, 2147483647)
	return posmod(x ^ (x >> 15), 2147483647)


static func _unit(value: int, salt: int) -> float:
	return float(_mix(value, salt) % 10000) / 10000.0


## Tinkercad exports are Z-up millimetres; this turns source +Z into Godot +Y.
static func z_up_basis() -> Basis:
	return Basis(Vector3.RIGHT, -PI / 2.0)


static func vegetation_base(mesh: Mesh) -> Vector3:
	var aabb := mesh.get_aabb()
	return Vector3(aabb.get_center().x, aabb.get_center().y, aabb.position.z)


static func vegetation_radius(mesh: Mesh, scale: float) -> float:
	var aabb := mesh.get_aabb()
	return 0.5 * maxf(aabb.size.x, aabb.size.y) * scale


func _plan_vegetation(map_bounds: Rect2i, renderer: DungeonRenderer) -> void:
	# Trees on both bands, bushes on the near band only. Items sit on the lower
	# half of each ridge's surface points (valleys and saddles) and keep their
	# whole canopy outside the logical map rectangle.
	var map_rect := Rect2(Vector2(map_bounds.position) - Vector2.ONE * 0.5, Vector2(map_bounds.size))
	for placement in placements:
		var block: Rect2i = placement.block
		var points := surface_points(placement.model)
		var low := maxi(1, points.size() / 2)
		var hash_value := renderer.floor_hash(block.position + Vector2i(15485863, 32452843))
		var kinds: Array[String] = []
		if _unit(hash_value, 1) < renderer.out_of_bounds_tree_density: kinds.append("tree")
		if not placement.far:
			if _unit(hash_value, 2) < renderer.out_of_bounds_bush_density: kinds.append("bush")
			if _unit(hash_value, 3) < renderer.out_of_bounds_bush_density * 0.4: kinds.append("bush")
		var used: Dictionary = {}
		for index in range(kinds.size()):
			var kind := kinds[index]
			var mesh: Mesh = TREE if kind == "tree" else BUSH
			var target: float = renderer.out_of_bounds_tree_height * (1.0 if kind == "tree" else BUSH_HEIGHT_SHARE)
			var height := target * lerpf(0.8, 1.2, _unit(hash_value, 10 + index))
			var scale := height / mesh.get_aabb().size.z
			var radius := vegetation_radius(mesh, scale)
			var start := _mix(hash_value, 20 + index) % low
			for attempt in range(low):
				var pick := (start + attempt) % low
				if used.has(pick): continue
				var point: Vector3 = placement.transform * points[pick]
				var flat := Vector2(point.x, point.z)
				var gap := Vector2(maxf(maxf(map_rect.position.x - flat.x, flat.x - map_rect.end.x), 0.0), maxf(maxf(map_rect.position.y - flat.y, flat.y - map_rect.end.y), 0.0)).length()
				if gap < radius: continue
				used[pick] = true
				var yaw := _unit(hash_value, 30 + index) * TAU
				var basis := (Basis(Vector3.UP, yaw) * z_up_basis()).scaled(Vector3.ONE * scale)
				var origin := point - basis * vegetation_base(mesh) - Vector3.UP * SINK
				var color: Color
				if kind == "tree" and _unit(hash_value, 40 + index) < renderer.out_of_bounds_blossom_ratio: color = BLOSSOM
				else:
					var palette: Array[Color] = CANOPY_GREENS if kind == "tree" else BUSH_GREENS
					color = palette[_mix(hash_value, 50 + index) % palette.size()]
				vegetation.append({"kind": kind, "block": block, "transform": Transform3D(basis, origin), "point": point, "height": height, "radius": radius, "color": color, "far": placement.far, "ground": placement.top})
				if kind == "tree": diagnostics.trees += 1
				else: diagnostics.bushes += 1
				break


func _vegetation_mesh(kind: String) -> ArrayMesh:
	if vegetation_meshes.has(kind): return vegetation_meshes[kind]
	# Duplicate keeps generated LODs; the imported resource's materials stay untouched.
	var source: Mesh = TREE if kind == "tree" else BUSH
	var mesh: ArrayMesh = source.duplicate()
	var trunk := -1
	if mesh.get_surface_count() > 1:
		var lowest := INF
		for surface in range(mesh.get_surface_count()):
			var top := -INF
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices: top = maxf(top, vertex.z)
			if top < lowest:
				lowest = top
				trunk = surface
	for surface in range(mesh.get_surface_count()):
		var surface_material := ShaderMaterial.new()
		surface_material.shader = VEGETATION_SHADER
		surface_material.set_shader_parameter("use_instance_color", surface != trunk)
		surface_material.set_shader_parameter("base_color", Vector3(TRUNK_COLOR.r, TRUNK_COLOR.g, TRUNK_COLOR.b))
		mesh.surface_set_material(surface, surface_material)
		vegetation_materials.append(surface_material)
	vegetation_meshes[kind] = mesh
	return mesh


func _build_vegetation() -> void:
	var groups: Dictionary = {}
	for index in range(vegetation.size()):
		var block: Rect2i = vegetation[index].block
		var key := Vector3i(floori(float(block.position.x) / CHUNK_SIZE), floori(float(block.position.y) / CHUNK_SIZE), 0 if vegetation[index].kind == "tree" else 1)
		if not groups.has(key): groups[key] = []
		groups[key].append(index)
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var kind := "tree" if key.z == 0 else "bush"
		var mesh := _vegetation_mesh(kind)
		var node := MultiMeshInstance3D.new()
		node.name = "OutOfBounds%s_%d_%d" % ["Trees" if key.z == 0 else "Bushes", key.x, key.y]
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.use_colors = true
		node.multimesh.mesh = mesh
		node.multimesh.instance_count = groups[key].size()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("geometry_purpose", "out_of_bounds_vegetation")
		add_child(node)
		vegetation_batches.append(node)
		for local_index in range(groups[key].size()):
			var index: int = groups[key][local_index]
			node.multimesh.set_instance_transform(local_index, vegetation[index].transform)
			# Canopy colors are authored in sRGB; the shader reads them as linear albedo.
			node.multimesh.set_instance_color(local_index, Color(vegetation[index].color).srgb_to_linear())
			vegetation[index]["batch"] = vegetation_batches.size() - 1
			vegetation[index]["instance"] = local_index
			diagnostics.vegetation_triangles += mesh.get_faces().size() / 3


func _plan_band(bounds: Rect2i, excluded: Rect2i, map_bounds: Rect2i, footprint: int, density: float, tops: Dictionary, apron_top: float, renderer: DungeonRenderer, far: bool) -> void:
	# Align the block grid to the excluded rectangle so blocks sit flush against it;
	# blocks that would straddle it or leave the band are skipped.
	var offset := excluded.position - bounds.position
	var start := excluded.position - Vector2i((offset.x + footprint - 1) / footprint, (offset.y + footprint - 1) / footprint) * footprint
	var y := start.y
	while y + footprint <= bounds.end.y:
		var x := start.x
		while x + footprint <= bounds.end.x:
			var block := Rect2i(x, y, footprint, footprint)
			x += footprint
			if block.intersects(excluded) or not bounds.encloses(block): continue
			# The fixed camera looks north from south of the player. Ridges south of
			# the map would stand between the camera and the play area, so the
			# foreground band stays flat ground.
			if renderer.out_of_bounds_foreground_clear and block.end.y > map_bounds.end.y: continue
			var hash_value := renderer.floor_hash(block.position + Vector2i(7919, 104729) * footprint)
			if density < 1.0 and float(posmod(hash_value / 64, 1000)) / 1000.0 >= density: continue
			var top := apron_top
			for cy in range(block.position.y, block.end.y):
				for cx in range(block.position.x, block.end.x):
					top = maxf(top, float(tops.get(Vector2i(cx, cy), apron_top)))
			var model := posmod(hash_value, MODELS.size())
			var quarter_turns := posmod(hash_value / 4, 4)
			var aabb := MODELS[model].get_aabb()
			var scale := float(footprint) * DungeonData.TILE_SIZE / maxf(aabb.size.x, aabb.size.z)
			var basis := Basis(Vector3.UP, quarter_turns * PI / 2.0).scaled(Vector3(scale, scale * renderer.out_of_bounds_height_scale, scale))
			var center := Vector3(block.position.x + (footprint - 1) * 0.5, top, block.position.y + (footprint - 1) * 0.5)
			# Center the authored mesh on its block and rest its lowest vertex on the ground top.
			var local_center := Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
			var transform := Transform3D(basis, center - basis * local_center)
			placements.append({"block": block, "model": model, "transform": transform, "far": far, "top": top})
			if far: diagnostics.far += 1
			else: diagnostics.near += 1
		y += footprint


func apply_shade(shade: Color) -> void:
	if material == null: return
	# Distant ridges are sky-lit: lift the border palette toward white by a fixed share.
	_shade = shade.lerp(Color.WHITE, shade_lift)
	_shade.a = 1.0
	material.set_shader_parameter("fog_shade", Vector3(_shade.r, _shade.g, _shade.b))
	for vegetation_material in vegetation_materials:
		vegetation_material.set_shader_parameter("fog_shade", Vector3(_shade.r, _shade.g, _shade.b))


func current_shade() -> Color:
	return _shade
