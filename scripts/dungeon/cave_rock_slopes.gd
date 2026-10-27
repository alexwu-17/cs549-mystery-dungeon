class_name CaveRockSlopes
extends RefCounted
## Shared decorative corner heights. Required foundation/bridge volumes stay intact.
const OFFSETS = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]

static func prepare(data: DungeonData, elements: Array, renderer: DungeonRenderer) -> Dictionary:
	var covered: Dictionary = {}
	for record in elements:
		if record.purpose in [EnvironmentGeometryPlan.BOUNDARY, EnvironmentGeometryPlan.TERRACE]: covered[record.cell] = record
	var planned := CaveTerrainBackdrop.plan(data, covered, renderer.floor_visual_seed, renderer.cave_ground_blending_enabled, renderer.cave_ground_height_variation_enabled, renderer.cave_scenery_border_width)
	var protected := EnvironmentGeometryPlan.protection(data, renderer.terrace_protected_clearance)
	var lower: Array[Vector2i] = []
	var pitch := float(renderer.geometry_plan.get("options",{}).get("pitch",35.0))
	var field: Dictionary = {}
	for tile: Vector2i in data.tiles:
		if not data.is_walkable(tile): continue
		if data.get_elevation(tile) <= 0: lower.append(tile)
		if EnvironmentGeometryPlan.upper_room(data,tile): field[tile] = {"top": EnvironmentGeometryPlan.floor_bottom(), "mutable": false}
	for record in planned.records:
		field[record.cell] = {"top": record.top, "mutable": not record.underlay and not protected.has(record.cell) and (record.varied or record.structural)}
	for record in covered.values():
		var enabled: bool = (record.purpose == EnvironmentGeometryPlan.TERRACE and renderer.upper_terrain_mode == UpperTerrainVisuals.Mode.TERRACES) or record.get("ground_variation",false)
		field[record.cell] = {"top": record.bounds.end.y, "mutable": enabled and not protected.has(record.cell)}
	# Freeze the safety decision before constructing any profile, so traversal
	# order cannot affect joins. Never raise terrain into lower-path sight stripes.
	for cell: Vector2i in field:
		if not field[cell].mutable: continue
		var maximum: float = field[cell].top
		for offset in OFFSETS: maximum = maxf(maximum,target_corner(cell+offset,field))
		if UpperTerrainVisuals.camera_risk(cell,maximum,lower,pitch): field[cell].mutable = false
	var ground: Dictionary = {}
	for record in planned.records:
		if not covered.has(record.cell) and field[record.cell].mutable: ground[record.cell] = corners(record.cell,field)
	var changed := 0
	for record in covered.values():
		if not field[record.cell].mutable: continue
		var points := corners(record.cell,field)
		var maximum: float = record.bounds.end.y
		var minimum := maximum
		for point in points:
			maximum = maxf(maximum,point.y)
			minimum = minf(minimum,point.y)
		if maximum-minimum < 0.001: continue
		record["nominal_bounds"] = record.bounds
		record["rock_profile"] = points
		record.bounds.size.y = maximum-record.bounds.position.y
		changed += 1
	return {"ground": ground, "planned_slopes": changed}

static func target_corner(corner: Vector2i, field: Dictionary) -> float:
	var height := -INF
	for offset in [Vector2i(-1,-1), Vector2i(0,-1), Vector2i.ZERO, Vector2i(-1,0)]:
		var cell: Vector2i = corner+offset
		if field.has(cell): height = maxf(height,field[cell].top)
	return height

static func corners(cell: Vector2i, field: Dictionary) -> PackedVector3Array:
	var points := PackedVector3Array()
	for offset in OFFSETS:
		var corner: Vector2i = cell+offset
		points.append(Vector3(corner.x-0.5,target_corner(corner,field),corner.y-0.5))
	return points

static func mesh(record: Dictionary) -> ArrayMesh:
	var result := ArrayMesh.new()
	var sides := SurfaceTool.new()
	var cap := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	var top: float = record.bounds.end.y
	var bottom: float = record.bounds.position.y-top
	for point in record.rock_profile:
		points.append(point-Vector3(record.cell.x,top,record.cell.y))
	var center := Vector3.ZERO
	for point in points: center += point*0.25
	for edge in range(4):
		var next := (edge+1)%4
		emit(cap,center,points[edge],points[next],Vector3.UP)
		var a := points[edge]
		var b := points[next]
		var direction: Vector2i = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][edge]
		var outward := Vector3(direction.x,0,direction.y)
		emit(sides,a,b,Vector3(b.x,bottom,b.z),outward)
		emit(sides,a,Vector3(b.x,bottom,b.z),Vector3(a.x,bottom,a.z),outward)
	sides.commit(result)
	cap.commit(result)
	result.surface_set_material(0,TerrainFillVisuals.material())
	result.surface_set_material(1,TerrainFillVisuals.material())
	return result

static func shape_key(record: Dictionary) -> Array:
	# Local shape only: repeated slopes can share meshes and render batching.
	var key: Array = [record.bounds.size.y]
	for point in record.rock_profile: key.append(point.y-record.bounds.end.y)
	return key

static func emit(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot(outward) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)
