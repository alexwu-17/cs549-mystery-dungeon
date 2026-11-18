extends SceneTree
## Owns: decorative out-of-bounds ridge placement (never over the logical map,
## inside the apron bounds, deterministic, batched), fog shade lift, toggles
## and fixture exemptions, plus tree/bush vegetation on the ridges. Appearance
## needs a normal-render check by the user.
const Snapshots = preload("res://tests/validate_terraces.gd")
const CameraScript = preload("res://scripts/core/presentation_camera.gd")
func _initialize() -> void: call_deferred("validate")

func transforms(scenery: OutOfBoundsScenery) -> Array:
	var result: Array = []
	for placement in scenery.placements: result.append([placement.block, placement.model, placement.transform, placement.far])
	for item in scenery.vegetation: result.append([item.kind, item.block, item.transform, item.color])
	return result


func check_vegetation(scenery: OutOfBoundsScenery, renderer: DungeonRenderer, data: DungeonData) -> void:
	assert(scenery.diagnostics.trees > 0 and scenery.diagnostics.bushes > 0)
	assert(scenery.vegetation.size() == scenery.diagnostics.trees + scenery.diagnostics.bushes)
	var ridge_blocks: Dictionary = {}
	for placement in scenery.placements: ridge_blocks[placement.block] = placement
	var map_rect := Rect2(Vector2(data.map_bounds.position) - Vector2.ONE * 0.5, Vector2(data.map_bounds.size))
	var instances := 0
	var blossoms := 0
	for batch in scenery.vegetation_batches:
		assert(batch.multimesh.use_colors and batch.material_override == null)
		assert(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert(batch.get_meta("geometry_purpose") == "out_of_bounds_vegetation")
		instances += batch.multimesh.instance_count
	assert(instances == scenery.vegetation.size())
	for item in scenery.vegetation:
		var mesh: Mesh = OutOfBoundsScenery.TREE if item.kind == "tree" else OutOfBoundsScenery.BUSH
		# Only on ridge blocks (never over or south of the map); bushes only on the near band.
		assert(ridge_blocks.has(item.block) and ridge_blocks[item.block].far == item.far)
		if item.kind == "bush": assert(not item.far)
		var block: Rect2i = item.block
		var point: Vector3 = item.point
		assert(point.x > block.position.x - 0.5 and point.x < block.end.x - 0.5 and point.z > block.position.y - 0.5 and point.z < block.end.y - 0.5)
		# The surface point lies on the ridge above its ground top, and the whole canopy clears the map.
		assert(point.y > float(item.ground))
		var flat := Vector2(point.x, point.z)
		var gap := Vector2(maxf(maxf(map_rect.position.x - flat.x, flat.x - map_rect.end.x), 0.0), maxf(maxf(map_rect.position.y - flat.y, flat.y - map_rect.end.y), 0.0)).length()
		assert(gap >= float(item.radius))
		# Z-up source turns upright, its base center lands just below the surface point, height in range.
		var transform: Transform3D = item.transform
		assert((transform.basis * Vector3(0, 0, 1)).normalized().dot(Vector3.UP) > 0.999)
		assert((transform * OutOfBoundsScenery.vegetation_base(mesh)).is_equal_approx(point - Vector3.UP * OutOfBoundsScenery.SINK))
		var bounds: AABB = transform * mesh.get_aabb()
		var target: float = renderer.out_of_bounds_tree_height * (1.0 if item.kind == "tree" else OutOfBoundsScenery.BUSH_HEIGHT_SHARE)
		assert(is_equal_approx(bounds.size.y, float(item.height)) and item.height >= target * 0.8 - 0.001 and item.height <= target * 1.2 + 0.001)
		var batch_node: MultiMeshInstance3D = scenery.vegetation_batches[item.batch]
		assert(item.instance < batch_node.multimesh.instance_count and batch_node.multimesh.mesh == scenery.vegetation_meshes[item.kind])
		if item.color == OutOfBoundsScenery.BLOSSOM: blossoms += 1
	assert(blossoms > 0 and blossoms < scenery.diagnostics.trees)
	# Duplicated meshes carry their own materials; the imported resources stay untouched.
	var tree_mesh: ArrayMesh = scenery.vegetation_meshes["tree"]
	assert(tree_mesh != OutOfBoundsScenery.TREE and tree_mesh.get_surface_count() == 2)
	var instance_colored := 0
	for surface in range(2):
		var surface_material := tree_mesh.surface_get_material(surface) as ShaderMaterial
		assert(surface_material != null and scenery.vegetation_materials.has(surface_material))
		if surface_material.get_shader_parameter("use_instance_color"): instance_colored += 1
	assert(instance_colored == 1) # Canopy takes instance colors; trunk keeps its base color.
	assert(scenery.vegetation_meshes["bush"].get_surface_count() == 1)
	assert(OutOfBoundsScenery.TREE.surface_get_material(0) is StandardMaterial3D and OutOfBoundsScenery.BUSH.surface_get_material(0) is StandardMaterial3D)

func validate() -> void:
	root.size = Vector2i(1920, 1080)
	var camera := CameraScript.new()
	root.add_child(camera)
	camera.current = true
	camera.rotation_degrees.x = -camera.pitch_degrees
	camera.fov = camera.field_of_view
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	for mode in [true, false]:
		renderer.cave_continuous_ground_enabled = mode
		for seed_value in [4, 17]:
			TestDungeonFactory.rng.seed = seed_value
			var data := TestDungeonFactory.create_test_dungeon()
			data.update_fog(data.player_spawn)
			var before := Snapshots.snapshot(data)
			var rng_state: int = TestDungeonFactory.rng.state
			assert(renderer.render_dungeon(data))
			var children := renderer.get_child_count()
			var scenery := renderer.out_of_bounds_scenery
			assert(scenery != null and scenery.get_parent() == renderer and scenery.get_child_count() == scenery.diagnostics.mesh_nodes)
			assert(scenery.diagnostics.near > 0 and scenery.diagnostics.far > 0 and scenery.diagnostics.mesh_nodes == scenery.batches.size() + scenery.vegetation_batches.size())
			# Spatially chunked batches so off-screen ridges cull; bounded node count.
			assert(scenery.batches.size() > 3 and scenery.batches.size() <= 120)
			assert(scenery.vegetation_batches.size() > 2 and scenery.vegetation_batches.size() <= 80)
			var full_far: int = scenery.diagnostics.far
			assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
			var apron := renderer.cave_background.scenery_apron
			var detailed: Rect2i = renderer.cave_background.get_meta("geometry_bounds")
			var instances := 0
			for batch in scenery.batches:
				assert(batch is MultiMeshInstance3D and batch.material_override == scenery.material)
				assert(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				assert(batch.get_meta("geometry_purpose") == "out_of_bounds_scenery")
				instances += batch.multimesh.instance_count
			assert(instances == scenery.placements.size() and instances == scenery.diagnostics.near + scenery.diagnostics.far)
			var models_used: Dictionary = {}
			for placement in scenery.placements:
				var block: Rect2i = placement.block
				models_used[placement.model] = true
				# Never over the logical map or south of it; near blocks cover the detailed border, far blocks the apron.
				assert(not block.intersects(data.map_bounds) and apron.visual_bounds.encloses(block))
				assert(block.end.y <= data.map_bounds.end.y)
				if placement.far: assert(not block.intersects(detailed) and block.size == Vector2i(4, 4) and detailed.grow(renderer.out_of_bounds_far_extent).encloses(block))
				else: assert(detailed.encloses(block) and block.size == Vector2i(2, 2))
				# Headless MultiMesh readback returns identity; validate the CPU-side transform.
				var batch_node: MultiMeshInstance3D = scenery.batches[placement.batch]
				assert(placement.instance < batch_node.multimesh.instance_count and batch_node.multimesh.mesh == OutOfBoundsScenery.MODELS[placement.model])
				assert(floori(float(block.position.x) / OutOfBoundsScenery.CHUNK_SIZE) == floori(float(scenery.placements[scenery.placements.find(placement)].block.position.x) / OutOfBoundsScenery.CHUNK_SIZE))
				var transform: Transform3D = placement.transform
				var bounds: AABB = transform * OutOfBoundsScenery.MODELS[placement.model].get_aabb()
				# Centered on the block, resting on the local ground top, stretched by height scale.
				assert(is_equal_approx(bounds.get_center().x, block.position.x + (block.size.x - 1) * 0.5))
				assert(is_equal_approx(bounds.get_center().z, block.position.y + (block.size.y - 1) * 0.5))
				assert(is_equal_approx(bounds.position.y, placement.top) and bounds.size.y > 0.1)
				assert(is_equal_approx(bounds.size.x, block.size.x * 1.0) or is_equal_approx(bounds.size.z, block.size.x * 1.0))
				var source: AABB = OutOfBoundsScenery.MODELS[placement.model].get_aabb()
				assert(is_equal_approx(bounds.size.y, source.size.y * (block.size.x / maxf(source.size.x, source.size.z)) * renderer.out_of_bounds_height_scale))
			assert(models_used.size() == 3)
			check_vegetation(scenery, renderer, data)
			# Far blocks sit flush against the detailed border on the north and side edges.
			var flush := 0
			for placement in scenery.placements:
				if placement.far and (placement.block.end.y == detailed.position.y or placement.block.end.x == detailed.position.x or placement.block.position.x == detailed.end.x): flush += 1
			assert(flush > 0)
			renderer.out_of_bounds_foreground_clear = false
			assert(renderer.render_dungeon(data))
			var southern := 0
			for placement in renderer.out_of_bounds_scenery.placements:
				if placement.block.end.y > data.map_bounds.end.y: southern += 1
			assert(southern > 0)
			renderer.out_of_bounds_foreground_clear = true
			# The far extent caps instance counts independently of the apron guard size.
			renderer.out_of_bounds_far_extent = 4
			assert(renderer.render_dungeon(data))
			var capped: int = renderer.out_of_bounds_scenery.diagnostics.far
			assert(capped > 0 and capped < full_far)
			for placement in renderer.out_of_bounds_scenery.placements:
				if placement.far: assert(detailed.grow(4).encloses(placement.block))
			renderer.out_of_bounds_far_extent = 16
			assert(renderer.render_dungeon(data))
			scenery = renderer.out_of_bounds_scenery
			# Deterministic for the same layout/seed; different visual seeds differ.
			var first := transforms(scenery)
			assert(renderer.render_dungeon(data) and transforms(renderer.out_of_bounds_scenery) == first)
			assert(renderer.get_child_count() == children)
			renderer.floor_visual_seed = 99
			assert(renderer.render_dungeon(data) and transforms(renderer.out_of_bounds_scenery) != first)
			renderer.floor_visual_seed = 0
			assert(renderer.render_dungeon(data))
			scenery = renderer.out_of_bounds_scenery
			# Shade follows the border palette with the configured lift; fog state does not alter placement.
			renderer.apply_fog(0)
			var dim: Color = renderer.dim_material.albedo_color.lerp(Color.WHITE, renderer.out_of_bounds_shade_lift)
			dim.a = 1.0
			assert(scenery.current_shade() == dim)
			assert(scenery.material.get_shader_parameter("fog_shade") == Vector3(dim.r, dim.g, dim.b))
			for vegetation_material in scenery.vegetation_materials:
				assert(vegetation_material.get_shader_parameter("fog_shade") == Vector3(dim.r, dim.g, dim.b))
			renderer.apply_fog(1)
			var other: Color = renderer.other_elevation_material.albedo_color.lerp(Color.WHITE, renderer.out_of_bounds_shade_lift)
			other.a = 1.0
			assert(scenery.current_shade() == other and transforms(scenery) == first)
			# Vegetation toggles and densities leave the ridges untouched.
			var ridges: Array = []
			for placement in scenery.placements: ridges.append(placement.transform)
			var default_trees: int = scenery.diagnostics.trees
			renderer.out_of_bounds_vegetation_enabled = false
			assert(renderer.render_dungeon(data))
			var bare := renderer.out_of_bounds_scenery
			assert(bare.vegetation.is_empty() and bare.vegetation_batches.is_empty() and bare.get_child_count() == bare.batches.size())
			for index in range(bare.placements.size()): assert(bare.placements[index].transform == ridges[index])
			renderer.out_of_bounds_vegetation_enabled = true
			renderer.out_of_bounds_tree_density = 0.0
			renderer.out_of_bounds_bush_density = 0.0
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery.vegetation.is_empty())
			renderer.out_of_bounds_tree_density = 1.0
			renderer.out_of_bounds_blossom_ratio = 0.0
			assert(renderer.render_dungeon(data))
			var dense := renderer.out_of_bounds_scenery
			assert(dense.diagnostics.trees > default_trees and dense.diagnostics.bushes == 0)
			for item in dense.vegetation: assert(item.color != OutOfBoundsScenery.BLOSSOM)
			renderer.out_of_bounds_tree_density = 0.3
			renderer.out_of_bounds_bush_density = 0.45
			renderer.out_of_bounds_blossom_ratio = 0.3
			assert(renderer.render_dungeon(data) and transforms(renderer.out_of_bounds_scenery) == first)
			scenery = renderer.out_of_bounds_scenery
			# Toggles: disabled scenery or no border leaves nothing behind; re-enabling restores it.
			renderer.out_of_bounds_scenery_enabled = false
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery == null)
			assert(renderer.get_child_count() == children - 1)
			renderer.out_of_bounds_scenery_enabled = true
			renderer.cave_scenery_border_width = 0
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery == null)
			renderer.cave_scenery_border_width = 6
			assert(renderer.render_dungeon(data) and renderer.out_of_bounds_scenery != null)
			assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
	# Preserved fixtures never acquire out-of-bounds scenery.
	for data in [BenchmarkDungeonFactory.create(), DemoArenaFactory.create_arena(), TestDungeonFactory.create_elevation_test_dungeon()]:
		assert(renderer.render_dungeon(data, true) and renderer.out_of_bounds_scenery == null)
	renderer.free()
	camera.free()
	print("PASS: out-of-bounds ridges stay off the logical map inside the apron, three batched models, deterministic hashed placement, height/ground anchoring, shade lift, toggles and fixture exemptions; trees/bushes on ridge surfaces clear of the map, upright, sized, colored, shaded and toggleable")
	quit()
