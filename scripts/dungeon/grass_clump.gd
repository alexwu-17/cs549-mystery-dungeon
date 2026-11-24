class_name GrassClump
extends RefCounted
## Procedural low-poly grass tuft for the out-of-bounds meadows. Blades arch out
## from a tight base and droop at the tip (two segments and a point, three
## triangles each), colored from a darker root to a lighter tip. Rendering only;
## all variation comes from the given seed, never gameplay RNG.

const SHADER := preload("res://shaders/grass_clump.gdshader")
## Vertex colors are sRGB; the shader converts them.
const ROOT := Color(0.36, 0.46, 0.2)
const TIP := Color(0.63, 0.74, 0.35)
const DRY_TIP := Color(0.71, 0.71, 0.45)


## A tuft of `blades` blades from a base of `radius`, about `height` tall before
## the arch, base width `width`; `dry_ratio` of the blades get a straw tip.
## The material's `shade` parameter is set by the owner (OutOfBoundsFoliage).
static func build(seed_value: int, blades: int, radius: float, height: float, width: float, dry_ratio: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for b in range(blades):
		var h := seed_value * 131 + b * 977
		var angle := _rand(h, 1) * TAU
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var base := outward * radius * sqrt(_rand(h, 2))
		# Long blades reach far and droop low; short ones stay more upright.
		var spread := _rand(h, 5)
		var tall := height * (0.6 + 0.4 * _rand(h, 4))
		var reach := tall * lerpf(0.3, 1.15, spread)
		var tip_height := tall * lerpf(0.9, 0.25, spread)
		var control := base + Vector3(0.0, tall * 1.05, 0.0) + outward * reach * 0.15
		var tip := base + outward * reach + Vector3(0.0, tip_height, 0.0)
		var mid := base * 0.25 + control * 0.5 + tip * 0.25
		# Blade width runs across the arch, so the faces turn to the sky and the
		# tuft reads from the gameplay camera.
		var twist := angle + PI * 0.5 + (_rand(h, 3) - 0.5) * 0.5
		var side := Vector3(cos(twist), 0.0, sin(twist))
		var w := width * (0.7 + 0.6 * _rand(h, 6))
		var bright := 0.88 + 0.24 * _rand(h, 8)
		var tip_color: Color = (DRY_TIP if _rand(h, 7) < dry_ratio else TIP) * bright
		var root_color := ROOT * (0.9 + 0.2 * _rand(h, 9))
		var mid_color := root_color.lerp(tip_color, 0.6)
		var p := [base - side * w * 0.5, base + side * w * 0.5, mid - side * w * 0.4, mid + side * w * 0.4, tip]
		var c := [root_color, root_color, mid_color, mid_color, tip_color]
		for tri in [[0, 2, 1], [1, 2, 3], [2, 4, 3]]:
			for k: int in tri:
				vertices.append(p[k])
				colors.append(c[k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	mesh.surface_set_material(0, material)
	return mesh


static func _rand(seed_value: int, salt: int) -> float:
	return BridgePlanks._rand(seed_value, salt)
