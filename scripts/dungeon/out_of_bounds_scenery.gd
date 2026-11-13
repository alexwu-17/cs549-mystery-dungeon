class_name OutOfBoundsScenery
extends Node3D
## Decorative ridge models beyond the logical map. Rendering only: no tiles,
## elevations, spawns, traversal or generator RNG are read for placement choices
## other than coordinate hashing. Three batched MultiMesh nodes, no per-cell nodes.

const MODELS: Array[Mesh] = [
	preload("res://assets/environment/out_of_bounds/oob_1.obj"),
	preload("res://assets/environment/out_of_bounds/oob_2.obj"),
	preload("res://assets/environment/out_of_bounds/oob_3.obj"),
]
const SHADER = preload("res://shaders/out_of_bounds_spring.gdshader")
const NEAR_FOOTPRINT := 2
const FAR_FOOTPRINT := 4
const CHUNK_SIZE := 16
var batches: Array[MultiMeshInstance3D] = []
var material: ShaderMaterial
var placements: Array[Dictionary] = []
var diagnostics := {"near": 0, "far": 0, "triangles": 0, "mesh_nodes": 0}
var shade_lift: float = 0.0
var _shade := Color.WHITE


func setup(data: DungeonData, backdrop: CaveTerrainBackdrop, renderer: DungeonRenderer) -> void:
	set_meta("geometry_purpose", "out_of_bounds_scenery")
	shade_lift = renderer.out_of_bounds_shade_lift
	material = ShaderMaterial.new()
	material.shader = SHADER
	var tops: Dictionary = {}
	for record in backdrop.records:
		if record.external: tops[record.cell] = float(record.top)
	var detailed: Rect2i = backdrop.get_meta("geometry_bounds")
	var outer: Rect2i = backdrop.scenery_apron.visual_bounds if is_instance_valid(backdrop.scenery_apron) else detailed
	# The apron guard follows the camera and can be very large; instance counts must not.
	outer = outer.intersection(detailed.grow(renderer.out_of_bounds_far_extent))
	var apron_top := TerrainFillVisuals.wall_top_offset(0.1, 0.5)
	# Near band: every whole 2x2 block of detailed external cells. Far band: 4x4
	# blocks over the apron, thinned by hash so the horizon stays irregular.
	_plan_band(detailed, data.map_bounds, data.map_bounds, NEAR_FOOTPRINT, 1.0, tops, apron_top, renderer, false)
	_plan_band(outer, detailed, data.map_bounds, FAR_FOOTPRINT, renderer.out_of_bounds_far_density, tops, apron_top, renderer, true)
	# One MultiMesh per (spatial chunk, model): a map-wide MultiMesh cannot be
	# frustum-culled, so distant off-screen ridges would always be drawn.
	var groups: Dictionary = {}
	for index in range(placements.size()):
		var block: Rect2i = placements[index].block
		var key := Vector3i(floori(float(block.position.x) / CHUNK_SIZE), floori(float(block.position.y) / CHUNK_SIZE), placements[index].model)
		if not groups.has(key): groups[key] = []
		groups[key].append(index)
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var node := MultiMeshInstance3D.new()
		node.name = "OutOfBoundsRidges_%d_%d_m%d" % [key.x, key.y, key.z + 1]
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = MODELS[key.z]
		node.multimesh.instance_count = groups[key].size()
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("geometry_purpose", "out_of_bounds_scenery")
		add_child(node)
		batches.append(node)
		for local_index in range(groups[key].size()):
			var index: int = groups[key][local_index]
			node.multimesh.set_instance_transform(local_index, placements[index].transform)
			placements[index]["batch"] = batches.size() - 1
			placements[index]["instance"] = local_index
			diagnostics.triangles += MODELS[key.z].get_faces().size() / 3
	diagnostics.mesh_nodes = batches.size()
	set_meta("geometry_bounds", outer)


func _plan_band(bounds: Rect2i, excluded: Rect2i, map_bounds: Rect2i, footprint: int, density: float, tops: Dictionary, apron_top: float, renderer: DungeonRenderer, far: bool) -> void:
	# Align the block grid to the excluded rectangle so blocks sit flush against it;
	# blocks that would straddle it or leave the band are skipped.
	var offset := excluded.position - bounds.position
	var start := excluded.position - Vector2i((offset.x + footprint - 1) / footprint, (offset.y + footprint - 1) / footprint) * footprint
	var y := start.y
	while y + footprint <= bounds.end.y:
		var x := start.x
		while x + footprint <= bounds.end.x:
			var block := Rect2i(x, y, footprint, footprint)
			x += footprint
			if block.intersects(excluded) or not bounds.encloses(block): continue
			# The fixed camera looks north from south of the player. Ridges south of
			# the map would stand between the camera and the play area, so the
			# foreground band stays flat ground.
			if renderer.out_of_bounds_foreground_clear and block.end.y > map_bounds.end.y: continue
			var hash_value := renderer.floor_hash(block.position + Vector2i(7919, 104729) * footprint)
			if density < 1.0 and float(posmod(hash_value / 64, 1000)) / 1000.0 >= density: continue
			var top := apron_top
			for cy in range(block.position.y, block.end.y):
				for cx in range(block.position.x, block.end.x):
					top = maxf(top, float(tops.get(Vector2i(cx, cy), apron_top)))
			var model := posmod(hash_value, MODELS.size())
			var quarter_turns := posmod(hash_value / 4, 4)
			var aabb := MODELS[model].get_aabb()
			var scale := float(footprint) * DungeonData.TILE_SIZE / maxf(aabb.size.x, aabb.size.z)
			var basis := Basis(Vector3.UP, quarter_turns * PI / 2.0).scaled(Vector3(scale, scale * renderer.out_of_bounds_height_scale, scale))
			var center := Vector3(block.position.x + (footprint - 1) * 0.5, top, block.position.y + (footprint - 1) * 0.5)
			# Center the authored mesh on its block and rest its lowest vertex on the ground top.
			var local_center := Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
			var transform := Transform3D(basis, center - basis * local_center)
			placements.append({"block": block, "model": model, "transform": transform, "far": far, "top": top})
			if far: diagnostics.far += 1
			else: diagnostics.near += 1
		y += footprint


func apply_shade(shade: Color) -> void:
	if material == null: return
	# Distant ridges are sky-lit: lift the border palette toward white by a fixed share.
	_shade = shade.lerp(Color.WHITE, shade_lift)
	_shade.a = 1.0
	material.set_shader_parameter("fog_shade", Vector3(_shade.r, _shade.g, _shade.b))


func current_shade() -> Color:
	return _shade
