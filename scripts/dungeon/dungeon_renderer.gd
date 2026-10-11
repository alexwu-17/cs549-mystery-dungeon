class_name DungeonRenderer
extends Node3D


const TILE_SIZE: float = DungeonData.TILE_SIZE
const ELEVATION_HEIGHT: float = DungeonData.ELEVATION_HEIGHT
const FLOOR_THICKNESS: float = 0.2

var dungeon_data: DungeonData
var fog_visuals: Array[Dictionary] = []
var normal_material: StandardMaterial3D
var dim_material: StandardMaterial3D
var other_elevation_material: StandardMaterial3D
@export var other_elevation_fog_color: Color = Color(0.07, 0.07, 0.07)


func render_dungeon(data: DungeonData) -> void:
	dungeon_data = data
	fog_visuals.clear()
	if normal_material == null:
		normal_material = StandardMaterial3D.new()
		dim_material = StandardMaterial3D.new()
		dim_material.albedo_color = Color(0.22, 0.22, 0.22)
		other_elevation_material = StandardMaterial3D.new()
	other_elevation_material.albedo_color = other_elevation_fog_color

	for child in get_children():
		child.free()

	for grid_position: Vector2i in dungeon_data.tiles:
		var tile_type: DungeonData.TileType = dungeon_data.get_tile(grid_position)

		if tile_type == DungeonData.TileType.VOID:
			continue

		if tile_type == DungeonData.TileType.RAMP:
			if dungeon_data.ramp_tiles.has(grid_position):
				if dungeon_data.ramp_tiles[grid_position].index == 0:
					create_ramp_segment(dungeon_data.ramp_segments[dungeon_data.ramp_tiles[grid_position].segment])
			else:
				create_ramp_tile(grid_position)
		elif tile_type == DungeonData.TileType.STAIRS:
			create_stairs_tile(grid_position)
		else:
			create_floor_tile(grid_position)


func create_floor_tile(grid_position: Vector2i) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	box.size = Vector3(TILE_SIZE, FLOOR_THICKNESS, TILE_SIZE)
	mesh_instance.mesh = box

	var elevation := dungeon_data.get_elevation(grid_position)

	mesh_instance.position = grid_to_world(grid_position, elevation)

	add_child(mesh_instance)
	register_fog_visual(mesh_instance, [grid_position])

func create_ramp_tile(grid_position: Vector2i) -> void:
	# Legacy fixture retains its one-tile footprint using the same height scale.
	create_slope(grid_position, Vector2i.RIGHT, dungeon_data.get_elevation(grid_position), 1)


func create_ramp_segment(segment: Dictionary) -> void:
	create_slope(segment.lower_buffer + segment.direction, segment.direction, segment.lower, 3)


func create_slope(first_tile: Vector2i, uphill: Vector2i, lower: int, tile_count: int) -> void:
	# Canonical asset frame: origin at the lower surface edge, uphill along +X.
	# Buffers are separate meshes. Replace this prism mesh with the future model.
	var mesh_instance := MeshInstance3D.new()
	var length := tile_count * TILE_SIZE
	var half_width := TILE_SIZE / 2.0
	var vertices := [Vector3(0, 0, -half_width), Vector3(0, 0, half_width), Vector3(length, ELEVATION_HEIGHT, half_width), Vector3(length, ELEVATION_HEIGHT, -half_width)]
	for index in range(4):
		vertices.append(vertices[index] - Vector3(0, FLOOR_THICKNESS, 0))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 2, 1, 0, 3, 2, 4, 6, 7, 4, 5, 6, 0, 5, 4, 0, 1, 5, 1, 6, 5, 1, 2, 6, 2, 7, 6, 2, 3, 7, 3, 4, 7, 3, 0, 4]:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	mesh_instance.position = grid_to_world(first_tile, lower) - Vector3(uphill.x, 0, uphill.y) * TILE_SIZE / 2.0
	mesh_instance.position.y += FLOOR_THICKNESS / 2.0
	mesh_instance.rotation.y = -atan2(float(uphill.y), float(uphill.x))
	add_child(mesh_instance)
	var covered: Array[Vector2i] = []
	for index in range(tile_count):
		covered.append(first_tile + uphill * index)
	register_fog_visual(mesh_instance, covered)

func create_stairs_tile(grid_position: Vector2i) -> void:
	# Create the normal floor underneath the staircase marker.
	create_floor_tile(grid_position)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	box.size = Vector3(
		TILE_SIZE * 0.6,
		0.15,
		TILE_SIZE * 0.6
	)

	mesh_instance.mesh = box

	var elevation := dungeon_data.get_elevation(grid_position)

	mesh_instance.position = grid_to_world(
		grid_position,
		elevation
	)

	mesh_instance.position.y += 0.2

	add_child(mesh_instance)
	register_fog_visual(mesh_instance, [grid_position], true)


func register_fog_visual(mesh: MeshInstance3D, covered: Array[Vector2i], stairs: bool = false) -> void:
	var tile: Vector2i = covered[0]
	var room := dungeon_data.get_room_id(tile)
	var terrain_candidate := room >= 0 or dungeon_data.get_tile(tile) == DungeonData.TileType.CORRIDOR
	var candidate := covered.size() == 1 and terrain_candidate and dungeon_data.get_tile(tile) != DungeonData.TileType.RAMP and not dungeon_data.reserved_transitions.has(tile)
	fog_visuals.append({"mesh": mesh, "tiles": covered, "stairs": stairs, "room": room, "candidate": candidate, "occluded": false, "fog_visible": true})


func apply_fog(reference_elevation: int = 0) -> void:
	for visual in fog_visuals:
		var bright := false
		for tile: Vector2i in visual.tiles:
			if dungeon_data.is_bright(tile):
				bright = true
				break
		var mesh: MeshInstance3D = visual.mesh
		visual.fog_visible = bright if visual.stairs else true
		mesh.visible = visual.fog_visible and not visual.occluded
		mesh.material_override = normal_material if bright else dim_material
		var tile: Vector2i = visual.tiles[0]
		var elevation_shaded: bool = visual.room >= 0 or dungeon_data.get_tile(tile) == DungeonData.TileType.CORRIDOR
		if not bright and elevation_shaded and dungeon_data.get_elevation(tile) != reference_elevation:
			mesh.material_override = other_elevation_material


func update_occlusion(camera: Camera3D, player_tile: Vector2i, sprite_points: Array[Vector3]) -> void:
	if dungeon_data == null:
		return
	var player_room := dungeon_data.get_room_id(player_tile)
	var ray_origins: Array[Vector3] = []
	for target in sprite_points:
		ray_origins.append(camera.project_ray_origin(camera.unproject_position(target)))
	for visual in fog_visuals:
		var mesh: MeshInstance3D = visual.mesh
		visual.occluded = false
		var higher_terrain := dungeon_data.get_elevation(visual.tiles[0]) > dungeon_data.surface_elevation(player_tile)
		var own_room: bool = player_room >= 0 and visual.room == player_room
		if visual.candidate and higher_terrain and not own_room and not visual.tiles.has(player_tile) and visual.fog_visible:
			# Transform the segment into the mesh's local frame. This tests its
			# actual oriented bounds rather than an inflated world-space AABB.
			var inverse := mesh.global_transform.affine_inverse()
			var bounds := mesh.get_aabb()
			for index in range(sprite_points.size()):
				if bounds.intersects_segment(inverse * ray_origins[index], inverse * sprite_points[index]) != null:
					visual.occluded = true
					break
		mesh.visible = visual.fog_visible and not visual.occluded


func grid_to_world(grid_position: Vector2i, elevation: int = 0) -> Vector3:
	return Vector3(
		grid_position.x * TILE_SIZE,
		elevation * ELEVATION_HEIGHT,
		grid_position.y * TILE_SIZE
	)

func get_entity_world_position(grid_position: Vector2i) -> Vector3:
	var world_position := grid_to_world(grid_position)
	world_position.y = dungeon_data.surface_elevation(grid_position) * ELEVATION_HEIGHT

	# Characters/entities stand on the top surface of the floor,
	# not at the center of the floor mesh.
	world_position.y += FLOOR_THICKNESS / 2.0

	return world_position
