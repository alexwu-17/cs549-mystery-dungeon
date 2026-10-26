class_name CaveTerrainBackdrop
extends Node3D
## Spatially grouped instances, never one node per empty cell or navigation.
var records: Array[Dictionary] = []
var diagnostics: Dictionary = {}
var caps: MultiMeshInstance3D
var bodies: MultiMeshInstance3D
var batches: Array[Dictionary] = []
var scenery_apron: CaveSceneryApron
var _interior_indices: Array[int] = []
var _all_indices: Array[int] = []
var _border_shade := Color(-1,-1,-1,1)
const GROUND_BASE := -1.0

static func ground_rules(data: DungeonData, covered: Dictionary, visual_bounds: Rect2i = Rect2i()) -> Dictionary:
	var bounds := visual_bounds if visual_bounds.has_area() else data.map_bounds
	var protected: Dictionary = {}
	var distance: Dictionary = {}
	var structure: Dictionary = {}
	var queue: Array[Vector2i] = []
	for segment in data.ramp_segments:
		for index in range(-1, 6):
			var tile: Vector2i = segment.lower_buffer + segment.direction * index
			for y in range(-1, 2):
				for x in range(-1, 2): protected[tile + Vector2i(x, y)] = true
	for tile: Vector2i in data.tiles:
		if not data.is_walkable(tile): continue
		distance[tile] = 0
		queue.append(tile)
		if EnvironmentGeometryPlan.upper_room(data, tile):
			structure[tile] = EnvironmentGeometryPlan.floor_bottom() - DungeonData.ELEVATION_HEIGHT
		if data.get_tile(tile) == DungeonData.TileType.CORRIDOR and data.get_elevation(tile) == 1:
			for y in range(-1, 2):
				for x in range(-1, 2): protected[tile + Vector2i(x, y)] = true
	for cell in covered:
		var record: Variant = covered[cell]
		if record is Dictionary and record.get("purpose", "") == EnvironmentGeometryPlan.TERRACE:
			structure[cell] = record.bounds.position.y
	var head := 0
	while head < queue.size():
		var tile: Vector2i = queue[head]
		head += 1
		for direction in DungeonData.CARDINALS:
			var next: Vector2i = tile + direction
			if not bounds.has_point(next) or distance.has(next): continue
			distance[next] = int(distance[tile]) + 1
			queue.append(next)
	return {"protected": protected, "distance": distance, "structure": structure}

static func near_structure(cell: Vector2i, structure: Dictionary) -> bool:
	for y in range(-1, 2):
		for x in range(-1, 2):
			if structure.has(cell + Vector2i(x,y)): return true
	return false

static func can_vary(cell: Vector2i, rules: Dictionary) -> bool:
	return int(rules.distance.get(cell, 0)) > 2 and not rules.protected.has(cell) and not near_structure(cell, rules.structure)

static func varied_top(cell: Vector2i, visual_seed: int) -> float:
	# Independent salted coordinate hash: no generator/turn RNG consumption.
	var value := posmod(cell.x * 73856093 ^ cell.y * 19349663 ^ posmod(visual_seed, 1000000) * 83492791 ^ 0x5bd1e995, 2147483647)
	value = posmod((value ^ (value >> 13)) * 1274126177, 2147483647)
	var scale := 1.0 if posmod(value ^ (value >> 16), 10) < 4 else 0.5
	return TerrainFillVisuals.wall_top_offset(0.1, scale)

static func refine_boundaries(data: DungeonData, elements: Array, visual_seed: int, variation: bool) -> void:
	if not variation: return
	var covered: Dictionary = {}
	for record in elements:
		if record.purpose in [EnvironmentGeometryPlan.BOUNDARY, EnvironmentGeometryPlan.TERRACE]: covered[record.cell] = record
	var rules := ground_rules(data, covered)
	for record in elements:
		if record.purpose != EnvironmentGeometryPlan.BOUNDARY or not data.map_bounds.has_point(record.cell) or not can_vary(record.cell, rules): continue
		# Keep ownership/terrace reservations; only distant decorative bounds change.
		var top := varied_top(record.cell, visual_seed)
		record.bounds.position.y = GROUND_BASE
		record.bounds.size.y = top - GROUND_BASE
		record["ground_variation"] = true

static func plan(data: DungeonData, covered: Dictionary, visual_seed: int = 0, blending: bool = true, variation: bool = true, border_width: int = 0) -> Dictionary:
	var records: Array[Dictionary] = []
	var visual_bounds := data.map_bounds.grow(maxi(0,border_width))
	var rules := ground_rules(data, covered, visual_bounds)
	var stats := {"nonwalkable": 0, "existing_terrain": 0, "protected_voids": 0, "background_cells": 0, "underlays": 0, "blended": 0, "varied_full": 0, "varied_half": 0, "mesh_nodes": 0, "violations": []}
	stats["border_cells"] = 0
	for y in range(visual_bounds.position.y, visual_bounds.end.y):
		for x in range(visual_bounds.position.x, visual_bounds.end.x):
			var tile := Vector2i(x, y)
			var external := not data.map_bounds.has_point(tile)
			var walkable := data.is_walkable(tile)
			var underlay := walkable and (data.get_tile(tile) == DungeonData.TileType.RAMP or (data.get_tile(tile) == DungeonData.TileType.CORRIDOR and data.get_elevation(tile) == 1))
			if walkable and not underlay: continue
			if not walkable and not external: stats.nonwalkable += 1
			var terrace_base := 0.0
			if covered.has(tile):
				var existing: Variant = covered[tile]
				if existing is Dictionary and existing.get("purpose", "") == EnvironmentGeometryPlan.TERRACE:
					terrace_base = existing.bounds.position.y
				else:
					if not external: stats.existing_terrain += 1
					continue
			var top := 0.0
			var structural := near_structure(tile, rules.structure)
			if blending:
				top = maxf(top, terrace_base)
				if not rules.protected.has(tile):
					for direction in DungeonData.CARDINALS:
						top = maxf(top, float(rules.structure.get(tile + direction, 0.0)))
			var varied := variation and not underlay and can_vary(tile, rules)
			if varied:
				top = varied_top(tile, visual_seed)
				if is_equal_approx(top, TerrainFillVisuals.wall_top_offset(0.1, 1.0)): stats.varied_full += 1
				else: stats.varied_half += 1
			if not varied and top > 0.0: stats.blended += 1
			if external: stats.border_cells += 1
			elif underlay: stats.underlays += 1
			else: stats.background_cells += 1
			var owner := tile
			var adjacent := false
			for direction: Vector2i in DungeonData.CARDINALS:
				if not external and data.is_walkable(tile + direction):
					owner = tile + direction
					adjacent = true
					break
			records.append({"cell": tile, "owner": owner, "adjacent": adjacent, "purpose": "cave_background", "top": top, "bottom": GROUND_BASE, "underlay": underlay, "structural": structural, "varied": varied, "external": external})
	return {"records": records, "diagnostics": stats, "visual_bounds": visual_bounds}

func batch(mesh: Mesh, material: StandardMaterial3D, count: int) -> MultiMeshInstance3D:
	var result := MultiMeshInstance3D.new()
	result.multimesh = MultiMesh.new()
	result.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	result.multimesh.use_colors = true
	result.multimesh.mesh = mesh
	result.multimesh.instance_count = count
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	result.material_override = material
	# Protected ground stays below traversal surfaces; distant decorative blocks
	# retain the backing's receive-only shadows, with no new shadow-map workload.
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result)
	return result

func setup(data: DungeonData, covered: Dictionary, renderer: DungeonRenderer) -> void:
	var planned := plan(data, covered, renderer.floor_visual_seed, renderer.cave_ground_blending_enabled, renderer.cave_ground_height_variation_enabled, renderer.cave_scenery_border_width)
	records = planned.records
	diagnostics = planned.diagnostics
	set_meta("geometry_purpose", "bounded_cave_background")
	set_meta("geometry_bounds", planned.visual_bounds)
	if records.is_empty(): return
	var body := BoxMesh.new()
	body.size = Vector3.ONE
	var side_material: StandardMaterial3D = TerrainFillVisuals.material().duplicate()
	var top_material: StandardMaterial3D = TerrainFillVisuals.material().duplicate()
	# A single map-wide MultiMesh cannot cull distant instances. Small spatial
	# groups retain batching while avoiding unnecessary off-screen model detail.
	var groups: Dictionary = {}
	for index in range(records.size()):
		_all_indices.append(index)
		if not records[index].external: _interior_indices.append(index)
		var tile: Vector2i = records[index].cell
		var chunk := Vector2i(floori(float(tile.x) / renderer.cave_batch_chunk_size), floori(float(tile.y) / renderer.cave_batch_chunk_size))
		if not groups.has(chunk): groups[chunk] = []
		groups[chunk].append(index)
	for chunk in groups:
		var cap_group := batch(ModularDungeonVisuals.FLOOR, top_material, groups[chunk].size())
		var body_group := batch(body, side_material, groups[chunk].size())
		cap_group.name = "CaveCaps_%d_%d" % [chunk.x, chunk.y]
		body_group.name = "CaveSides_%d_%d" % [chunk.x, chunk.y]
		batches.append({"caps": cap_group, "bodies": body_group, "chunk": chunk})
		for local_index in range(groups[chunk].size()):
			var index: int = groups[chunk][local_index]
			records[index]["batch"] = batches.size() - 1
			records[index]["instance"] = local_index
	caps = batches[0].caps
	bodies = batches[0].bodies
	for index in range(records.size()):
		var tile: Vector2i = records[index].cell
		var hash_value := renderer.floor_hash(tile)
		var angle := float(posmod(hash_value, 4)) * PI / 2.0 if renderer.cave_ceiling_variation_enabled else 0.0
		var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * ModularDungeonVisuals.SOURCE_SCALE)
		var top: float = records[index].top
		var bottom: float = records[index].bottom
		var cap_transform := Transform3D(basis, Vector3(tile.x, top - ModularDungeonVisuals.FLOOR_TOP * ModularDungeonVisuals.SOURCE_SCALE, tile.y))
		var body_transform := Transform3D(Basis.from_scale(Vector3(1, top - bottom - 0.12, 1)), Vector3(tile.x, (top + bottom - 0.12) / 2.0, tile.y))
		records[index]["cap_transform"] = cap_transform
		records[index]["body_transform"] = body_transform
		cap_batch(records[index]).multimesh.set_instance_transform(records[index].instance, cap_transform)
		body_batch(records[index]).multimesh.set_instance_transform(records[index].instance, body_transform)
		var tint := 1.0
		if renderer.cave_ceiling_variation_enabled: tint += (float(posmod(hash_value / 4, 9)) / 4.0 - 1.0) * renderer.cave_ceiling_color_variation
		records[index]["tint"] = tint
		if not planned.visual_bounds.has_point(tile) or (data.is_walkable(tile) and not records[index].underlay): diagnostics.violations.append(tile)
		# The headless Dummy RenderingServer returns identity for MultiMesh
		# readback. Validate CPU transforms here; GPU capture tests read them back
		# from the normal renderer after frame submission as an independent check.
		var bounds: AABB = cap_transform * caps.multimesh.mesh.get_aabb()
		var ceiling := TerrainFillVisuals.wall_top_offset(0.1, 1.0) if records[index].varied else 0.1
		if not is_equal_approx(bounds.end.y, top) or top > ceiling + 0.001: diagnostics.violations.append(tile)
	diagnostics.mesh_nodes = batches.size() * 2
	if renderer.cave_scenery_border_width > 0:
		scenery_apron = CaveSceneryApron.new()
		scenery_apron.name = "DistantCaveScenery"
		add_child(scenery_apron)
		scenery_apron.setup(data,planned.visual_bounds,get_viewport().get_camera_3d())
		diagnostics.mesh_nodes += 1
		diagnostics["apron_triangles"] = 8
	apply_fog(data, 0, renderer.dim_material.albedo_color, renderer.other_elevation_material.albedo_color)

func apply_fog(data: DungeonData, reference: int, dim: Color, other: Color) -> void:
	if records.is_empty(): return
	# Outer scenery has no discovery state. Only a global elevation palette change
	# touches its colors; ordinary player steps retain the existing interior work.
	var border_shade := dim if reference == 0 else other
	var border_changed := _border_shade != border_shade
	var indices: Array[int] = _all_indices if border_changed else _interior_indices
	for index in indices:
		var record: Dictionary = records[index]
		var bright: bool = data.is_bright(record.cell) or (record.adjacent and data.is_bright(record.owner))
		var shade := border_shade if record.external else (Color.WHITE if bright else (dim if reference == 0 else other))
		records[index]["shade"] = shade
		body_batch(record).multimesh.set_instance_color(record.instance, instance_color(shade, 1.0))
		cap_batch(record).multimesh.set_instance_color(record.instance, instance_color(shade, record.tint))
	_border_shade = border_shade
	if border_changed and is_instance_valid(scenery_apron): scenery_apron.apply_shade(border_shade)

func cap_batch(record: Dictionary) -> MultiMeshInstance3D:
	return batches[record.batch].caps

func body_batch(record: Dictionary) -> MultiMeshInstance3D:
	return batches[record.batch].bodies

static func instance_color(shade: Color, tint: float) -> Color:
	# Material albedo is converted to linear space by the renderer. Raw dim RGB
	# as a vertex multiplier would make batched fog much brighter than the old
	# per-mesh materials. Match their final albedo in linear space instead.
	var base := ModularDungeonVisuals.FILL_COLOR.srgb_to_linear()
	var target := (ModularDungeonVisuals.FILL_COLOR * shade * Color(tint, tint, tint, 1)).srgb_to_linear()
	return Color(target.r / base.r, target.g / base.g, target.b / base.b, 1)
