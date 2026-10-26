class_name TerrainFillVisuals
extends RefCounted
## Presentation-only ownership of non-walkable space. Never writes DungeonData.
static var meshes: Dictionary = {}
static var stone_material: StandardMaterial3D
static var cave_meshes: Dictionary = {}

static func layout(data: DungeonData, margin: int) -> Dictionary:
	var cells: Dictionary = {}
	var walkable: Array[Vector2i] = []
	var bounds := Rect2i()
	var first := true
	var minimum_height: float = INF
	for tile: Vector2i in data.tiles:
		if first:
			bounds = Rect2i(tile, Vector2i.ONE)
			first = false
		else:
			bounds = bounds.merge(Rect2i(tile, Vector2i.ONE))
		if data.is_walkable(tile):
			walkable.append(tile)
			minimum_height = minf(minimum_height, data.surface_elevation(tile))
	if walkable.is_empty(): return {"cells": cells, "bounds": bounds, "base": 0.0}
	bounds = bounds.grow(margin)
	# Higher boundary wins an equal-distance tie, closing both wall backs.
	# This is local nearest-boundary ownership, not a roof at the highest level.
	walkable.sort_custom(func(a: Vector2i, b: Vector2i):
		var ha := data.surface_elevation(a)
		var hb := data.surface_elevation(b)
		if not is_equal_approx(ha, hb): return ha > hb
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var claimed: Dictionary = {}
	var queue: Array[Vector2i] = walkable.duplicate()
	for tile in walkable:
		claimed[tile] = {"owner": tile, "distance": 0, "height": data.surface_elevation(tile), "elevation": data.get_elevation(tile)}
	var head := 0
	while head < queue.size():
		var tile := queue[head]
		head += 1
		var source: Dictionary = claimed[tile]
		for direction: Vector2i in DungeonData.CARDINALS:
			var neighbor := tile + direction
			if not bounds.has_point(neighbor) or data.is_walkable(neighbor) or claimed.has(neighbor): continue
			var entry := source.duplicate()
			entry.distance += 1
			claimed[neighbor] = entry
			cells[neighbor] = entry
			queue.append(neighbor)
	return {"cells": cells, "bounds": bounds, "base": minimum_height * DungeonData.ELEVATION_HEIGHT - DungeonData.TILE_SIZE}

static func wall_top_offset(floor_surface: float, wall_scale: float = 1.0) -> float:
	return floor_surface + (ModularDungeonVisuals.WALL.get_aabb().end.y - ModularDungeonVisuals.FLOOR_TOP) * ModularDungeonVisuals.SOURCE_SCALE * DungeonData.TILE_SIZE * wall_scale

static func material() -> StandardMaterial3D:
	if stone_material == null:
		stone_material = ModularDungeonVisuals.FLOOR.surface_get_material(0).duplicate()
		stone_material.albedo_color = ModularDungeonVisuals.FILL_COLOR
	return stone_material

static func mesh(depth: float, detailed_cap: bool) -> ArrayMesh:
	var key := "%0.5f:%s" % [depth, detailed_cap]
	if not meshes.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := -0.12 * DungeonData.TILE_SIZE if detailed_cap else 0.0
		var body := BoxMesh.new()
		body.size = Vector3(DungeonData.TILE_SIZE, depth + top, DungeonData.TILE_SIZE)
		surface.append_from(body, 0, Transform3D(Basis.IDENTITY, Vector3(0, (top - depth) / 2.0, 0)))
		if detailed_cap:
			var scale := ModularDungeonVisuals.SOURCE_SCALE * DungeonData.TILE_SIZE
			surface.append_from(ModularDungeonVisuals.FLOOR, 0, Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3(0, -ModularDungeonVisuals.FLOOR_TOP * scale, 0)))
		var result := surface.commit()
		result.surface_set_material(0, material())
		meshes[key] = result
	return meshes[key]

static func cave_mesh(depth: float) -> ArrayMesh:
	var key := "%0.5f" % depth
	if not cave_meshes.has(key):
		var mesh := ArrayMesh.new()
		var body := BoxMesh.new()
		body.size = Vector3(DungeonData.TILE_SIZE, depth - 0.12, DungeonData.TILE_SIZE)
		var sides := SurfaceTool.new()
		sides.begin(Mesh.PRIMITIVE_TRIANGLES)
		sides.append_from(body, 0, Transform3D(Basis.IDENTITY, Vector3(0, (-depth - 0.12) / 2.0, 0)))
		sides.commit(mesh)
		mesh.surface_set_material(0, material())
		var cap := SurfaceTool.new()
		cap.begin(Mesh.PRIMITIVE_TRIANGLES)
		var scale := ModularDungeonVisuals.SOURCE_SCALE * DungeonData.TILE_SIZE
		cap.append_from(ModularDungeonVisuals.FLOOR, 0, Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3(0, -ModularDungeonVisuals.FLOOR_TOP * scale, 0)))
		cap.commit(mesh)
		mesh.surface_set_material(1, material())
		cave_meshes[key] = mesh
	return cave_meshes[key]
