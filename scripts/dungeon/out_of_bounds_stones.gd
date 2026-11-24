class_name OutOfBoundsStones
extends Node3D
## Boulders and rubble on the out-of-bounds terrain. Rendering only: no collision,
## no gameplay data. Shapes are low-poly displaced icospheres drawn with the
## terrain's own (shared) rock material, so they take the same texture, lighting
## and fog shade as the ground. Placement follows the terrain: boulders gather on
## steep ground and at the foot of the plateau rim, rubble lies around them, all
## inside the band the gameplay camera actually sees. Every choice comes from a
## coordinate hash of the floor's visual seed, never from gameplay RNG.
const VARIANTS := 6
## Candidate spacing in world units (one candidate per cell, jittered).
const CELL := 0.5
## Visible band past the kept layout cells, in tiles.
const NEAR := 0.45
const FAR := 8.0
var counts := {"boulders": 0, "rubble": 0}
## Every placed stone as [Transform3D, tint Color, shape index], kept for checks
## (headless rendering cannot read MultiMesh instances back).
var placements: Array = []
var _tops: Array[float] = [] # Per shape: highest point above its origin, in unit size.
var _settings := {"density": 1.0, "size": 1.0, "lift": 0.06, "shade_spread": 0.28, "warmth_spread": 0.07}
static var _ico_faces: Array = []


func populate(scenery: OutOfBoundsScenery, seed_value: int, settings: Dictionary = {}) -> void:
	name = "OutOfBoundsStones"
	set_meta("geometry_purpose", "out_of_bounds_scenery")
	_settings.merge(settings, true)
	var cluster := FastNoiseLite.new()
	cluster.seed = seed_value + 5
	cluster.frequency = 0.28
	var meshes: Array[ArrayMesh] = []
	for v in range(VARIANTS):
		meshes.append(rock_mesh(seed_value * 13 + v * 101))
		# Farthest vertex from the origin: the highest any rotation can reach.
		var reach := 0.0
		for vertex in meshes[v].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: reach = maxf(reach, vertex.length())
		_tops.append(reach)
	var buckets: Array = []
	for v in range(VARIANTS): buckets.append([])
	var region := scenery.region
	var columns := int(region.size.x / CELL)
	var rows := int(region.size.y / CELL)
	var density := maxf(0.0, float(_settings.density))
	var scale := maxf(0.1, float(_settings.size))
	for row in range(rows):
		for column in range(columns):
			var h := seed_value * 7919 + column * 92821 + row * 68917
			var x := region.position.x + (column + _rand(h, 1)) * CELL
			var z := region.position.y + (row + _rand(h, 2)) * CELL
			var distance := scenery.map_distance(x, z)
			if distance < NEAR or distance > FAR: continue
			var normal := _normal(scenery, x, z)
			var steep := 1.0 - normal.y
			var gather := clampf((cluster.get_noise_2d(x, z) + 1.0) * 0.5, 0.0, 1.0)
			# Scree collects at the foot of the plateau rim, about a tile out.
			var foot := 1.0 - smoothstep(0.4, 1.6, absf(distance - 1.0))
			var chance := 0.03 + 0.5 * gather * smoothstep(0.08, 0.4, steep) + 0.22 * foot * gather
			chance *= (1.0 - smoothstep(5.0, FAR, distance)) * density
			if _rand(h, 3) >= chance: continue
			var size := (0.14 + 0.32 * pow(_rand(h, 4), 2.0)) * scale
			_place(scenery, buckets, x, z, size, normal, h)
			counts.boulders += 1
			for k in range(2 + int(_rand(h, 5) * 4.0)):
				var angle := _rand(h, 10 + k) * TAU
				var reach := size * (1.1 + 1.6 * _rand(h, 20 + k))
				var px := x + cos(angle) * reach
				var pz := z + sin(angle) * reach
				if scenery.map_distance(px, pz) < NEAR * 0.8: continue
				_place(scenery, buckets, px, pz, (0.035 + 0.06 * _rand(h, 30 + k)) * scale, _normal(scenery, px, pz), h + k * 31)
				counts.rubble += 1
	for v in range(VARIANTS):
		if buckets[v].is_empty(): continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = meshes[v]
		multimesh.instance_count = buckets[v].size()
		for i in range(buckets[v].size()):
			multimesh.set_instance_transform(i, buckets[v][i][0])
			multimesh.set_instance_color(i, buckets[v][i][1])
		var node := MultiMeshInstance3D.new()
		node.name = "Stones_%d" % v
		node.multimesh = multimesh
		# Shared terrain material: fog shade and lighting follow the ground.
		node.material_override = scenery.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if scenery.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("geometry_purpose", "out_of_bounds_scenery")
		add_child(node)


## One stone shape: a once-subdivided icosphere, squashed and noise-displaced, flat shaded.
static func rock_mesh(seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.6
	var points := _icosphere()
	var squash := Vector3(1.0 + 0.25 * _rand(seed_value, 1), 0.6 + 0.2 * _rand(seed_value, 2), 1.0 + 0.25 * _rand(seed_value, 3))
	for index in range(points.size()):
		var p: Vector3 = points[index]
		points[index] = p * (1.0 + 0.32 * noise.get_noise_3dv(p * 1.3)) * squash
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in _ico_faces:
		var a: Vector3 = points[face[0]]
		var b: Vector3 = points[face[1]]
		var c: Vector3 = points[face[2]]
		# Godot front faces are clockwise seen from the normal side: front = -(b-a)x(c-a).
		var normal := -(b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0) < 0.0:
			var swap := b
			b = c
			c = swap
			normal = -normal
		for vertex in [a, b, c]:
			tool.set_normal(normal)
			tool.add_vertex(vertex)
	return tool.commit()


static func _icosphere() -> PackedVector3Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var mids: Dictionary = {}
	var split := []
	for f in faces:
		var m := []
		for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
			var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
			if not mids.has(key):
				mids[key] = verts.size()
				verts.append((verts[e[0]] + verts[e[1]]) * 0.5)
			m.append(mids[key])
		split.append_array([[f[0], m[0], m[2]], [f[1], m[1], m[0]], [f[2], m[2], m[1]], [m[0], m[1], m[2]]])
	_ico_faces = split
	var result := PackedVector3Array()
	for v in verts: result.append(v.normalized())
	return result


static func _rand(seed_value: int, salt: int) -> float:
	return BridgePlanks._rand(seed_value, salt)


func _normal(scenery: OutOfBoundsScenery, x: float, z: float) -> Vector3:
	var e := 0.15
	var dx := scenery.height_at(x + e, z) - scenery.height_at(x - e, z)
	var dz := scenery.height_at(x, z + e) - scenery.height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func _place(scenery: OutOfBoundsScenery, buckets: Array, x: float, z: float, size: float, normal: Vector3, h: int) -> void:
	var y := scenery.height_at(x, z)
	# Half-tilted to the slope, random yaw (stones have no facing), sunk into the ground.
	var up := Vector3.UP.slerp(normal, 0.6).normalized()
	var basis := (Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, _rand(h, 6) * TAU)).scaled(Vector3.ONE * size)
	# Near the rim no stone rises above map level.
	var variant := posmod(h, VARIANTS)
	var top := y - size * 0.3 + _tops[variant] * size
	var limit := scenery.ground_level - 0.04
	if scenery.map_distance(x, z) < 2.5 and top > limit: y -= top - limit
	# Each stone: its own shade around a slight lift, plus a small warm/cool shift.
	var shade := 1.0 + float(_settings.lift) + (_rand(h, 7) - 0.5) * float(_settings.shade_spread)
	var warmth := (_rand(h, 8) - 0.5) * float(_settings.warmth_spread)
	var tint := Color(shade * (1.0 + warmth), shade, shade * (1.0 - warmth), 1.0)
	var placed := Transform3D(basis, Vector3(x, y - size * 0.3, z))
	buckets[variant].append([placed, tint])
	placements.append([placed, tint, variant])
