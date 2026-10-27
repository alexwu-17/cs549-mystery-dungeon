extends SceneTree
const Snapshots = preload("res://tests/validate_terraces.gd")
func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	var data := DungeonData.new()
	data.map_bounds = Rect2i(0,0,24,24)
	data.rooms = [Rect2i(10,10,4,4)]
	data.room_elevations = [1]
	for y in range(10,14):
		for x in range(10,14): data.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR,1)
	var before := Snapshots.snapshot(data)
	var rng_state: int = TestDungeonFactory.rng.state
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	var elements := EnvironmentGeometryPlan.required(data,1.0)
	var required := elements.duplicate(true)
	var owner := Vector2i(10,11)
	var upper := EnvironmentGeometryPlan.box_record(EnvironmentGeometryPlan.TERRACE,Vector2i(9,11),owner,0.1,2.1)
	upper["parent"] = owner
	upper["distance"] = 1
	var lower := EnvironmentGeometryPlan.box_record(EnvironmentGeometryPlan.TERRACE,Vector2i(8,11),owner,0.1,1.1)
	lower["parent"] = upper.cell
	lower["distance"] = 2
	elements.append(upper)
	elements.append(lower)
	var profiles := CaveRockSlopes.prepare(data,elements,renderer)
	assert(profiles.planned_slopes == 2)
	var a: PackedVector3Array = upper.rock_profile
	var b: PackedVector3Array = lower.rock_profile
	assert(is_equal_approx(a[0].y,2.1) and is_equal_approx(a[1].y,EnvironmentGeometryPlan.floor_bottom()))
	assert(is_equal_approx(b[0].y,1.1) and is_equal_approx(b[1].y,2.1))
	assert(a[0] == b[1] and a[3] == b[2])
	var ground: PackedVector3Array = profiles.ground[Vector2i(7,11)]
	assert(ground[1] == b[0] and ground[2] == b[3])
	for i in range(required.size()): assert(required[i] == elements[i])
	var options := {"support_height":1.0,"clearance":1,"maximum":3,"pitch":35.0,"cave_caps":true}
	var plan := {"elements":elements,"surfaces":EnvironmentGeometryPlan.base_contract(data),"options":options}
	assert(EnvironmentGeometryPlan.validate(plan,data).is_empty())
	for record in [upper,lower]:
		var mesh := CaveRockSlopes.mesh(record)
		var transform := Transform3D(Basis.IDENTITY,Vector3(record.cell.x,record.bounds.end.y,record.cell.y))
		assert(EnvironmentGeometryPlan.same_bounds(transform*mesh.get_aabb(),record.bounds))
		assert(mesh.get_surface_count() == 2)
		var normals: PackedVector3Array = mesh.surface_get_arrays(1)[Mesh.ARRAY_NORMAL]
		for normal in normals: assert(normal.y > 0.1 and normal.y < 0.999) # No flat intermediate shelf.
	# Original model relief is baked, rather than replacing it with faint noise.
	var heights := CaveStoneMaterial.authored_heights()
	var minimum := INF
	var maximum := -INF
	for height in heights:
		minimum = minf(minimum,height)
		maximum = maxf(maximum,height)
	assert(maximum-minimum > 0.02)
	assert(CaveStoneMaterial.detail() == CaveStoneMaterial.detail())
	assert(CaveStoneMaterial.normal_texture != null)
	assert(before == Snapshots.snapshot(data) and rng_state == TestDungeonFactory.rng.state)
	renderer.free()
	print("PASS: continuous ground-to-three-layer slopes, shared cross-band corners, no flat intermediate roof, full foundations, original relief textures, unchanged data/RNG")
	quit()
