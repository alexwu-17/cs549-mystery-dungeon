class_name EnvironmentGeometryPlan
extends RefCounted
## Deterministic presentation contract. Never writes DungeonData or uses RNG.
const FOUNDATION = "room_foundation"
const WALKWAY = "walkway_support"
const TERRACE = "terrace"
const BOUNDARY = "boundary_filler"

static func floor_bottom() -> float:
	return DungeonData.ELEVATION_HEIGHT + 0.1 + (ModularDungeonVisuals.FLOOR.get_aabb().position.y - ModularDungeonVisuals.FLOOR_TOP) * ModularDungeonVisuals.SOURCE_SCALE * DungeonData.TILE_SIZE

static func upper_room(data: DungeonData, tile: Vector2i) -> bool:
	return data.is_walkable(tile) and data.get_elevation(tile) == 1 and data.get_room_id(tile) >= 0 and data.get_tile(tile) != DungeonData.TileType.RAMP

static func identifier(purpose: String, tile: Vector2i, layer: int = 0) -> String:
	return "%s:%d:%d:%d" % [purpose, tile.x, tile.y, layer]

static func box_record(purpose: String, cell: Vector2i, owner: Vector2i, bottom: float, top: float, layer: int = 0) -> Dictionary:
	return {"id": identifier(purpose, cell, layer), "purpose": purpose, "cell": cell, "owner": owner, "layer": layer,
		"bounds": AABB(Vector3(cell.x - 0.5, bottom, cell.y - 0.5), Vector3(DungeonData.TILE_SIZE, top - bottom, DungeonData.TILE_SIZE))}

static func required(data: DungeonData, support_height: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var top := floor_bottom()
	var layer_height := DungeonData.ELEVATION_HEIGHT / 3.0
	var walkway_height := clampf(support_height, 0.1, layer_height)
	for tile: Vector2i in data.tiles:
		if upper_room(data, tile):
			# Full columns inside the walkable footprint: no visibility-based holes.
			for layer in range(3):
				var bottom := top - DungeonData.ELEVATION_HEIGHT + layer * layer_height
				result.append(box_record(FOUNDATION, tile, tile, bottom, bottom + layer_height, layer))
		elif data.get_tile(tile) == DungeonData.TileType.CORRIDOR and data.get_elevation(tile) == 1:
			result.append(box_record(WALKWAY, tile, tile, top - walkway_height, top))
	return result

static func base_contract(data: DungeonData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tile: Vector2i in data.tiles:
		if not data.is_walkable(tile): continue
		var purpose := "ramp" if data.get_tile(tile) == DungeonData.TileType.RAMP else "floor"
		result.append({"purpose": purpose, "cell": tile, "owner": tile})
		if data.get_tile(tile) == DungeonData.TileType.STAIRS: result.append({"purpose": "stairs_marker", "cell": tile, "owner": tile})
		if purpose == "floor" and data.get_elevation(tile) == 0:
			var edges: Array[Vector2i] = []
			for direction: Vector2i in DungeonData.CARDINALS:
				if data.get_tile(tile + direction) in [DungeonData.TileType.VOID, DungeonData.TileType.WALL]: edges.append(direction)
			if not edges.is_empty(): result.append({"purpose": "wall", "cell": tile, "owner": tile, "edges": edges})
	return result

static func protection(data: DungeonData, clearance: int) -> Dictionary:
	var protected: Dictionary = {}
	for tile: Vector2i in data.tiles:
		if not data.is_walkable(tile): continue
		if data.get_elevation(tile) <= 0 or data.get_tile(tile) in [DungeonData.TileType.CORRIDOR, DungeonData.TileType.STAIRS]:
			for y in range(-clearance, clearance + 1):
				for x in range(-clearance, clearance + 1): protected[tile + Vector2i(x, y)] = true
	for segment in data.ramp_segments:
		for index in range(-1, 6):
			var tile: Vector2i = segment.lower_buffer + segment.direction * index
			for y in range(-1, 2):
				for x in range(-1, 2): protected[tile + Vector2i(x, y)] = true
	return protected

static func build(data: DungeonData, original: Dictionary, options: Dictionary, structure_only: bool = false) -> Dictionary:
	var elements := required(data, options.support_height)
	var protected := protection(data, options.clearance)
	var lower: Array[Vector2i] = []
	var upper: Dictionary = {}
	for tile: Vector2i in data.tiles:
		if upper_room(data, tile): upper[tile] = true
		if data.is_walkable(tile) and data.get_elevation(tile) <= 0: lower.append(tile)
	# Keep the existing lower dungeon backing. Ramp-height ownership and upper
	# nearest-source filler are not valid reasons to create raised stone blocks.
	for cell: Vector2i in original.cells:
		var entry: Dictionary = original.cells[cell]
		if data.get_elevation(entry.owner) != 0 or data.get_tile(entry.owner) == DungeonData.TileType.RAMP: continue
		var top := TerrainFillVisuals.wall_top_offset(0.1, float(options.get("wall_scale", 1.0)))
		var record := box_record(BOUNDARY, cell, entry.owner, float(original.base), top)
		record["distance"] = entry.distance
		record["detailed"] = entry.distance == 1
		elements.append(record)
	var retained: Dictionary = {}
	var distance: Dictionary = {}
	var owner: Dictionary = {}
	var queue: Array[Vector2i] = []
	for tile: Vector2i in upper:
		queue.append(tile)
		distance[tile] = 0
		owner[tile] = tile
	var occupied_boundary: Dictionary = {}
	for record in elements:
		if record.purpose == BOUNDARY: occupied_boundary[record.cell] = true
	var head := 0
	while not structure_only and head < queue.size():
		var tile := queue[head]
		head += 1
		var d: int = distance[tile] + 1
		if d > int(options.maximum): continue
		for direction: Vector2i in DungeonData.CARDINALS:
			var cell := tile + direction
			if distance.has(cell) or protected.has(cell) or occupied_boundary.has(cell) or data.get_tile(cell) != DungeonData.TileType.VOID or not original.bounds.has_point(cell): continue
			var jitter := int(options.irregular and d > int(options.width) and posmod(cell.x * 73856093 ^ cell.y * 19349663, 5) == 0)
			var band: int = 1 + (d - 1 + jitter) / maxi(1, int(options.width))
			var top := DungeonData.ELEVATION_HEIGHT * (1.0 - float(band) / 3.0) + 0.1
			if int(options.mode) == UpperTerrainVisuals.Mode.BOUNDED: top = DungeonData.ELEVATION_HEIGHT + 0.1
			if top <= 0.11 or UpperTerrainVisuals.camera_risk(cell, top, lower, options.pitch): continue
			# Retain only cells attached through retained predecessors. Clipping
			# cannot leave a detached outer band or a height-increasing island.
			if retained.has(tile) and float(retained[tile].bounds.end.y) < top - 0.001: continue
			var record := box_record(TERRACE, cell, owner[tile], 0.1, top)
			record["distance"] = d
			record["parent"] = tile
			retained[cell] = record
			elements.append(record)
			distance[cell] = d
			owner[cell] = owner[tile]
			queue.append(cell)
	return {"elements": elements, "surfaces": base_contract(data), "options": options.duplicate(true), "structure_only": structure_only}

static func issue(code: String, record: Dictionary) -> Dictionary:
	return {"code": code, "id": record.get("id", "?"), "cell": record.get("cell", Vector2i.ZERO), "owner": record.get("owner", Vector2i.ZERO)}

static func same_bounds(a: AABB, b: AABB) -> bool:
	return a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size)

static func validate(plan: Dictionary, data: DungeonData) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	if plan.get("surfaces", []) != base_contract(data): problems.append(issue("invalid_surface_contract", {}))
	var expected: Dictionary = {}
	for record in required(data, plan.options.support_height): expected[record.id] = record
	var seen: Dictionary = {}
	var terraces: Dictionary = {}
	var protected := protection(data, plan.options.clearance)
	var lower: Array[Vector2i] = []
	for tile: Vector2i in data.tiles:
		if data.is_walkable(tile) and data.get_elevation(tile) <= 0: lower.append(tile)
	for record in plan.elements:
		if seen.has(record.id): problems.append(issue("duplicate", record))
		seen[record.id] = true
		var bounds: AABB = record.bounds
		if bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.z <= 0: problems.append(issue("invalid_bounds", record))
		if record.purpose in [FOUNDATION, WALKWAY]:
			if not expected.has(record.id) or not same_bounds(bounds, expected[record.id].bounds) or record.owner != record.cell:
				problems.append(issue("invalid_required_support", record))
		elif record.purpose == TERRACE:
			terraces[record.cell] = record
			if not upper_room(data, record.owner) or data.get_tile(record.cell) != DungeonData.TileType.VOID or protected.has(record.cell): problems.append(issue("protected_or_orphan_terrace", record))
			if int(record.distance) < 1 or int(record.distance) > int(plan.options.maximum) or not is_equal_approx(bounds.position.y, 0.1): problems.append(issue("floating_or_unbounded_terrace", record))
			if UpperTerrainVisuals.camera_risk(record.cell, bounds.end.y, lower, plan.options.pitch): problems.append(issue("terrace_camera_conflict", record))
		elif record.purpose == BOUNDARY:
			if data.is_walkable(record.cell) or not data.is_walkable(record.owner) or data.get_elevation(record.owner) != 0 or data.get_tile(record.owner) == DungeonData.TileType.RAMP: problems.append(issue("orphan_boundary", record))
		else: problems.append(issue("unknown_purpose", record))
	for record in expected.values():
		if not seen.has(record.id): problems.append(issue("missing_required_support", record))
	for record in terraces.values():
		var parent: Vector2i = record.parent
		var delta: Vector2i = record.cell - parent
		var attached: bool = upper_room(data, parent) and parent == record.owner and int(record.distance) == 1
		if terraces.has(parent):
			var prior: Dictionary = terraces[parent]
			attached = prior.owner == record.owner and int(prior.distance) == int(record.distance) - 1 and float(prior.bounds.end.y) >= float(record.bounds.end.y) - 0.001
		if absi(delta.x) + absi(delta.y) != 1 or not attached: problems.append(issue("disconnected_terrace", record))
	return problems

static func repair(plan: Dictionary, data: DungeonData, original: Dictionary) -> Dictionary:
	var problems := validate(plan, data)
	if problems.is_empty(): return {"plan": plan, "repairs": [], "unresolved": []}
	# Recalculate from immutable topology/options, rather than guess at ownership.
	var canonical := build(data, original, plan.options, plan.get("structure_only", false))
	return {"plan": canonical, "repairs": problems, "unresolved": validate(canonical, data)}

static func inspect_instances(plan: Dictionary, data: DungeonData, visuals: Array[Dictionary]) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	var expected: Dictionary = {}
	var coverage: Dictionary = {}
	var seen: Dictionary = {}
	for record in plan.elements: expected[record.id] = record
	for visual in visuals:
		var id: String = visual.get("plan_id", "")
		if not is_instance_valid(visual.get("mesh")):
			if expected.has(id):
				problems.append(issue("missing_instance", expected[id]))
				seen[id] = true
			continue
		var mesh: MeshInstance3D = visual.mesh
		if mesh.is_queued_for_deletion():
			if expected.has(id):
				problems.append(issue("missing_instance", expected[id]))
				seen[id] = true
			continue
		if not id.is_empty():
			if not expected.has(id):
				problems.append(issue("unexpected_instance", {"id": id, "cell": visual.tiles[0]}))
				continue
			var record: Dictionary = expected[id]
			if seen.has(id): problems.append(issue("duplicate_instance", record))
			seen[id] = true
			var actual: AABB = mesh.transform * mesh.get_aabb()
			var cap_mesh: bool = record.purpose == TERRACE and plan.options.get("cave_caps", false)
			var wrong_type: bool = not mesh.mesh is BoxMesh and record.purpose != BOUNDARY and not cap_mesh
			if cap_mesh and (not mesh.mesh is ArrayMesh or mesh.mesh.get_surface_count() != 2): wrong_type = true
			if not same_bounds(actual, record.bounds) or visual.owner != record.owner or visual.purpose != record.purpose or wrong_type: problems.append(issue("misplaced_instance", record))
		elif visual.get("purpose", "") in ["floor", "ramp", "stairs_marker", "wall"]:
			for tile: Vector2i in visual.tiles:
				if not data.is_walkable(tile) or visual.owner != visual.tiles[0] or (visual.purpose == "wall" and data.get_elevation(tile) == 1):
					var invalid := issue("orphan_unplanned_instance", {"cell": tile, "owner": visual.owner})
					invalid["instance"] = mesh.get_instance_id()
					problems.append(invalid)
					continue
				if visual.purpose == "floor":
					var surface: AABB = mesh.transform * mesh.get_aabb()
					if not is_equal_approx(surface.end.y, data.get_elevation(tile) * DungeonData.ELEVATION_HEIGHT + 0.1): problems.append(issue("misplaced_floor_surface", {"cell": tile, "owner": tile}))
				coverage["%s:%s" % [visual.purpose, tile]] = true
		else:
			var invalid := issue("orphan_unplanned_instance", {"cell": visual.tiles[0], "owner": visual.get("owner", Vector2i.ZERO)})
			invalid["instance"] = mesh.get_instance_id()
			problems.append(invalid)
	for record in plan.elements:
		if not seen.has(record.id): problems.append(issue("missing_instance", record))
	for record in base_contract(data):
		if not coverage.has("%s:%s" % [record.purpose, record.cell]): problems.append(issue("missing_" + str(record.purpose), record))
	return problems
