extends SceneTree
const Snapshots = preload("res://tests/validate_terraces.gd")
const CameraScript = preload("res://scripts/core/presentation_camera.gd")
func _initialize() -> void: call_deferred("validate")
func interior(backdrop: CaveTerrainBackdrop) -> Array:
	var result: Array = []
	for record in backdrop.records:
		if not record.external: result.append([record.cell,record.top,record.bottom,record.tint,record.cap_transform,record.body_transform,record.shade])
	return result
func check_frustum(apron: CaveSceneryApron, camera: Camera3D, data: DungeonData) -> void:
	var size := root.get_visible_rect().size
	for corner in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]:
		var ray := camera.project_ray_normal(corner)
		var origin: Vector3 = camera.follow_offset + Vector3(0,3.1,0)
		var hit := origin + ray * ((CaveTerrainBackdrop.GROUND_BASE-origin.y)/ray.y)
		for tile in [data.map_bounds.position,data.map_bounds.end-Vector2i.ONE]:
			assert(apron.visual_bounds.grow(-1).has_point(tile+Vector2i(floori(hit.x+0.5),floori(hit.z+0.5))))
func validate() -> void:
	root.size=Vector2i(1920,1080)
	var camera := CameraScript.new()
	root.add_child(camera)
	camera.current=true
	camera.rotation_degrees.x=-camera.pitch_degrees
	camera.fov=camera.field_of_view
	var renderer := DungeonRenderer.new()
	renderer.cave_continuous_ground_enabled = false
	renderer.cave_stone_mapping_enabled = false
	root.add_child(renderer)
	for seed_value in [4,17]:
		TestDungeonFactory.rng.seed=seed_value
		var data := TestDungeonFactory.create_test_dungeon()
		data.update_fog(data.player_spawn)
		var before := Snapshots.snapshot(data)
		var rng_state: int = TestDungeonFactory.rng.state
		renderer.cave_scenery_border_width=0
		assert(renderer.render_dungeon(data))
		renderer.apply_fog(0)
		var original := interior(renderer.cave_background)
		assert(renderer.cave_background.scenery_apron==null)
		renderer.cave_scenery_border_width=6
		assert(renderer.render_dungeon(data))
		renderer.apply_fog(0)
		var backdrop := renderer.cave_background
		assert(interior(backdrop)==original)
		assert(data.map_bounds==Rect2i(0,0,42,32))
		assert(before==Snapshots.snapshot(data) and rng_state==TestDungeonFactory.rng.state)
		assert(backdrop.diagnostics.violations.is_empty() and backdrop.diagnostics.border_cells>0)
		assert(backdrop.diagnostics.mesh_nodes<=85)
		assert(backdrop.get_child_count()==backdrop.diagnostics.mesh_nodes)
		for record in backdrop.records:
			assert(data.map_bounds.grow(6).has_point(record.cell))
			if record.external: assert(not data.map_bounds.has_point(record.cell) and not data.is_walkable(record.cell) and not record.adjacent)
		var apron := backdrop.scenery_apron
		assert(apron.mesh.get_faces().size()==24 and apron.guard_margin>=8)
		assert(apron.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		check_frustum(apron,camera,data)
		var external: Dictionary
		for record in backdrop.records:
			if record.external:
				external=record
				break
		data.bright_tiles[external.cell]=true
		data.discovered_tiles[external.cell]=true
		renderer.apply_fog(0)
		assert(external.shade==renderer.dim_material.albedo_color)
		renderer.apply_fog(1)
		assert(external.shade==renderer.other_elevation_material.albedo_color)
		root.size=Vector2i(2560,1080)
		await process_frame
		await process_frame
		check_frustum(apron,camera,data)
		root.size=Vector2i(1920,1080)
		await process_frame
	# Preserved fixtures never acquire scenery or scenery collision.
	for data in [BenchmarkDungeonFactory.create(),DemoArenaFactory.create_arena(),TestDungeonFactory.create_elevation_test_dungeon()]:
		assert(renderer.render_dungeon(data,true) and renderer.cave_background==null)
	renderer.free()
	camera.free()
	print("PASS: reversible border, identical interior/data/RNG, discovery-independent scenery, bounded chunks, apron frustum/resize coverage and exemptions")
	quit()
