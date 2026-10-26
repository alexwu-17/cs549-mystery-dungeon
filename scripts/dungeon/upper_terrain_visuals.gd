class_name UpperTerrainVisuals
extends RefCounted
## Decorative only. Input layout and DungeonData are never modified.
enum Mode { UNLIMITED, BOUNDED, TERRACES }

static func camera_risk(tile: Vector2i, top: float, lower_tiles: Array[Vector2i], pitch: float) -> bool:
	# Conservative +Z camera viewing stripe, including a whole lower tile/body.
	# Deliberately omit decoration rather than depend on runtime fading for safety.
	var reach := (maxf(0.0, top) + 0.5) / tan(deg_to_rad(clampf(pitch, 10.0, 80.0))) + 1.5
	for lower in lower_tiles:
		var delta := tile - lower
		if absf(float(delta.x)) <= 1.5 and delta.y >= -1 and float(delta.y) <= reach:
			return true
	return false

static func prepare(data: DungeonData, original: Dictionary, mode: Mode, maximum: int, band_width: int, irregular: bool, clearance: int, pitch: float) -> Dictionary:
	var result := {"cells": original.cells.duplicate(true), "bounds": original.bounds, "base": original.base,
		"skirts": [], "metrics": {"upper_cells": 0, "decorative_cells": 0, "ground_cells": 0,
			"protected_cells": 0, "camera_rejected": 0, "potential_overlap": 0, "exposed_edges": 0, "skirts": 0}}
	if mode == Mode.UNLIMITED or data.legacy_ramp: return result
	var upper: Dictionary = {}
	var lower: Array[Vector2i] = []
	var protected: Dictionary = {}
	for tile: Vector2i in data.tiles:
		if not data.is_walkable(tile): continue
		if data.get_elevation(tile) == 1 and data.get_room_id(tile) >= 0:
			upper[tile] = true
		if data.get_elevation(tile) <= 0:
			lower.append(tile)
		# Keep walls, stairs and walkways clear, including diagonal asset overhang.
		if data.get_elevation(tile) <= 0 or data.get_tile(tile) in [DungeonData.TileType.CORRIDOR, DungeonData.TileType.STAIRS]:
			for y in range(-clearance, clearance + 1):
				for x in range(-clearance, clearance + 1): protected[tile + Vector2i(x, y)] = true
	for segment in data.ramp_segments:
		# Both approaches plus the entire five-tile footprint and side clearance.
		for index in range(-1, 6):
			var tile: Vector2i = segment.lower_buffer + segment.direction * index
			for y in range(-1, 2):
				for x in range(-1, 2): protected[tile + Vector2i(x, y)] = true
	if upper.is_empty(): return result # Benchmark, arena, lower-only floors unchanged.
	# An upper-only debug layout still needs a base below the decorative ground.
	result.base = minf(float(original.base), -DungeonData.TILE_SIZE)
	var distance: Dictionary = {}
	var owners: Dictionary = {}
	var queue: Array[Vector2i] = []
	for tile: Vector2i in upper:
		distance[tile] = 0
		owners[tile] = tile
		queue.append(tile)
	var head := 0
	while head < queue.size():
		var tile := queue[head]
		head += 1
		if int(distance[tile]) >= maximum: continue
		for direction: Vector2i in DungeonData.CARDINALS:
			var next := tile + direction
			if distance.has(next) or protected.has(next) or data.get_tile(next) != DungeonData.TileType.VOID or not original.cells.has(next): continue
			var old: Dictionary = original.cells[next]
			# Never replace the original lower dungeon filler or bridge-owned void.
			if data.get_elevation(old.owner) != 1 or data.get_room_id(old.owner) < 0: continue
			distance[next] = int(distance[tile]) + 1
			owners[next] = owners[tile]
			queue.append(next)
	for tile: Vector2i in result.cells.keys():
		var entry: Dictionary = result.cells[tile]
		if data.get_elevation(entry.owner) != 1 or data.get_room_id(entry.owner) < 0: continue
		# Outside the bounded region, settle to the lower stone base instead of
		# retaining the unlimited flat plateau. No claimed gameplay tiles are added.
		var top := 0.1
		var d: int = distance.get(tile, maximum + 1)
		if protected.has(tile):
			result.metrics.protected_cells += 1
			result.cells.erase(tile)
			continue
		if d <= maximum:
			if mode == Mode.BOUNDED:
				top = DungeonData.ELEVATION_HEIGHT + 0.1
			else:
				# Coarse, stable coordinate variation only thins the outer band.
				# It never touches gameplay RNG or raises a band toward a lower path.
				var jitter := int(irregular and d > band_width and posmod(tile.x * 73856093 ^ tile.y * 19349663, 5) == 0)
				var band := 1 + (d - 1 + jitter) / maxi(1, band_width)
				top = maxf(0.0, DungeonData.ELEVATION_HEIGHT * (1.0 - float(band) / 3.0)) + 0.1
			if top > 0.1 and camera_risk(tile, top, lower, pitch):
				result.metrics.camera_rejected += 1
				top = 0.1
		entry["top"] = top
		entry["decorative"] = true
		entry["terrace"] = top > 0.1 and top < DungeonData.ELEVATION_HEIGHT
		if top > 0.1:
			entry.owner = owners.get(tile, entry.owner)
			entry.distance = d
			result.metrics.upper_cells += 1
			result.metrics.decorative_cells += int(entry.terrace)
		else:
			entry.elevation = 0
			result.metrics.ground_cells += 1
	# Thin vertical stone skirts meet the floor underside and the nearest band.
	# They sit inside each platform tile, never in an approach/walkway footprint.
	var floor_bottom := DungeonData.ELEVATION_HEIGHT + 0.1 + (ModularDungeonVisuals.FLOOR.get_aabb().position.y - ModularDungeonVisuals.FLOOR_TOP) * ModularDungeonVisuals.SOURCE_SCALE * DungeonData.TILE_SIZE
	for tile: Vector2i in upper:
		for direction: Vector2i in DungeonData.CARDINALS:
			var neighbor := tile + direction
			if data.is_walkable(neighbor): continue
			var bottom: float = result.cells.get(neighbor, {}).get("top", 0.1)
			if bottom >= floor_bottom: continue
			if protected.has(tile) or camera_risk(tile, floor_bottom, lower, pitch):
				result.metrics.exposed_edges += 1
				continue
			result.skirts.append({"owner": tile, "direction": direction, "top": floor_bottom, "bottom": bottom})
	result.metrics.skirts = result.skirts.size()
	return result
