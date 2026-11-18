extends SceneTree
## Owns: decorative out-of-bounds ridge placement (never over the logical map,
## inside the apron bounds, deterministic, batched), fog shade lift, toggles
## and fixture exemptions. Appearance needs a normal-render check by the user.
const Snapshots = preload("res://tests/validate_terraces.gd")
const CameraScript = preload("res://scripts/core/presentation_camera.gd")
func _initialize() -> void: call_deferred("validate")

func transforms(scenery: OutOfBoundsScenery) -> Array:
	var result: Array = []
	for placement in scenery.placements: result.append([placement.block, placement.model, placement.transform, placement.far])
	return result

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
			assert(scenery.diagnostics.near > 0 and scenery.diagnostics.far > 0 and scenery.diagnostics.mesh_nodes == scenery.batches.size())
			# Spatially chunked batches so off-screen ridges cull; bounded node count.
			assert(scenery.batches.size() > 3 and scenery.batches.size() <= 120)
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
			renderer.apply_fog(1)
			var other: Color = renderer.other_elevation_material.albedo_color.lerp(Color.WHITE, renderer.out_of_bounds_shade_lift)
			other.a = 1.0
			assert(scenery.current_shade() == other and transforms(scenery) == first)
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
	print("PASS: out-of-bounds ridges stay off the logical map inside the apron, three batched models, deterministic hashed placement, height/ground anchoring, shade lift, toggles and fixture exemptions")
	quit()
