class_name OutOfBoundsFoliage
extends Node3D
## Trees, bushes, plants, flower patches, grass tufts, stumps and fallen logs on
## the out-of-bounds terrain, chosen by season. Also sets the terrain shader's
## season (summer meadow grass, winter snow). Rendering only: placement is a
## coordinate hash of the floor's visual seed (never generation RNG) and stays
## inside the terrain band beside the layout. Groves, tufts and flowers follow
## the meadow pattern the terrain shader paints, so plants stand in grass.

enum Season { NONE, SUMMER_SPRING, WINTER }
const DIR := "res://assets/environment/foliage/%s.obj"
const SETS := {
	Season.SUMMER_SPRING: {
		"trees": ["CommonTree_1", "CommonTree_2", "CommonTree_4", "CommonTree_5", "PineTree_1", "PineTree_2", "PineTree_3", "PineTree_5", "BirchTree_1", "BirchTree_3", "BirchTree_5"],
		"bushes": ["Bush_1", "Bush_2", "BushBerries_1", "BushBerries_2"],
		"plants": ["Plant_1", "Plant_3", "Plant_3", "Plant_4", "Plant_5"],
		"flowers": ["Flowers@white", "Flowers@yellow", "Flowers@pink", "Flowers@violet", "Flowers@white", "Flowers"],
		"stumps": ["TreeStump", "TreeStump_Moss"],
		"logs": ["WoodLog", "WoodLog_Moss"],
		"grass": ["GrassClump_0", "GrassClump_1", "GrassClump_2", "GrassClump_3", "GrassClump_4", "GrassClump_5"],
		"rocks": ["Rock_Moss_1", "Rock_Moss_2", "Rock_Moss_3", "Rock_Moss_4", "Rock_Moss_5", "Rock_Moss_6", "Rock_Moss_7", "Rock_1", "Rock_3", "Rock_5"],
		"willows": ["Willow_1", "Willow_2", "Willow_3", "Willow_4", "Willow_5"],
		"reeds": ["Grass", "Grass_2"],
		"lilypads": ["Lilypad"],
	},
	Season.WINTER: {
		"trees": ["CommonTree_Snow_1", "CommonTree_Snow_2", "CommonTree_Snow_4", "CommonTree_Snow_5", "PineTree_Snow_1", "PineTree_Snow_2", "PineTree_Snow_3", "PineTree_Snow_5", "BirchTree_Snow_1", "BirchTree_Snow_5", "CommonTree_Dead_Snow_1", "CommonTree_Dead_Snow_2", "BirchTree_Dead_Snow_1", "BirchTree_Dead_Snow_3"],
		"bushes": ["Bush_Snow_1", "Bush_Snow_2"],
		"plants": [],
		"flowers": [],
		"stumps": ["TreeStump_Snow"],
		"logs": ["WoodLog_Snow"],
		"grass": [],
		"rocks": [],
		"willows": [],
		"reeds": [],
		"lilypads": [],
	},
}
## Built-in per-season density (winter has far fewer bushes and no plants).
const SEASON_DENSITY := {Season.SUMMER_SPRING: {"trees": 1.0, "bushes": 0.75}, Season.WINTER: {"trees": 0.75, "bushes": 0.3}}
## Target heights in tiles per kind, before per-instance jitter (0.75-1.25).
const HEIGHTS := {"trees": 2.0, "bushes": 0.55, "plants": 0.3, "flowers": 0.24, "stumps": 0.35, "logs": 0.3, "grass": 0.13, "rocks": 0.3, "willows": 2.2, "reeds": 0.32, "lilypads": 0.05, "pebbles": 0.07}
## The models' own snow is lavender; use the ground's snow colour instead.
const SNOW := Color(0.9, 0.92, 0.96)
## Petal colors (sRGB) replacing the Flowers model's cyan for each variant.
const PETALS := {"white": Color(0.93, 0.92, 0.86), "yellow": Color(0.96, 0.8, 0.28), "pink": Color(0.9, 0.52, 0.7), "violet": Color(0.6, 0.48, 0.86)}
## Grass tuft variants: [blades, base radius, height, blade width, dry-tip ratio].
const CLUMPS := [[14, 0.025, 0.2, 0.045, 0.1], [16, 0.03, 0.17, 0.042, 0.15], [11, 0.02, 0.22, 0.05, 0.05], [18, 0.035, 0.16, 0.04, 0.25], [13, 0.025, 0.19, 0.046, 0.4], [10, 0.02, 0.18, 0.05, 0.1]]
## Ground paint tones of the terrain shader (green and dry); tufts follow them.
const MEADOW_GREEN := Color(0.34, 0.44, 0.21)
const MEADOW_DRY := Color(0.47, 0.47, 0.28)
## Foliage spreads evenly (no fade-out) between these distances past the layout.
const NEAR := 0.5
const FAR := 14.0
## Must match the terrain shader's grass_scale and macro_scale.
const GRASS_SCALE := 0.11
const MACRO_SCALE := 0.045

var season: Season = Season.NONE
var counts := {"trees": 0, "bushes": 0, "plants": 0, "flowers": 0, "stumps": 0, "logs": 0, "grass": 0, "rocks": 0, "willows": 0, "reeds": 0, "lilypads": 0, "ponds": 0, "streams": 0, "pebbles": 0}
## Streams: Array of [points PackedVector3Array (x, level, z), widths PackedFloat32Array].
var streams: Array = []
## Cells (0.25 tiles) covered by stream water, and the wider bank margin trees avoid.
var _stream_cells: Dictionary = {}
var _bank_cells: Dictionary = {}
## Flower color pairs; each area of the map cycles to one pair (white/cyan favored).
const FLOWER_PAIRS := [["Flowers@white", "Flowers"], ["Flowers@white", "Flowers@yellow"], ["Flowers", "Flowers@violet"], ["Flowers@white", "Flowers@pink"], ["Flowers@white", "Flowers"], ["Flowers@yellow", "Flowers@violet"]]
const PEBBLES := ["Rock_1", "Rock_2", "Rock_3", "Rock_4", "Rock_5", "Rock_6", "Rock_7"]
## Ponds: [center Vector2, radius, water level].
var ponds: Array = []
const WATER := Color(0.27, 0.43, 0.47, 0.8)
const STREAM_WATER := Color(0.22, 0.37, 0.4, 0.86)
const MEADOW_LOW := 0.22
## [kind, model, Transform3D, tint] per instance (headless runs cannot read
## MultiMesh buffers back).
var placements: Array = []
var _settings := {"trees": 1.0, "bushes": 1.0, "plants": 1.0, "flowers": 1.0, "grass": 1.0, "wood": 1.0, "meadow": 1.0, "snow": 0.85}
var _macro: Image
var _meshes: Dictionary = {}
var _buckets: Dictionary = {}
## [StandardMaterial3D, base color] pairs and grass ShaderMaterials, re-shaded
## whenever the terrain's fog shade changes (apply_shade).
var _materials: Array = []
var _grass_materials: Array = []


static func season_named(value: String) -> Season:
	match value.strip_edges().to_lower():
		"summer", "spring", "summer_spring": return Season.SUMMER_SPRING
		"winter": return Season.WINTER
	return Season.NONE


## Places this floor's foliage. `settings`: density multipliers trees, bushes,
## plants, flowers, grass, wood (stumps and logs); meadow and snow amounts.
func populate(scenery: OutOfBoundsScenery, seed_value: int, floor_season: Season, settings: Dictionary = {}) -> void:
	name = "OutOfBoundsFoliage"
	season = floor_season
	_settings.merge(settings, true)
	scenery.material.set_shader_parameter("grass_amount", _settings.meadow if season == Season.SUMMER_SPRING else 0.0)
	scenery.material.set_shader_parameter("snow_amount", _settings.snow if season == Season.WINTER else 0.0)
	if season == Season.NONE: return
	var set: Dictionary = SETS[season]
	var built_in: Dictionary = SEASON_DENSITY[season]
	_macro = RockTextureSet.macro.get_image()
	for i in range(CLUMPS.size()):
		var v: Array = CLUMPS[i]
		var mesh := GrassClump.build(seed_value + i * 17, v[0], v[1], v[2], v[3], v[4])
		_grass_materials.append(mesh.surface_get_material(0))
		_meshes["GrassClump_%d" % i] = mesh
	var tree_density: float = built_in.trees * _settings.trees
	var bush_density: float = built_in.bushes * _settings.bushes
	if season == Season.SUMMER_SPRING:
		_make_ponds(scenery, seed_value)
		_make_streams(scenery, seed_value)
	# Trees: groves where the painted meadow is strongest.
	_scatter(scenery, 1.0, seed_value * 3 + 1, func(x: float, z: float, h: int, d: float) -> void:
		var roll := _rand(h, 3)
		var chance := 0.24 * tree_density
		# Trees keep back from the dungeon edge and pond shores so the ground
		# dressing and water stay visible.
		if d < 2.5 or roll >= chance * meadow(x, z) or near_pond(x, z, 1.1) or _bank_cells.has(_cell(x, z)): return
		if roll >= chance * smoothstep(0.35, 0.8, ground_grass(scenery, x, z)): return
		_place(scenery, set.trees, "trees", x, z, h, d))
	# Bushes: along the meadow edges and scattered in the open.
	_scatter(scenery, 0.75, seed_value * 5 + 2, func(x: float, z: float, h: int, d: float) -> void:
		var roll := _rand(h, 3)
		if d < 0.8 or roll >= 0.45 * bush_density: return
		var g := ground_grass(scenery, x, z)
		var edge := clampf(1.0 - absf(g - 0.4) * 2.5, 0.0, 1.0)
		if roll >= (0.027 + 0.216 * edge) * bush_density: return
		_place(scenery, set.bushes, "bushes", x, z, h, d))
	# Near the dungeon the band has a few more plants (not flowers).
	var near_boost := func(d: float) -> float: return 1.0 + 0.8 * (1.0 - smoothstep(1.0, 4.5, d))
	# Plants: dense on grass, some on bare gentle ground and near the dungeon.
	if not set.plants.is_empty():
		_scatter(scenery, 0.4, seed_value * 7 + 3, func(x: float, z: float, h: int, d: float) -> void:
			var roll := _rand(h, 3)
			var boost: float = near_boost.call(d)
			if d < 0.6 or roll >= 0.45 * boost * _settings.plants: return
			var g := ground_grass(scenery, x, z)
			# Groups of 2-5 (3.5 on average), mostly one species, so the same
			# number of plants grows in natural clumps.
			var chance: float = (0.026 + 0.11 * g) / 3.5 * boost * _settings.plants * (1.0 - smoothstep(0.35, 0.55, _steep(scenery, x, z)))
			if roll >= chance: return
			var main_model: String = set.plants[posmod(h / 7, set.plants.size())]
			for k in range(2 + int(_rand(h, 11) * 4.0)):
				var ph := h * 37 + k * 211 + 3
				var a := _rand(ph, 1) * TAU
				var r := 0.1 + 0.3 * sqrt(_rand(ph, 2))
				var px := x + cos(a) * r
				var pz := z + sin(a) * r
				var pd := scenery.map_distance(px, pz)
				var pick: String = main_model if _rand(ph, 5) < 0.75 else set.plants[posmod(ph / 7, set.plants.size())]
				if pd >= NEAR: _place(scenery, [pick], "plants", px, pz, ph, pd))
	# Flower patches: 3-7 of one color, in and beside the meadows.
	if not set.flowers.is_empty():
		_scatter(scenery, 0.9, seed_value * 19 + 7, func(x: float, z: float, h: int, d: float) -> void:
			var roll := _rand(h, 3)
			if d < 0.8 or roll >= 0.35 * _settings.flowers: return
			var chance: float = (0.024 + 0.145 * ground_grass(scenery, x, z)) * _settings.flowers
			if roll >= chance: return
			_flower_patch(scenery, set.flowers, x, z, h, 0.35, 3 + int(_rand(h, 10) * 5.0)))
	# Grass tufts on the painted meadow.
	if not set.grass.is_empty():
		var dry := Color(MEADOW_DRY.r / MEADOW_GREEN.r, MEADOW_DRY.g / MEADOW_GREEN.g, MEADOW_DRY.b / MEADOW_GREEN.b)
		_scatter(scenery, 0.27, seed_value * 13 + 5, func(x: float, z: float, h: int, d: float) -> void:
			var roll := _rand(h, 3)
			var chance: float = 0.34 * _settings.grass
			if d < 0.55 or roll >= chance * meadow(x, z): return
			if roll >= chance * ground_grass(scenery, x, z): return
			var fine := _sample(Vector2(z, x) * MACRO_SCALE * 4.3 + Vector2(0.37, 0.37)).g
			_place(scenery, set.grass, "grass", x, z, h, d, Color.WHITE.lerp(dry, 0.5 * (1.0 - fine))))
	# Mossy rocks, mostly near the dungeon and at the foot of slopes.
	if not set.rocks.is_empty():
		_scatter(scenery, 0.7, seed_value * 23 + 8, func(x: float, z: float, h: int, d: float) -> void:
			var chance := 0.014 + 0.065 * (1.0 - smoothstep(1.0, 4.5, d))
			if d < 0.6 or _rand(h, 3) >= chance: return
			_place(scenery, set.rocks, "rocks", x, z, h, d))
	# A few stumps, and fallen logs (plain and mossy) lying along the ground.
	_scatter(scenery, 1.6, seed_value * 11 + 4, func(x: float, z: float, h: int, d: float) -> void:
		if d < 1.0 or _rand(h, 3) >= 0.05 * _settings.wood or _steep(scenery, x, z) > 0.3: return
		_place(scenery, set.stumps, "stumps", x, z, h, d))
	_scatter(scenery, 1.8, seed_value * 17 + 6, func(x: float, z: float, h: int, d: float) -> void:
		if d < 1.5 or _rand(h, 3) >= 0.05 * _settings.wood or _steep(scenery, x, z) > 0.15: return
		_place(scenery, set.logs, "logs", x, z, h, d))
	# Pond dressing: lilypads on the water, reeds, flowers and a willow on the shore.
	for i in range(ponds.size()):
		var pond: Array = ponds[i]
		var c: Vector2 = pond[0]
		var r: float = pond[1]
		var level: float = pond[2]
		var ph := seed_value * 977 + i * 7919
		for k in range(40):
			var kh := ph + k * 131
			var a := _rand(kh, 1) * TAU
			var p := c + Vector2(cos(a), sin(a)) * r * sqrt(_rand(kh, 2)) * 0.9
			if counts.lilypads < (i + 1) * 9 and scenery.height_at(p.x, p.y) < level - 0.06:
				var t := Transform3D(Basis(Vector3.UP, _rand(kh, 3) * TAU).scaled(Vector3.ONE * (0.12 + 0.1 * _rand(kh, 4))), Vector3(p.x, level + 0.004, p.y))
				_add("lilypads", "Lilypad", t, Color.WHITE)
		# Walk out from the centre to the shore along rays.
		for k in range(14):
			var kh := ph + 5000 + k * 173
			var a := (k + _rand(kh, 1) * 0.8) / 14.0 * TAU
			var dir := Vector2(cos(a), sin(a))
			var shore := r
			for step in range(1, 21):
				var q := c + dir * r * step / 20.0
				if scenery.height_at(q.x, q.y) > level + 0.02:
					shore = r * step / 20.0
					break
			var q := c + dir * (shore + 0.05 + 0.2 * _rand(kh, 2))
			var d := scenery.map_distance(q.x, q.y)
			if d < NEAR: continue
			var pick := _rand(kh, 3)
			if pick < 0.45: _place(scenery, set.reeds, "reeds", q.x, q.y, kh, d)
			elif pick < 0.8: _flower_patch(scenery, set.flowers, q.x + dir.x * 0.15, q.y + dir.y * 0.15, kh, 0.2, 2 + int(_rand(kh, 4) * 3.0))
			else: _place(scenery, set.plants, "plants", q.x, q.y, kh, d)
		var wa := _rand(ph, 9) * TAU
		var w := c + Vector2(cos(wa), sin(wa)) * (r + 0.6)
		if _rand(ph, 8) < 0.7: _place(scenery, set.willows, "willows", w.x, w.y, ph + 3, scenery.map_distance(w.x, w.y))
	for stream in streams: _dress_stream(scenery, set, stream, seed_value)
	_build_water(scenery)
	for key: String in _buckets:
		var entries: Array = _buckets[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _meshes[key]
		multimesh.instance_count = entries.size()
		for i in range(entries.size()):
			multimesh.set_instance_transform(i, entries[i][0])
			multimesh.set_instance_color(i, entries[i][1])
		var node := MultiMeshInstance3D.new()
		node.name = key.replace("@", "_")
		node.multimesh = multimesh
		# Tufts and flowers are too small for visible shadows; skip the shadow pass.
		var small := key.begins_with("GrassClump") or key.begins_with("Flowers") or key == "Lilypad" or key.begins_with("Rock_") and not key.begins_with("Rock_Moss")
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small or not scenery.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node)
	apply_shade(scenery.current_shade())


## Terrain grass coverage at a point, as the terrain shader paints it (without
## its per-pixel rock bumps): meadow patches cut back on steep, jittered slopes.
func ground_grass(scenery: OutOfBoundsScenery, x: float, z: float) -> float:
	var m := meadow(x, z)
	if m <= 0.0: return 0.0
	var fine := _sample(Vector2(z, x) * MACRO_SCALE * 4.3 + Vector2(0.37, 0.37))
	var broad := _sample(Vector2(x, z) * MACRO_SCALE)
	var jitter := (fine.r - 0.5) * 0.2 + (broad.g - 0.5) * 0.12
	var ny := _normal(scenery, x, z, 0.2).y
	return m * smoothstep(0.58 + jitter, 0.76 + jitter, ny)


func _flower_patch(scenery: OutOfBoundsScenery, flowers: Array, x: float, z: float, h: int, radius: float, amount: int) -> void:
	if flowers.is_empty(): return
	var pair: Array = FLOWER_PAIRS[posmod(int(floor(x / 7.0)) * 73856093 ^ int(floor(z / 7.0)) * 19349663, FLOWER_PAIRS.size())]
	var variant: String = pair[posmod(h / 13, 2)]
	for k in range(amount):
		var fh := h * 31 + k * 7 + 1
		var a := _rand(fh, 1) * TAU
		var r := radius * sqrt(_rand(fh, 2))
		var fx := x + cos(a) * r
		var fz := z + sin(a) * r
		var fd := scenery.map_distance(fx, fz)
		if fd >= NEAR: _place(scenery, [variant], "flowers", fx, fz, fh, fd)


## Ponds in natural hollows of the lowland. The water level sits just
## under the lowest point of a ring around the hollow, so the shore follows the
## terrain and the water never shows a floating edge.
func _make_ponds(scenery: OutOfBoundsScenery, seed_value: int) -> void:
	var candidates: Array = []
	var region := scenery.region
	for row in range(int(region.size.y / 0.8)):
		for column in range(int(region.size.x / 0.8)):
			var h := seed_value * 4241 + column * 92821 + row * 68917
			var c := Vector2(region.position.x + (column + _rand(h, 1)) * 0.8, region.position.y + (row + _rand(h, 2)) * 0.8)
			var d := scenery.map_distance(c.x, c.y)
			if d < 2.5 or d > 11.0: continue
			var r := 0.9 + 0.8 * _rand(h, 3)
			var ring := INF
			for k in range(40):
				var a := k / 40.0 * TAU
				ring = minf(ring, scenery.height_at(c.x + cos(a) * r, c.y + sin(a) * r))
			var level := ring - 0.04
			var depth := level - scenery.height_at(c.x, c.y)
			if depth > 0.08: candidates.append([depth, c, r, level])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for candidate in candidates:
		if ponds.size() >= 7: break
		var clear := true
		for pond in ponds:
			if (pond[0] as Vector2).distance_to(candidate[1]) < pond[1] + candidate[2] + 1.5: clear = false
		if clear: ponds.append([candidate[1], candidate[2], candidate[3]])
	counts.ponds = ponds.size()


func near_pond(x: float, z: float, margin: float) -> bool:
	for pond in ponds:
		if (pond[0] as Vector2).distance_to(Vector2(x, z)) < pond[1] + margin: return true
	return false


func in_water(scenery: OutOfBoundsScenery, x: float, z: float) -> bool:
	if _stream_cells.has(_cell(x, z)): return true
	for pond in ponds:
		if (pond[0] as Vector2).distance_to(Vector2(x, z)) < pond[1] and scenery.height_at(x, z) < pond[2] + 0.03: return true
	return false


func _build_water(scenery: OutOfBoundsScenery) -> void:
	if ponds.is_empty() and streams.is_empty(): return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stream in streams:
		var points: PackedVector3Array = stream[0]
		var widths: PackedFloat32Array = stream[1]
		for i in range(points.size() - 1):
			var quad := []
			for j in [i, i + 1]:
				var forward := (points[mini(j + 1, points.size() - 1)] - points[maxi(j - 1, 0)])
				var side := Vector3(-forward.z, 0.0, forward.x).normalized() * widths[j] * 0.5
				quad.append([points[j] - side, points[j] + side])
			st.set_normal(Vector3.UP)
			for v in [quad[0][0], quad[1][0], quad[0][1], quad[0][1], quad[1][0], quad[1][1]]: st.add_vertex(v)
	_water_node(st, "Streams", STREAM_WATER)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pond in ponds:
		var c: Vector2 = pond[0]
		var r: float = pond[1]
		var level: float = pond[2]
		for k in range(40):
			var a0 := k / 40.0 * TAU
			var a1 := (k + 1) / 40.0 * TAU
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(c.x, level, c.y))
			st.add_vertex(Vector3(c.x + cos(a1) * r, level, c.y + sin(a1) * r))
			st.add_vertex(Vector3(c.x + cos(a0) * r, level, c.y + sin(a0) * r))
	_water_node(st, "Ponds", WATER)


func _water_node(st: SurfaceTool, node_name: String, color: Color) -> void:
	var water := MeshInstance3D.new()
	water.name = node_name
	water.mesh = st.commit()
	if water.mesh == null or water.mesh.get_surface_count() == 0: return
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.roughness = 0.08
	m.metallic_specular = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_materials.append([m, Color(color.r, color.g, color.b)])
	add_child(water)


## Darkens foliage by the terrain's (lifted) fog shade so it sits in the same
## light as the ground; OutOfBoundsScenery.apply_shade forwards every change.
func apply_shade(shade: Color) -> void:
	for entry: Array in _materials:
		var base: Color = entry[1]
		entry[0].albedo_color = Color(base.r * shade.r, base.g * shade.g, base.b * shade.b, entry[0].albedo_color.a)
	for material: ShaderMaterial in _grass_materials:
		material.set_shader_parameter("shade", Color(shade.r, shade.g, shade.b))


## Meadow strength at a world point, read from the same macro noise texture and
## mapping the terrain shader uses for its grass.
func meadow(x: float, z: float) -> float:
	return smoothstep(MEADOW_LOW, MEADOW_LOW + 0.22, _sample(Vector2(x, z) * GRASS_SCALE + Vector2(0.61, 0.13)).r)


func _scatter(scenery: OutOfBoundsScenery, cell: float, salt: int, rule: Callable) -> void:
	var region := scenery.region
	for row in range(int(region.size.y / cell)):
		for column in range(int(region.size.x / cell)):
			var h := salt * 7919 + column * 92821 + row * 68917
			var x := region.position.x + (column + _rand(h, 1)) * cell
			var z := region.position.y + (row + _rand(h, 2)) * cell
			var d := scenery.map_distance(x, z)
			if d < NEAR or d > FAR: continue
			rule.call(x, z, h, d)


func _normal(scenery: OutOfBoundsScenery, x: float, z: float, e: float) -> Vector3:
	return Vector3(-(scenery.height_at(x + e, z) - scenery.height_at(x - e, z)), 2.0 * e, -(scenery.height_at(x, z + e) - scenery.height_at(x, z - e))).normalized()


func _steep(scenery: OutOfBoundsScenery, x: float, z: float) -> float:
	return 1.0 - _normal(scenery, x, z, 0.2).y


func _mesh(model: String) -> Mesh:
	if _meshes.has(model): return _meshes[model]
	var file := model.get_slice("@", 0)
	var petal := model.get_slice("@", 1) if "@" in model else ""
	var source: Mesh = load(DIR % file)
	var mesh := ArrayMesh.new()
	for i in range(source.get_surface_count()):
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(i))
		var authored := source.surface_get_material(i)
		var m := StandardMaterial3D.new()
		# Blender writes Kd in linear; Godot reads it as sRGB.
		var base: Color = (authored.albedo_color if authored is StandardMaterial3D else Color.GRAY).linear_to_srgb()
		if authored != null and authored.resource_name == "Snow": base = SNOW
		if petal != "" and authored != null and authored.resource_name == "Cyan": base = PETALS[petal]
		m.albedo_color = base
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		mesh.surface_set_material(i, m)
		_materials.append([m, base])
	_meshes[model] = mesh
	return mesh


func _place(scenery: OutOfBoundsScenery, models: Array, kind: String, x: float, z: float, h: int, d: float, tint_scale := Color.WHITE) -> void:
	if models.is_empty() or in_water(scenery, x, z): return
	var model: String = models[posmod(h / 7, models.size())]
	var mesh := _mesh(model)
	var bounds := mesh.get_aabb()
	var scale: float = HEIGHTS[kind] / maxf(bounds.size.y, 0.01) * (0.75 + 0.5 * _rand(h, 4))
	var y := scenery.height_at(x, z)
	# Near the rim nothing rises far above map level, so the player stays clear.
	var top := y + bounds.end.y * scale
	var limit := scenery.ground_level + (0.25 if kind == "trees" else 0.0)
	if d < 3.0 and top > limit:
		scale *= (limit - y) / maxf(top - y, 0.01)
		if scale <= 0.0 or (kind == "trees" and bounds.size.y * scale < 0.9): return
	var basis := Basis(Vector3.UP, _rand(h, 6) * TAU)
	if kind == "grass" or kind == "logs" or kind == "rocks":
		# Tufts lean partly with the slope (their lighting normal follows it);
		# logs lie fully along it.
		var n := _normal(scenery, x, z, 0.15)
		basis = Basis(Quaternion(Vector3.UP, Vector3.UP.slerp(n, 1.0 if kind == "logs" else 0.7).normalized())) * basis
	basis = basis.scaled(Vector3.ONE * scale)
	var v := 0.9 + 0.2 * _rand(h, 7)
	var tint := Color(v * (0.97 + 0.06 * _rand(h, 8)) * tint_scale.r, v * tint_scale.g, v * (0.97 + 0.06 * _rand(h, 9)) * tint_scale.b, 1.0)
	var origin := Vector3(x, y - {"grass": 0.015, "logs": 0.07, "rocks": 0.08}.get(kind, 0.04), z)
	_add(kind, model, Transform3D(basis, origin), tint)


func _add(kind: String, model: String, transform: Transform3D, tint: Color) -> void:
	_mesh(model)
	if not _buckets.has(model): _buckets[model] = []
	_buckets[model].append([transform, tint])
	placements.append([kind, model, transform, tint])
	counts[kind] += 1


## Bilinear, repeating read of the macro noise texture, as the shader samples it.
func _sample(uv: Vector2) -> Color:
	var size := Vector2i(_macro.get_width(), _macro.get_height())
	var p := Vector2(fposmod(uv.x, 1.0) * size.x, fposmod(uv.y, 1.0) * size.y) - Vector2(0.5, 0.5)
	var i := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(i)
	var a := _macro.get_pixel(posmod(i.x, size.x), posmod(i.y, size.y))
	var b := _macro.get_pixel(posmod(i.x + 1, size.x), posmod(i.y, size.y))
	var c := _macro.get_pixel(posmod(i.x, size.x), posmod(i.y + 1, size.y))
	var e := _macro.get_pixel(posmod(i.x + 1, size.x), posmod(i.y + 1, size.y))
	return a.lerp(b, f.x).lerp(c.lerp(e, f.x), f.y)


func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x * 4.0), floori(z * 4.0))


## Winding streams. Each starts on higher ground in the band and
## walks downhill (gradient plus a slow meander), ending in a pond, at a hollow
## or after a length limit. The water sits just above the lowest of its bed and
## banks and never rises downstream, so it follows the valley floor.
func _make_streams(scenery: OutOfBoundsScenery, seed_value: int) -> void:
	var region := scenery.region
	var starts: Array = []
	for row in range(int(region.size.y / 1.5)):
		for column in range(int(region.size.x / 1.5)):
			var h := seed_value * 6151 + column * 92821 + row * 68917
			var p := Vector2(region.position.x + (column + _rand(h, 1)) * 1.5, region.position.y + (row + _rand(h, 2)) * 1.5)
			var d := scenery.map_distance(p.x, p.y)
			if d < 3.5 or d > 9.0 or _steep(scenery, p.x, p.y) > 0.25: continue
			starts.append([scenery.height_at(p.x, p.y) + _rand(h, 3) * 0.4, p, h])
	starts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for start in starts:
		if streams.size() >= 2: break
		var p: Vector2 = start[1]
		if _bank_cells.has(_cell(p.x, p.y)) or near_pond(p.x, p.y, 1.0): continue
		var path: Array = [p]
		var direction := Vector2.ZERO
		var lowest := scenery.height_at(p.x, p.y)
		var phase := _rand(start[2], 4) * TAU
		for step in range(160):
			var n := _normal(scenery, p.x, p.y, 0.3)
			var downhill := Vector2(n.x, n.z)
			if downhill.length() > 0.02: downhill = downhill.normalized()
			elif direction != Vector2.ZERO: downhill = direction
			else: break
			if direction == Vector2.ZERO: direction = downhill
			direction = direction.lerp(downhill, 0.3).normalized()
			var meander := direction.orthogonal() * sin(step * 0.18 + phase) * 0.45
			p += (direction + meander).normalized() * 0.2
			var height := scenery.height_at(p.x, p.y)
			var d := scenery.map_distance(p.x, p.y)
			if d < 1.8 or d > 13.0 or height > lowest + 0.12: break
			lowest = minf(lowest, height)
			path.append(p)
			if near_pond(p.x, p.y, -0.3): break
		if path.size() < 30: continue
		# Smooth the walk, then set widths and water levels.
		for pass_index in range(3):
			for i in range(1, path.size() - 1):
				path[i] = path[i - 1] * 0.25 + path[i] * 0.5 + path[i + 1] * 0.25
		var points := PackedVector3Array()
		var widths := PackedFloat32Array()
		var level := INF
		for i in range(path.size()):
			var q: Vector2 = path[i]
			var forward: Vector2 = path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]
			var side := forward.orthogonal().normalized()
			var t := float(i) / (path.size() - 1)
			var width := (0.28 + 0.14 * _rand(int(start[2]) + i / 6, 5)) * smoothstep(0.0, 0.12, t)
			var low := minf(scenery.height_at(q.x, q.y), minf(scenery.height_at(q.x + side.x * width * 0.5, q.y + side.y * width * 0.5), scenery.height_at(q.x - side.x * width * 0.5, q.y - side.y * width * 0.5)))
			level = minf(level, low + 0.025)
			points.append(Vector3(q.x, level, q.y))
			widths.append(width)
			for ox in range(-3, 4):
				for oz in range(-3, 4):
					var cell := _cell(q.x + ox * 0.25, q.y + oz * 0.25)
					var reach := Vector2(ox, oz).length() * 0.25
					if reach <= width * 0.5 + 0.05: _stream_cells[cell] = true
					_bank_cells[cell] = true
		streams.append([points, widths])
	counts.streams = streams.size()


## Pebbles along both banks and in the bed, reeds/plants/flowers here and there.
func _dress_stream(scenery: OutOfBoundsScenery, set: Dictionary, stream: Array, seed_value: int) -> void:
	var points: PackedVector3Array = stream[0]
	var widths: PackedFloat32Array = stream[1]
	for i in range(1, points.size() - 1):
		var h := seed_value * 3571 + i * 7919 + int(points[i].x * 31.0)
		var forward := points[i + 1] - points[i - 1]
		var side := Vector3(-forward.z, 0.0, forward.x).normalized()
		for bank in [-1.0, 1.0]:
			var bh := h + (1 if bank > 0.0 else 2) * 104729
			var roll := _rand(bh, 1)
			var offset: float = bank * (widths[i] * 0.5 + 0.04 + 0.12 * _rand(bh, 2))
			var q := points[i] + side * offset
			if roll < 0.32:
				var pebble: String = PEBBLES[posmod(bh / 7, PEBBLES.size())]
				var mesh := _mesh(pebble)
				var size := (0.5 + _rand(bh, 3)) * HEIGHTS.pebbles / maxf(mesh.get_aabb().size.y, 0.01)
				var y := scenery.height_at(q.x, q.z)
				_add("pebbles", pebble, Transform3D(Basis(Vector3.UP, _rand(bh, 4) * TAU).scaled(Vector3.ONE * size), Vector3(q.x, y - 0.02, q.z)), Color(1.0, 1.0, 1.0) * (0.9 + 0.2 * _rand(bh, 5)))
			elif roll < 0.38: _place(scenery, set.reeds, "reeds", q.x + side.x * bank * 0.08, q.z + side.z * bank * 0.08, bh, scenery.map_distance(q.x, q.z))
			elif roll < 0.43: _place(scenery, set.plants, "plants", q.x + side.x * bank * 0.15, q.z + side.z * bank * 0.15, bh, scenery.map_distance(q.x, q.z))
			elif roll < 0.46: _flower_patch(scenery, set.flowers, q.x + side.x * bank * 0.25, q.z + side.z * bank * 0.25, bh, 0.15, 2 + int(_rand(bh, 6) * 2.0))
		# A few stones in the water itself.
		if _rand(h, 7) < 0.12:
			var pebble: String = PEBBLES[posmod(h / 11, PEBBLES.size())]
			var mesh := _mesh(pebble)
			var q := points[i] + side * (_rand(h, 8) - 0.5) * widths[i] * 0.6
			var size := (0.6 + 0.6 * _rand(h, 9)) * HEIGHTS.pebbles / maxf(mesh.get_aabb().size.y, 0.01)
			_add("pebbles", pebble, Transform3D(Basis(Vector3.UP, _rand(h, 10) * TAU).scaled(Vector3.ONE * size), Vector3(q.x, points[i].y - 0.03, q.z)), Color.WHITE)


static func _rand(seed_value: int, salt: int) -> float:
	return BridgePlanks._rand(seed_value, salt)
