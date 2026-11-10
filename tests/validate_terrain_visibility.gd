extends SceneTree
const Support = preload("res://tests/capture_support.gd")

func _initialize() -> void: call_deferred("validate")

func visual(mesh: MeshInstance3D, tile: Vector2i) -> Dictionary:
	return {"mesh": mesh, "tiles": [tile], "stairs": false, "fog_visible": true, "wall": false, "support": true, "candidate": false, "occluded": false, "round_occluded": false}

func validate() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0,5,8)
	camera.look_at(Vector3(0,1,0))
	var data := DungeonData.new()
	for x in range(5): data.set_tile(Vector2i(x,0), DungeonData.TileType.CORRIDOR)
	data.update_fog(Vector2i.ZERO)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3,3,0.2)
	mesh.mesh = box
	root.add_child(mesh)
	mesh.position = Vector3(0,1.5,2)
	var entry := visual(mesh,Vector2i(1,0))
	var entries: Array[Dictionary] = [entry]
	var helper := TerrainOcclusion.new()
	var body: Array[Vector3] = [Vector3(-0.2,1,0),Vector3(0.2,1,0),Vector3(-0.2,1.4,0),Vector3(0.2,1.4,0)]
	# Upper corridors, ramps and both landing types are genuine occluders.
	for kind in [DungeonData.TileType.CORRIDOR, DungeonData.TileType.RAMP, DungeonData.TileType.FLOOR]:
		data.set_tile(Vector2i(1,0),kind)
		helper.setup(entries)
		helper.update(camera,Vector2i.ZERO,body,data)
		assert(helper.active.size()==1 and helper.stats.blocked==4)
		var tests: int = helper.stats.triangle_tests
		assert(helper.update(camera,Vector2i.ZERO,body,data).is_empty())
		assert(helper.stats.triangle_tests==tests) # Identical pose does no ray work.
	entry.stairs = true # Exit marker is distinct from a ramp mesh.
	helper.setup(entries)
	helper.update(camera,Vector2i.ZERO,body,data)
	assert(helper.active.is_empty())
	entry.stairs = false
	# Exactly25% blocked remains clear;50% really blocked opens the circle.
	var partial: Array[Vector3] = [body[0],Vector3(20,1,0),Vector3(21,1,0),Vector3(22,1,0)]
	helper.setup(entries)
	helper.update(camera,Vector2i.ZERO,partial,data)
	assert(helper.stats.blocked==1 and helper.active.is_empty())
	partial[1]=body[1]
	helper.update(camera,Vector2i.ZERO,partial,data)
	assert(helper.stats.blocked==2 and helper.active.size()==1)
	# A box around two separate sides crosses all rays; their triangles do not.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-2,0,0),Vector3(-1.5,0,0),Vector3(-2,3,0),Vector3(1.5,0,0),Vector3(2,0,0),Vector3(2,3,0)]: tool.add_vertex(point)
	tool.generate_normals()
	mesh.mesh = tool.commit()
	helper.setup(entries)
	assert(mesh.mesh.get_aabb().intersects_segment(mesh.to_local(camera.global_position),mesh.to_local(body[0]))!=null)
	helper.update(camera,Vector2i.ZERO,body,data)
	assert(helper.stats.blocked==0 and helper.active.is_empty())
	mesh.free()
	camera.free()
	if DisplayServer.get_name()!="headless": await validate_colors()
	print("PASS: exact mesh/corner coverage, 25-percent gate, corridor/ramp/landing support, cached stationary queries and circular shadow parity")
	quit()

func validate_colors() -> void:
	root.size=Vector2i(512,512)
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=6.0
	camera.position=Vector3(0,10,0)
	camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	camera.current=true
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE
	world.environment.ambient_light_energy=1.0
	world.environment.ambient_light_sky_contribution=0.0
	world.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	scene.add_child(world)
	var bright := StandardMaterial3D.new()
	bright.albedo_color=Color(0.7,0.6,0.5)
	bright.roughness=1.0
	var dark: StandardMaterial3D=bright.duplicate()
	dark.albedo_color=bright.albedo_color*Color(0.22,0.22,0.22)
	var materials := TerrainVisibilityMaterial.new()
	for size in [5.0,3.0]:
		var plane := MeshInstance3D.new()
		var shape := PlaneMesh.new()
		shape.size=Vector2(size,size)
		plane.mesh=shape
		plane.position.y=0.02 if size==3.0 else 0.0
		plane.material_override=materials.get_material(bright,dark,true,false,0.2) if size==3.0 else dark
		scene.add_child(plane)
	await process_frame
	await process_frame
	var picture:=Support.image(self)
	var outside: Color=picture.get_pixelv(Vector2i(camera.unproject_position(Vector3(1.35,0,1.35))))
	var neighbor: Color=picture.get_pixelv(Vector2i(camera.unproject_position(Vector3(1.8,0,1.35))))
	var inside: Color=picture.get_pixel(256,256)
	print("GPU shadow comparison: inside=",inside," outside-circle=",outside," neighboring-shadow=",neighbor)
	assert(absf(outside.r-neighbor.r)<0.012 and absf(outside.g-neighbor.g)<0.012 and absf(outside.b-neighbor.b)<0.012)
	assert(inside.r>outside.r*2.0)
	Support.save_image(picture,"res://.godot/terrain-visibility-shadow-parity.png")
	scene.free()
