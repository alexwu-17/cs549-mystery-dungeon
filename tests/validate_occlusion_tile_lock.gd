extends SceneTree

func _initialize() -> void: call_deferred("validate")

func validate() -> void:
	var data := DungeonData.new()
	data.set_tile(Vector2i.ZERO, DungeonData.TileType.FLOOR)
	data.set_tile(Vector2i.RIGHT, DungeonData.TileType.FLOOR)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 3, 6)
	camera.look_at(Vector3.ZERO)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(2, 3, 0.2)
	root.add_child(mesh)
	mesh.position = Vector3(0, 1.5, 3)
	var visual: Dictionary = {"mesh": mesh, "stairs": false, "wall": true,
		"tiles": [Vector2i(0, 3)], "fog_visible": true,
		"occluded": false, "round_occluded": false}
	var occlusion := TerrainOcclusion.new()
	occlusion.setup([visual] as Array[Dictionary])
	var blocked: Array[Vector3] = [Vector3.ZERO]
	var clear: Array[Vector3] = [Vector3(20, 0, 0)]
	occlusion.update(camera, Vector2i.ZERO, blocked, data)
	assert(visual.occluded)
	var saved := occlusion.active.duplicate()
	for index in range(20):
		assert(occlusion.update(camera, Vector2i.ZERO, clear if index % 2 == 0 else blocked, data).is_empty())
		assert(occlusion.active == saved and visual.occluded)
	# Movement releases the saved selection and permits restoration.
	occlusion.update(camera, Vector2i.RIGHT, clear, data)
	assert(not visual.occluded)
	# A clear decision is also stable against idle sample changes.
	assert(occlusion.update(camera, Vector2i.RIGHT, blocked, data).is_empty())
	assert(not visual.occluded)
	occlusion.update(camera, Vector2i.ZERO, blocked, data)
	assert(visual.occluded)
	# Explicit fog/topology refresh remains authoritative on the same tile.
	visual.fog_visible = false
	occlusion.invalidate()
	occlusion.update(camera, Vector2i.ZERO, blocked, data)
	assert(not visual.occluded)
	visual.fog_visible = true
	occlusion.invalidate()
	occlusion.update(camera, Vector2i.ZERO, blocked, data)
	assert(visual.occluded)
	camera.position.x += 0.01
	occlusion.update(camera, Vector2i.ZERO, clear, data)
	assert(not visual.occluded)
	occlusion.setup([visual] as Array[Dictionary])
	occlusion.update(camera, Vector2i.ZERO, blocked, data)
	assert(visual.occluded)
	mesh.free()
	camera.free()
	print("PASS: full occlusion selection frozen per tile; movement, camera, fog and rebuild invalidate")
	quit()
