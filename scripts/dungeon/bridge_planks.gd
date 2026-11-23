class_name BridgePlanks
extends RefCounted
## Procedural plank deck for bridge tiles, in the bridge model's source space
## (x and z in -1..1, walking surface at y = TOP, travel along z). Replaces only
## the model's flat deck; the authored posts and rails stay.
const TOP := 0.10
const GAP := 0.035
const THICKNESS := 0.09
const HALF_SPAN := 0.97
static var _material: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.9
	return _material


## Deterministic 0..1 value for a tile seed and a salt.
static func _rand(seed_value: int, salt: int) -> float:
	var value := posmod(seed_value * 1103515245 + salt * 2654435761 + 12345, 2147483647)
	value = posmod((value ^ (value >> 13)) * 1274126177, 2147483647)
	return float(posmod(value ^ (value >> 16), 100000)) / 100000.0


## One tile's deck: `planks` boards across the bridge on two stringers. Old boards
## are greyer and slightly sunk; broken boards keep one end with a stepped break.
static func deck(seed_value: int, planks: int, old_ratio: float, broken_ratio: float) -> ArrayMesh:
	planks = maxi(planks, 1)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pitch := 2.0 / planks
	for index in range(planks):
		var z0 := -1.0 + index * pitch + GAP * 0.5
		var z1 := z0 + pitch - GAP
		var x0 := -HALF_SPAN + (_rand(seed_value, index * 7 + 1) - 0.5) * 0.06
		var x1 := HALF_SPAN + (_rand(seed_value, index * 7 + 2) - 0.5) * 0.06
		var shade := 0.88 + 0.22 * _rand(seed_value, index * 7 + 3)
		var tint := Color(shade, shade * (0.97 + 0.06 * _rand(seed_value, index * 7 + 4)), shade * 0.97)
		var top := TOP
		# The middle plank always stays whole and at full height, so the deck
		# surface keeps the exact floor plane.
		var old := index != planks / 2 and _rand(seed_value, index * 7 + 5) < old_ratio
		var broken := index != planks / 2 and _rand(seed_value, index * 7 + 6) < broken_ratio
		if old:
			# Weathered: greyer, darker and slightly sunk.
			tint = Color(tint.r * 0.78, tint.g * 0.86, tint.b * 1.02)
			top -= 0.018
		if broken:
			# Snapped plank: one end remains, with a stepped (splintered) break.
			var keep := 0.3 + 0.35 * _rand(seed_value, index * 7 + 7)
			var from_left := _rand(seed_value, index * 7 + 8) < 0.5
			var length := (x1 - x0) * keep
			var mid := (z0 + z1) * 0.5
			var step := 0.06 + 0.08 * _rand(seed_value, index * 7 + 9)
			if from_left:
				_box(tool, Vector3(x0, top - THICKNESS, z0), Vector3(x0 + length, top, mid), tint)
				_box(tool, Vector3(x0, top - THICKNESS, mid), Vector3(x0 + length + step, top, z1), tint)
			else:
				_box(tool, Vector3(x1 - length, top - THICKNESS, z0), Vector3(x1, top, mid), tint)
				_box(tool, Vector3(x1 - length - step, top - THICKNESS, mid), Vector3(x1, top, z1), tint)
		else:
			_box(tool, Vector3(x0, top - THICKNESS, z0), Vector3(x1, top, z1), tint)
	# Two stringers under the planks carry the deck along the bridge.
	var beam := Color(0.72, 0.7, 0.68)
	for side in [-1.0, 1.0]:
		_box(tool, Vector3(side * 0.62 - 0.08, TOP - THICKNESS - 0.16, -1.0), Vector3(side * 0.62 + 0.08, TOP - THICKNESS, 1.0), beam)
	tool.set_material(material())
	return tool.commit()


static func _box(tool: SurfaceTool, low: Vector3, high: Vector3, color: Color) -> void:
	var c := [Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z), Vector3(high.x, low.y, high.z), Vector3(low.x, low.y, high.z),
		Vector3(low.x, high.y, low.z), Vector3(high.x, high.y, low.z), Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z)]
	_quad(tool, c[4], c[5], c[6], c[7], Vector3.UP, color)
	_quad(tool, c[0], c[3], c[2], c[1], Vector3.DOWN, color * 0.6)
	_quad(tool, c[0], c[1], c[5], c[4], Vector3.FORWARD, color * 0.85)
	_quad(tool, c[2], c[3], c[7], c[6], Vector3.BACK, color * 0.85)
	_quad(tool, c[3], c[0], c[4], c[7], Vector3.LEFT, color * 0.8)
	_quad(tool, c[1], c[2], c[6], c[5], Vector3.RIGHT, color * 0.8)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color) -> void:
	color.a = 1.0
	for triangle in [[a, b, c], [a, c, d]]:
		# Godot front faces are clockwise seen from the normal side: front = -(b-a)x(c-a).
		if (-(triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])).dot(outward) < 0.0:
			triangle = [triangle[0], triangle[2], triangle[1]]
		for vertex in triangle:
			tool.set_color(color)
			tool.set_normal(outward)
			tool.add_vertex(vertex)
