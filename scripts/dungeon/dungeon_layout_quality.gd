class_name DungeonLayoutQuality
extends RefCounted
## Pure geometry evaluation: no RNG, tile writes, routing, acceptance, or rendering.
const DEFAULT_SETTINGS = preload("res://config/layout_quality.tres")

static func empty_gaps(a: Rect2i, b: Rect2i) -> Vector2i:
	# Rect end is exclusive. Rect(0,0,3,3) and Rect(4,0,3,3) have one empty column.
	return Vector2i(maxi(0, maxi(b.position.x - a.end.x, a.position.x - b.end.x)), maxi(0, maxi(b.position.y - a.end.y, a.position.y - b.end.y)))

static func projected_envelope(room: Rect2i, elevation: int, settings: DungeonQualitySettings) -> Rect2:
	# Fixed +Z camera side, zero yaw. Parallel projection is a risk proxy only;
	# it intentionally does not simulate the moving perspective camera or filler.
	var pitch := deg_to_rad(settings.camera_pitch_degrees)
	var x_min := (room.position.x - 0.5) * DungeonData.TILE_SIZE - settings.edge_margin
	var x_max := (room.end.x - 0.5) * DungeonData.TILE_SIZE + settings.edge_margin
	var z_min := (room.position.y - 0.5) * DungeonData.TILE_SIZE - settings.edge_margin
	var z_max := (room.end.y - 0.5) * DungeonData.TILE_SIZE + settings.edge_margin
	var height := elevation * DungeonData.ELEVATION_HEIGHT
	var bottom := height * cos(pitch) - z_max * sin(pitch)
	var top := (height + settings.visual_height) * cos(pitch) - z_min * sin(pitch)
	return Rect2(Vector2(x_min, bottom), Vector2(x_max - x_min, top - bottom))

static func evaluate(rooms: Array[Rect2i], heights: Array[int], settings: DungeonQualitySettings = null) -> Dictionary:
	if settings == null: settings = DEFAULT_SETTINGS
	var report := {"evaluated": false, "errors": PackedStringArray(), "room_count": rooms.size(), "pair_count": 0,
		"pairs": [], "violating_pairs": [], "potential_overlap_pairs": [], "total_deficit": 0,
		"rooms": rooms.duplicate(), "elevations": heights.duplicate(),
		"settings": {"enabled": settings.enabled, "same": settings.same_elevation_gap, "one": settings.one_level_gap,
			"two": settings.two_level_gap, "camera_pitch": settings.camera_pitch_degrees, "visual_height": settings.visual_height, "edge_margin": settings.edge_margin}}
	if not settings.enabled: return report
	report.errors = settings.validation_errors()
	if rooms.size() != heights.size(): report.errors.append("Room and elevation counts differ.")
	for height in heights:
		if height not in [-1, 0, 1]: report.errors.append("Room elevations must be -1, 0, or +1.")
	for room in rooms:
		if room.size.x <= 0 or room.size.y <= 0: report.errors.append("Room dimensions must be positive.")
	if not report.errors.is_empty(): return report
	var levels: Array[int] = []
	for height in heights:
		if not levels.has(height): levels.append(height)
	levels.sort()
	report["elevation_levels"] = levels
	var envelopes: Array[Rect2] = []
	for index in range(rooms.size()): envelopes.append(projected_envelope(rooms[index], heights[index], settings))
	for a in range(rooms.size()):
		for b in range(a + 1, rooms.size()):
			var difference := absi(heights[a] - heights[b])
			var gaps := empty_gaps(rooms[a], rooms[b])
			# Chebyshev rectangle distance: minimum empty-cell clearance for square padding.
			var separation := maxi(gaps.x, gaps.y)
			var required := settings.gap_for_difference(difference)
			var deficit := maxi(0, required - separation)
			var higher := a if heights[a] > heights[b] else b
			var lower := b if higher == a else a
			var foreground := difference > 0 and rooms[higher].position.y >= rooms[lower].end.y
			var overlap := envelopes[a].intersection(envelopes[b])
			var potential := foreground and overlap.has_area()
			var pair := {"a": a, "b": b, "elevation_a": heights[a], "elevation_b": heights[b], "difference": difference,
				"gap_x": gaps.x, "gap_y": gaps.y, "empty_separation": separation, "required": required, "deficit": deficit,
				"room_overlap": rooms[a].intersects(rooms[b]), "higher": higher if difference > 0 else -1,
				"higher_in_front": foreground, "potential_camera_overlap": potential,
				"projected_overlap_area": overlap.get_area() if potential else 0.0}
			report.pairs.append(pair)
			report.total_deficit += deficit
			if deficit > 0: report.violating_pairs.append(Vector2i(a, b))
			if potential: report.potential_overlap_pairs.append(Vector2i(a, b))
	report.pair_count = report.pairs.size()
	report.evaluated = true
	return report

static func summary(report: Dictionary) -> Dictionary:
	return {"evaluated": report.get("evaluated", false), "room_pairs": report.get("pair_count", 0),
		"elevation_levels": report.get("elevation_levels", []),
		"violations": report.get("violating_pairs", []).size(), "deficit": report.get("total_deficit", 0),
		"potential_camera_overlaps": report.get("potential_overlap_pairs", []).size(),
		"errors": report.get("errors", PackedStringArray()), "mode": "evaluation_only"}

static func serializable(value: Variant) -> Variant:
	# Keep diagnostic JSON numeric and replayable rather than Godot's vector strings.
	if value is Vector2i: return [value.x, value.y]
	if value is Rect2i: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = serializable(value[key])
		return result
	if value is Array or value is PackedStringArray:
		var result: Array = []
		for item in value: result.append(serializable(item))
		return result
	return value
