class_name TerrainOcclusion
extends RefCounted
## Floor-lifetime broad phase and shared local-space triangle BVHs.
var records: Array[Dictionary] = []
var cells: Dictionary = {}
var trees: Dictionary = {}
var active: Dictionary = {}
var signature: Array = []
var stats: Dictionary = {}
static var shared_trees: Dictionary = {}

func setup(visuals: Array[Dictionary]) -> void:
	records.clear()
	cells.clear()
	trees.clear()
	active.clear()
	signature.clear()
	for id: int in shared_trees.keys():
		if shared_trees[id].mesh.get_ref() == null: shared_trees.erase(id)
	for visual in visuals:
		if visual.stairs: continue # Exit marker/art, not an upper walkway.
		var mesh: MeshInstance3D = visual.mesh
		var id := mesh.mesh.get_instance_id()
		if not trees.has(id):
			if mesh.mesh is BoxMesh:
				# Its local AABB IS its exact solid surface. Thousands of generated
				# support boxes must not evict the expensive authored-mesh BVHs.
				trees[id] = {"solid_box": true}
			else:
				if not shared_trees.has(id):
					var faces := mesh.mesh.get_faces()
					if shared_trees.size() >= 64:
						var smallest: int = shared_trees.keys()[0]
						for cached: int in shared_trees:
							if shared_trees[cached]["size"] < shared_trees[smallest]["size"]: smallest = cached
						shared_trees.erase(smallest)
					shared_trees[id] = {"mesh": weakref(mesh.mesh), "tree": build_tree(faces), "size": faces.size()}
				trees[id] = shared_trees[id].tree
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		var index := records.size()
		records.append({"visual": visual, "tree": trees[id], "bounds": mesh.get_aabb()})
		for y in range(floori(bounds.position.z), floori(bounds.end.z) + 1):
			for x in range(floori(bounds.position.x), floori(bounds.end.x) + 1):
				var cell := Vector2i(x, y)
				if not cells.has(cell): cells[cell] = []
				cells[cell].append(index)

func invalidate() -> void:
	signature.clear()

func update(camera: Camera3D, tile: Vector2i, points: Array[Vector3], data: DungeonData) -> Array[Dictionary]:
	var context: Array = [camera.get_camera_transform(), camera.get_camera_projection(), camera.get_viewport().get_visible_rect(), tile, points]
	if signature == context: return []
	signature = context
	signature[4] = points.duplicate()
	stats = {"candidates": 0, "rays": points.size(), "blocked": 0, "triangle_tests": 0}
	var next: Dictionary = {}
	if not points.is_empty():
		var origins: Array[Vector3] = []
		var volume := AABB(points[0], Vector3.ZERO)
		for point in points:
			var origin := camera.project_ray_origin(camera.unproject_position(point))
			origins.append(origin)
			volume = volume.expand(point).expand(origin)
		volume = volume.grow(1.5)
		var candidates: Dictionary = {}
		for y in range(floori(volume.position.z), floori(volume.end.z) + 1):
			for x in range(floori(volume.position.x), floori(volume.end.x) + 1):
				for index: int in cells.get(Vector2i(x,y), []): candidates[index] = true
		var blocked: Dictionary = {}
		var eligible: Array[Dictionary] = []
		for index: int in candidates:
			var record: Dictionary = records[index]
			var visual: Dictionary = record.visual
			if not visual.fog_visible: continue
			# Preserve the floor under the feet. Neighboring ramps, landings and
			# supports may really obstruct the body and must not be blacklisted.
			if visual.tiles.has(tile) and not visual.wall and not visual.get("filler", false) and not visual.get("support", false) and data.get_tile(tile) != DungeonData.TileType.RAMP: continue
			var mesh: MeshInstance3D = visual.mesh
			record["inverse"] = mesh.global_transform.affine_inverse()
			eligible.append(record)
			stats.candidates += 1
			for ray in range(points.size()):
				if intersects(record, origins[ray], points[ray]): blocked[ray] = true
		stats.blocked = blocked.size()
		if blocked.size() > points.size() * 0.25:
			var groups: Array = [{"points": points, "origins": origins}]
			for y in range(-1, 2):
				for x in range(-1, 2):
					var neighbor := tile + Vector2i(x,y)
					if neighbor == tile or not data.is_walkable(neighbor) or not data.is_bright(neighbor): continue
					var shift := Vector3(x, (data.surface_elevation(neighbor)-data.surface_elevation(tile))*DungeonData.ELEVATION_HEIGHT, y)
					var targets: Array[Vector3] = []
					var starts: Array[Vector3] = []
					for point in points:
						targets.append(point + shift)
						starts.append(camera.project_ray_origin(camera.unproject_position(point + shift)))
					groups.append({"points": targets, "origins": starts})
			for record in eligible:
				var found := false
				for group: Dictionary in groups:
					for ray in range(points.size()):
						if intersects(record, group.origins[ray], group.points[ray]):
							found = true
							break
					if found: break
				if found: next[record.visual.mesh.get_instance_id()] = record.visual
	var changes: Array[Dictionary] = []
	for id: int in active:
		if not next.has(id):
			active[id].occluded = false
			active[id].round_occluded = false
			changes.append(active[id])
	for id: int in next:
		if not active.has(id):
			next[id].occluded = true
			next[id].round_occluded = true
			changes.append(next[id])
	active = next
	return changes

func intersects(record: Dictionary, start: Vector3, end: Vector3) -> bool:
	var a: Vector3 = record.inverse * start
	var b: Vector3 = record.inverse * end
	if record.bounds.intersects_segment(a,b) == null: return false
	if record.tree.has("solid_box"): return true
	return tree_hit(record.tree, a,b)

func tree_hit(tree: Dictionary, a: Vector3, b: Vector3) -> bool:
	if tree.is_empty() or tree.bounds.intersects_segment(a,b) == null: return false
	if tree.has("faces"):
		var faces: PackedVector3Array = tree.faces
		for index in range(0, faces.size(), 3):
			stats.triangle_tests += 1
			if Geometry3D.segment_intersects_triangle(a,b,faces[index],faces[index+1],faces[index+2]) != null: return true
		return false
	return tree_hit(tree.left,a,b) or tree_hit(tree.right,a,b)

static func build_tree(faces: PackedVector3Array) -> Dictionary:
	if faces.is_empty(): return {}
	var bounds := AABB(faces[0], Vector3.ZERO)
	for point in faces: bounds = bounds.expand(point)
	# Give planar faces nonzero bounds for robust broad-phase intersections.
	bounds = bounds.grow(0.00001)
	if faces.size() <= 24: return {"bounds": bounds, "faces": faces}
	var axis := bounds.size.max_axis_index()
	var triangles: Array = []
	for index in range(0, faces.size(),3):
		triangles.append([faces[index], faces[index+1], faces[index+2]])
	triangles.sort_custom(func(a,b): return (a[0][axis]+a[1][axis]+a[2][axis]) < (b[0][axis]+b[1][axis]+b[2][axis]))
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for index in range(triangles.size()):
		for point: Vector3 in triangles[index]:
			if index < triangles.size()/2: left.append(point)
			else: right.append(point)
	return {"bounds": bounds, "left": build_tree(left), "right": build_tree(right)}
