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
	},
	Season.WINTER: {
		"trees": ["CommonTree_Snow_1", "CommonTree_Snow_2", "CommonTree_Snow_4", "CommonTree_Snow_5", "PineTree_Snow_1", "PineTree_Snow_2", "PineTree_Snow_3", "PineTree_Snow_5", "BirchTree_Snow_1", "BirchTree_Snow_5", "CommonTree_Dead_Snow_1", "CommonTree_Dead_Snow_2", "BirchTree_Dead_Snow_1", "BirchTree_Dead_Snow_3"],
		"bushes": ["Bush_Snow_1", "Bush_Snow_2"],
		"plants": [],
		"flowers": [],
		"stumps": ["TreeStump_Snow"],
		"logs": ["WoodLog_Snow"],
		"grass": [],
	},
}
## Built-in per-season density (winter has far fewer bushes and no plants).
const SEASON_DENSITY := {Season.SUMMER_SPRING: {"trees": 0.75, "bushes": 0.65}, Season.WINTER: {"trees": 0.75, "bushes": 0.3}}
## Target heights in tiles per kind, before per-instance jitter (0.75-1.25).
const HEIGHTS := {"trees": 2.0, "bushes": 0.55, "plants": 0.3, "flowers": 0.24, "stumps": 0.35, "logs": 0.3, "grass": 0.13}
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
var counts := {"trees": 0, "bushes": 0, "plants": 0, "flowers": 0, "stumps": 0, "logs": 0, "grass": 0}
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
	# Each rule rolls once against its chance before the slope is measured; the
	# slope factor (<= 1) then only lowers it, so cheap rejects skip the normal.
	# Trees: groves on gentle ground where the meadow is strongest.
	_scatter(scenery, 1.1, seed_value * 3 + 1, func(x: float, z: float, h: int, d: float) -> void:
		var roll := _rand(h, 3)
		var chance := smoothstep(0.5, 0.85, meadow(x, z)) * 0.6 * tree_density
		if d < 1.2 or roll >= chance or roll >= chance * (1.0 - smoothstep(0.22, 0.4, _steep(scenery, x, z))): return
		_place(scenery, set.trees, "trees", x, z, h, d))
	# Bushes: along meadow edges and scattered in the open.
	_scatter(scenery, 0.8, seed_value * 5 + 2, func(x: float, z: float, h: int, d: float) -> void:
		var roll := _rand(h, 3)
		var edge := clampf(1.0 - absf(meadow(x, z) - 0.45) * 3.0, 0.0, 1.0)
		var chance := (0.04 + 0.35 * edge) * bush_density
		if d < 0.8 or roll >= chance or roll >= chance * (1.0 - smoothstep(0.3, 0.5, _steep(scenery, x, z))): return
		_place(scenery, set.bushes, "bushes", x, z, h, d))
	# Plants: dense in meadows, a few on bare gentle ground to break up the rock.
	if not set.plants.is_empty():
		_scatter(scenery, 0.45, seed_value * 7 + 3, func(x: float, z: float, h: int, d: float) -> void:
			var roll := _rand(h, 3)
			var chance: float = (0.05 + 0.28 * smoothstep(0.35, 0.7, meadow(x, z))) * _settings.plants
			if d < 0.6 or roll >= chance or roll >= chance * (1.0 - smoothstep(0.3, 0.5, _steep(scenery, x, z))): return
			_place(scenery, set.plants, "plants", x, z, h, d))
	# Flower patches: 3-7 flowers of one color around a point, in and beside meadows.
	if not set.flowers.is_empty():
		_scatter(scenery, 1.0, seed_value * 19 + 7, func(x: float, z: float, h: int, d: float) -> void:
			var roll := _rand(h, 3)
			var chance: float = (0.06 + 0.3 * smoothstep(0.25, 0.6, meadow(x, z))) * _settings.flowers
			if d < 0.8 or roll >= chance or roll >= chance * (1.0 - smoothstep(0.25, 0.4, _steep(scenery, x, z))): return
			var variant: String = set.flowers[posmod(h / 13, set.flowers.size())]
			for k in range(3 + int(_rand(h, 10) * 5.0)):
				var fh := h * 31 + k * 7 + 1
				var a := _rand(fh, 1) * TAU
				var r := 0.35 * sqrt(_rand(fh, 2))
				var fx := x + cos(a) * r
				var fz := z + sin(a) * r
				var fd := scenery.map_distance(fx, fz)
				if fd >= NEAR: _place(scenery, [variant], "flowers", fx, fz, fh, fd))
	# Grass tufts over the meadows: the ground the groves grow from.
	if not set.grass.is_empty():
		var dry := Color(MEADOW_DRY.r / MEADOW_GREEN.r, MEADOW_DRY.g / MEADOW_GREEN.g, MEADOW_DRY.b / MEADOW_GREEN.b)
		_scatter(scenery, 0.3, seed_value * 13 + 5, func(x: float, z: float, h: int, d: float) -> void:
			var roll := _rand(h, 3)
			var chance: float = 0.8 * smoothstep(0.25, 0.6, meadow(x, z)) * _settings.grass
			if d < 0.55 or roll >= chance or roll >= chance * (1.0 - smoothstep(0.2, 0.32, _steep(scenery, x, z))): return
			# Follow the ground paint's dry/green patches (the shader's macro_fine.y).
			var fine := _sample(Vector2(z, x) * MACRO_SCALE * 4.3 + Vector2(0.37, 0.37)).g
			_place(scenery, set.grass, "grass", x, z, h, d, Color.WHITE.lerp(dry, 0.5 * (1.0 - fine))))
	# A few stumps, and fallen logs (plain and mossy) lying along the ground.
	_scatter(scenery, 1.6, seed_value * 11 + 4, func(x: float, z: float, h: int, d: float) -> void:
		if d < 1.0 or _rand(h, 3) >= 0.04 * _settings.wood or _steep(scenery, x, z) > 0.3: return
		_place(scenery, set.stumps, "stumps", x, z, h, d))
	_scatter(scenery, 1.8, seed_value * 17 + 6, func(x: float, z: float, h: int, d: float) -> void:
		if d < 1.5 or _rand(h, 3) >= 0.04 * _settings.wood or _steep(scenery, x, z) > 0.15: return
		_place(scenery, set.logs, "logs", x, z, h, d))
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
		var small := key.begins_with("GrassClump") or key.begins_with("Flowers")
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small or not scenery.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node)
	apply_shade(scenery.current_shade())


## Darkens foliage by the terrain's (lifted) fog shade so it sits in the same
## light as the ground; OutOfBoundsScenery.apply_shade forwards every change.
func apply_shade(shade: Color) -> void:
	for entry: Array in _materials:
		var base: Color = entry[1]
		entry[0].albedo_color = Color(base.r * shade.r, base.g * shade.g, base.b * shade.b, 1.0)
	for material: ShaderMaterial in _grass_materials:
		material.set_shader_parameter("shade", Color(shade.r, shade.g, shade.b))


## Meadow strength at a world point, read from the same macro noise texture and
## mapping the terrain shader uses for its grass.
func meadow(x: float, z: float) -> float:
	return smoothstep(0.38, 0.62, _sample(Vector2(x, z) * GRASS_SCALE + Vector2(0.61, 0.13)).r)


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
	if kind == "grass" or kind == "logs":
		# Tufts lean partly with the slope (their lighting normal follows it);
		# logs lie fully along it.
		var n := _normal(scenery, x, z, 0.15)
		basis = Basis(Quaternion(Vector3.UP, Vector3.UP.slerp(n, 0.7 if kind == "grass" else 1.0).normalized())) * basis
	basis = basis.scaled(Vector3.ONE * scale)
	var v := 0.9 + 0.2 * _rand(h, 7)
	var tint := Color(v * (0.97 + 0.06 * _rand(h, 8)) * tint_scale.r, v * tint_scale.g, v * (0.97 + 0.06 * _rand(h, 9)) * tint_scale.b, 1.0)
	var origin := Vector3(x, y - {"grass": 0.015, "logs": 0.07}.get(kind, 0.04), z)
	if not _buckets.has(model): _buckets[model] = []
	_buckets[model].append([Transform3D(basis, origin), tint])
	placements.append([kind, model, Transform3D(basis, origin), tint])
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


static func _rand(seed_value: int, salt: int) -> float:
	return BridgePlanks._rand(seed_value, salt)
