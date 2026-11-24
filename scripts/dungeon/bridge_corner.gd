class_name BridgeCorner
extends RefCounted
## 90-degree curved bridge tile, in the bridge model's source space
## (x, z in -1..1, walking surface at y = BridgePlanks.TOP). Canonical piece
## connects the +X and +Z sides; the turn wraps around the inner corner (1, 1).
const INNER := Vector2(1.0, 1.0)
const PLANKS := 8
const OUTER_RAIL := 1.8
const INNER_RAIL := 0.2


static func _point(r: float, angle: float) -> Vector2:
	# angle 0 runs along the +X edge (x = 1), PI/2 along the +Z edge (z = 1).
	return INNER + Vector2(-sin(angle), -cos(angle)) * r


static func deck(seed_value: int, old_ratio: float, broken_ratio: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (PI / 2.0) / PLANKS
	var gap := BridgePlanks.GAP / 1.1
	var top_y := BridgePlanks.TOP
	for index in range(PLANKS):
		var a0 := index * step + gap * 0.5
		var a1 := (index + 1) * step - gap * 0.5
		var r0 := 0.03 + (BridgePlanks._rand(seed_value, index * 7 + 1) - 0.5) * 0.06 + 0.03
		var r1 := 1.97 + (BridgePlanks._rand(seed_value, index * 7 + 2) - 0.5) * 0.06
		var shade := 0.88 + 0.22 * BridgePlanks._rand(seed_value, index * 7 + 3)
		var tint := Color(shade, shade * (0.97 + 0.06 * BridgePlanks._rand(seed_value, index * 7 + 4)), shade * 0.97)
		var top := top_y
		var old := index != PLANKS / 2 and BridgePlanks._rand(seed_value, index * 7 + 5) < old_ratio
		var broken := index != PLANKS / 2 and BridgePlanks._rand(seed_value, index * 7 + 6) < broken_ratio
		if old:
			tint = Color(tint.r * 0.78, tint.g * 0.86, tint.b * 1.02)
			top -= 0.018
		if broken:
			var keep := 0.3 + 0.35 * BridgePlanks._rand(seed_value, index * 7 + 7)
			var from_inner := BridgePlanks._rand(seed_value, index * 7 + 8) < 0.5
			var length := (r1 - r0) * keep
			var mid := (a0 + a1) * 0.5
			var jag := 0.06 + 0.08 * BridgePlanks._rand(seed_value, index * 7 + 9)
			if from_inner:
				_wedge(tool, r0, r0 + length, a0, mid, top, top - BridgePlanks.THICKNESS, tint)
				_wedge(tool, r0, r0 + length + jag, mid, a1, top, top - BridgePlanks.THICKNESS, tint)
			else:
				_wedge(tool, r1 - length, r1, a0, mid, top, top - BridgePlanks.THICKNESS, tint)
				_wedge(tool, r1 - length - jag, r1, mid, a1, top, top - BridgePlanks.THICKNESS, tint)
		else:
			_wedge(tool, r0, r1, a0, a1, top, top - BridgePlanks.THICKNESS, tint)
	# Two curved stringers under the boards, in short straight pieces.
	var beam := Color(0.72, 0.7, 0.68)
	var under := top_y - BridgePlanks.THICKNESS
	for radius in [0.38, 1.62]:
		for index in range(PLANKS):
			_wedge(tool, radius - 0.08, radius + 0.08, index * step, (index + 1) * step, under, under - 0.16, beam)
	tool.set_material(BridgePlanks.material())
	return tool.commit()


## Posts copied from the authored bridge model plus rails along the outer and inner turn.
static func rails(post_source: Mesh, post_surface: int) -> ArrayMesh:
	var bounds := ModularDungeonVisuals.surface_bounds(post_source, post_surface)
	var post_center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().z)
	var outer: Array[Vector2] = [_point(OUTER_RAIL, 0.0), _point(OUTER_RAIL, PI / 4.0), _point(OUTER_RAIL, PI / 2.0)]
	var inner := _point(INNER_RAIL, PI / 4.0)
	var material := post_source.surface_get_material(post_surface)
	# Rails first as their own surface: posts copied from the model carry a
	# different vertex format, so they get a second surface.
	var rail_tool := SurfaceTool.new()
	rail_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(outer.size() - 1):
		_beam(rail_tool, outer[index], outer[index + 1], 0.42, 0.67, 0.04, Color.WHITE)
	rail_tool.set_material(material)
	var mesh := rail_tool.commit()
	var post_tool := SurfaceTool.new()
	post_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spot in outer + [inner]:
		post_tool.append_from(ModularDungeonVisuals.surface_mesh(post_source, post_surface), 0, Transform3D(Basis(), Vector3(spot.x, 0.0, spot.y) - post_center))
	post_tool.set_material(material)
	return post_tool.commit(mesh)


static func _wedge(tool: SurfaceTool, r0: float, r1: float, a0: float, a1: float, top: float, bottom: float, color: Color) -> void:
	_prism(tool, [_point(r0, a0), _point(r1, a0), _point(r1, a1), _point(r0, a1)], top, bottom, color)


static func _beam(tool: SurfaceTool, a: Vector2, b: Vector2, low: float, high: float, width: float, color: Color) -> void:
	var side := (b - a).normalized().orthogonal() * width * 0.5
	_prism(tool, [a - side, b - side, b + side, a + side], high, low, color)


## Convex quad footprint extruded between two heights.
static func _prism(tool: SurfaceTool, footprint: Array, top: float, bottom: float, color: Color) -> void:
	var center := Vector2.ZERO
	for p in footprint: center += p
	center /= footprint.size()
	var t: Array[Vector3] = []
	var b: Array[Vector3] = []
	for p in footprint:
		t.append(Vector3(p.x, top, p.y))
		b.append(Vector3(p.x, bottom, p.y))
	BridgePlanks._quad(tool, t[0], t[1], t[2], t[3], Vector3.UP, color)
	BridgePlanks._quad(tool, b[0], b[3], b[2], b[1], Vector3.DOWN, color * 0.6)
	for index in range(footprint.size()):
		var next := (index + 1) % footprint.size()
		var edge_mid: Vector2 = (footprint[index] + footprint[next]) * 0.5
		var out := edge_mid - center
		BridgePlanks._quad(tool, t[index], t[next], b[next], b[index], Vector3(out.x, 0.0, out.y).normalized(), color * 0.82)
