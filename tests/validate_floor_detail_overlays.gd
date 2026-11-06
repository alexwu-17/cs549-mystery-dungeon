extends SceneTree
## FloorDetailOverlays: rendering-only grime bands and corridor moss.
func _initialize() -> void: call_deferred("validate")

func snapshot(data: DungeonData) -> Array:
	return [data.tiles.duplicate(true), data.elevations.duplicate(true),
		data.reserved_transitions.duplicate(true), data.player_spawn, data.stairs_position]

func mesh_arrays(node: MeshInstance3D) -> Array:
	return node.mesh.surface_get_arrays(0) if node != null else []

func no_collision(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D or not no_collision(child): return false
	return true

func validate() -> void:
	var renderer := DungeonRenderer.new()
	root.add_child(renderer)
	for seed_value in [4, 17]:
		TestDungeonFactory.rng.seed = seed_value
		var data := TestDungeonFactory.create_test_dungeon()
		var before := snapshot(data)
		var rng_state: int = TestDungeonFactory.rng.state
		# Defaults: both overlays present, one node, no collision or shadows.
		assert(renderer.render_dungeon(data))
		var overlays := renderer.floor_detail_overlays
		assert(is_instance_valid(overlays) and overlays.get_parent() == renderer)
		assert(overlays.grime != null and overlays.moss != null)
		assert(overlays.stats.grime_bands > 0 and overlays.stats.moss_tiles > 0)
		assert(no_collision(overlays))
		for node: MeshInstance3D in [overlays.grime, overlays.moss]:
			assert(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(node.mesh.get_surface_count() == 1)
		# Counts match the tile rules exactly.
		var bands := 0
		var corridors := 0
		for tile: Vector2i in data.tiles:
			if data.reserved_transitions.has(tile): continue
			if data.get_tile(tile) == DungeonData.TileType.CORRIDOR: corridors += 1
			if data.get_tile(tile) == DungeonData.TileType.FLOOR and not renderer.is_open_upper_tile(tile):
				for direction in FloorDetailOverlays.DIRECTIONS:
					if FloorDetailOverlays.is_wall_side(data, tile + direction): bands += 1
		assert(overlays.stats.grime_bands == bands and overlays.stats.moss_tiles == corridors)
		assert(overlays.grime.mesh.surface_get_array_len(0) == bands * 6)
		assert(overlays.moss.mesh.surface_get_array_len(0) == corridors * 6)
		# Each moss quad sits just above its own walkable tile surface, inside that tile.
		var vertices: PackedVector3Array = mesh_arrays(overlays.moss)[Mesh.ARRAY_VERTEX]
		for quad in range(0, vertices.size(), 6):
			var center := Vector3.ZERO
			for offset in range(6): center += vertices[quad + offset] / 6.0
			var tile := Vector2i(roundi(center.x), roundi(center.z))
			assert(data.get_tile(tile) == DungeonData.TileType.CORRIDOR)
			var surface := renderer.get_entity_world_position(tile).y
			for offset in range(6):
				var vertex := vertices[quad + offset]
				assert(absf(vertex.x - tile.x) <= 0.5001 and absf(vertex.z - tile.y) <= 0.5001)
				assert(vertex.y > surface and vertex.y < surface + 0.02)
		# Deterministic and rebuilt (not duplicated) on re-render.
		var first_grime := mesh_arrays(overlays.grime)
		var first_moss := mesh_arrays(overlays.moss)
		assert(renderer.render_dungeon(data))
		assert(not is_instance_valid(overlays))
		var count := 0
		for child in renderer.get_children():
			if child is FloorDetailOverlays: count += 1
		assert(count == 1)
		assert(mesh_arrays(renderer.floor_detail_overlays.grime) == first_grime)
		assert(mesh_arrays(renderer.floor_detail_overlays.moss) == first_moss)
		# Toggles remove each overlay independently, and together remove the node.
		renderer.corridor_moss_enabled = false
		assert(renderer.render_dungeon(data))
		assert(renderer.floor_detail_overlays.grime != null and renderer.floor_detail_overlays.moss == null)
		renderer.floor_grime_enabled = false
		assert(renderer.render_dungeon(data))
		assert(renderer.floor_detail_overlays == null)
		for child in renderer.get_children(): assert(not child is FloorDetailOverlays)
		renderer.floor_grime_enabled = true
		renderer.corridor_moss_enabled = true
		# Gameplay data and generator RNG untouched.
		assert(snapshot(data) == before)
		assert(TestDungeonFactory.rng.state == rng_state)
	renderer.free()
	print("PASS: floor detail overlays match tile rules, deterministic, rebuilt once per render, toggleable, no collision/shadows, data and RNG unchanged")
	quit()
