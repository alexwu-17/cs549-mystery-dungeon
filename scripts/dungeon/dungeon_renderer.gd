class_name DungeonRenderer
extends Node3D


const TILE_SIZE: float = DungeonData.TILE_SIZE
const ELEVATION_HEIGHT: float = DungeonData.ELEVATION_HEIGHT
const FLOOR_THICKNESS: float = 0.2
const STAIRS_VISUAL: PackedScene = preload("res://scenes/environment/stairs_placeholder.tscn")
const RAMP_VISUAL: PackedScene = preload("res://scenes/environment/up_stairs.tscn")

var dungeon_data: DungeonData
var fog_visuals: Array[Dictionary] = []
var normal_material: StandardMaterial3D
var dim_material: StandardMaterial3D
var other_elevation_material: StandardMaterial3D
@export var other_elevation_fog_color: Color = Color(0.07, 0.07, 0.07)
@export_range(0.5, 1.0, 0.25) var conventional_wall_height_scale: float = 0.5
@export var floor_variation_enabled: bool = true
@export var floor_quarter_turns_enabled: bool = true
@export_range(0.0, 0.1, 0.01) var floor_color_variation: float = 0.04
@export var floor_visual_seed: int = 0
@export_range(0.0, 1.0) var obstructing_wall_opacity: float = 0.2
@export var stair_seams_enabled: bool = true
@export var terrain_fill_enabled: bool = true
@export_range(0, 8) var terrain_fill_margin: int = 3
@export var upper_elevation_open_platforms: bool = true
@export_range(0.0, 3.0, 0.05) var upper_corridor_support_height: float = 1.0
@export var upper_terrain_mode: UpperTerrainVisuals.Mode = UpperTerrainVisuals.Mode.TERRACES
@export_range(0, 8) var upper_filler_max_distance: int = 3
@export_range(1, 3) var terrace_band_width: int = 1
@export var terrace_irregular_edges: bool = true
@export_range(1, 3) var terrace_protected_clearance: int = 1
var terrain_metrics: Dictionary = {}
@export var geometry_validation_enabled: bool = true
@export var geometry_diagnostics_enabled: bool = false
var geometry_plan: Dictionary = {}
var geometry_diagnostics: Dictionary = {}
var geometry_box_meshes: Dictionary = {}
var validated_geometry_active: bool = false
var terrain_fill_cells: Dictionary = {}
@export var cave_fill_enabled: bool = true
@export var cave_ceiling_variation_enabled: bool = true
@export_range(0.0, 0.1, 0.01) var cave_ceiling_color_variation: float = 0.03
@export_range(4, 16, 4) var cave_batch_chunk_size: int = 8
@export var cave_ground_blending_enabled: bool = true
@export var cave_ground_height_variation_enabled: bool = true
@export_range(0, 16, 1) var cave_scenery_border_width: int = 6
@export var cave_continuous_ground_enabled: bool = true
@export var cave_stone_mapping_enabled: bool = true
@export var cave_weathered_edges_enabled: bool = true
var cave_background: CaveTerrainBackdrop
var cave_fill_active: bool = false
var _occlusion_frame: int = -1
var _occlusion_context: Array = []
var _stone_variants: Dictionary = {}
var cave_rock_profiles: Dictionary = {}
var _rock_meshes: Dictionary = {}


func render_dungeon(data: DungeonData, preserve_terrain: bool = false, structure_only: bool = false) -> bool:
	_occlusion_context.clear()
	_stone_variants.clear()
	cave_rock_profiles.clear()
	_rock_meshes.clear()
	dungeon_data = data
	fog_visuals.clear()
	terrain_fill_cells.clear()
	terrain_metrics.clear()
	geometry_plan = {}
	cave_background = null
	geometry_diagnostics = {"active": false, "repairs": [], "unresolved": [], "fallback": structure_only}
	validated_geometry_active = geometry_validation_enabled and terrain_fill_enabled and upper_elevation_open_platforms and upper_terrain_mode != UpperTerrainVisuals.Mode.UNLIMITED and not preserve_terrain and not data.legacy_ramp and data.room_elevations.has(1) and not data.room_elevations.has(-1)
	var flat_ground := geometry_validation_enabled and terrain_fill_enabled and upper_elevation_open_platforms and upper_terrain_mode != UpperTerrainVisuals.Mode.UNLIMITED and not preserve_terrain and not data.legacy_ramp and not data.room_elevations.has(1) and not data.room_elevations.has(-1)
	cave_fill_active = cave_fill_enabled and (validated_geometry_active or flat_ground) and data.map_bounds.has_area()
	if validated_geometry_active:
		var original := TerrainFillVisuals.layout(data, terrain_fill_margin)
		var options := {"support_height": upper_corridor_support_height, "maximum": upper_filler_max_distance, "width": terrace_band_width,
			"irregular": terrace_irregular_edges, "clearance": terrace_protected_clearance, "pitch": 35.0, "mode": upper_terrain_mode, "wall_scale": conventional_wall_height_scale, "cave_caps": cave_fill_active}
		var camera := get_viewport().get_camera_3d()
		if camera != null and camera.get("pitch_degrees") != null: options.pitch = float(camera.get("pitch_degrees"))
		geometry_plan = EnvironmentGeometryPlan.build(data, original, options, structure_only)
		var checked := EnvironmentGeometryPlan.repair(geometry_plan, data, original)
		geometry_plan = checked.plan
		if cave_fill_active:
			CaveTerrainBackdrop.refine_boundaries(data, geometry_plan.elements, floor_visual_seed, cave_ground_height_variation_enabled)
		geometry_diagnostics.active = true
		geometry_diagnostics.repairs = checked.repairs
		var applied_depth := clampf(upper_corridor_support_height, 0.1, ELEVATION_HEIGHT / 3.0)
		if not is_equal_approx(applied_depth, upper_corridor_support_height):
			geometry_diagnostics.repairs.append({"code": "clamped_walkway_depth", "requested": upper_corridor_support_height, "applied": applied_depth})
		geometry_diagnostics.unresolved = checked.unresolved
		if not checked.unresolved.is_empty():
			if not structure_only:
				push_warning("Environmental plan rejected; rebuilding required structure without terraces: " + str(checked.unresolved))
				var reasons: Array = checked.unresolved.duplicate(true)
				var restored := render_dungeon(data, preserve_terrain, true)
				geometry_diagnostics["fallback_reasons"] = reasons
				return restored
			push_error("Environmental structure could not be validated: " + str(checked.unresolved))
			return false
	if cave_fill_active and cave_continuous_ground_enabled and cave_weathered_edges_enabled:
		cave_rock_profiles = CaveRockSlopes.prepare(data,geometry_plan.get("elements",[]),self)
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
		if tile_type == DungeonData.TileType.WALL:
			continue # Boundary models are owned by their neighboring walkable tiles.

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
	if validated_geometry_active:
		for record in geometry_plan.elements: create_planned_element(record)
		if not verify_environment_geometry():
			if not structure_only:
				var reasons: Array = geometry_diagnostics.unresolved.duplicate(true)
				push_warning("Environmental instances rejected; rebuilding structure-only visual fallback: " + str(reasons))
				var restored := render_dungeon(data, preserve_terrain, true)
				geometry_diagnostics["fallback_reasons"] = reasons
				return restored
			push_error("Environmental structure failed instance validation: " + str(geometry_diagnostics.unresolved))
			return false
	elif terrain_fill_enabled:
		create_terrain_fill(preserve_terrain)
	if cave_fill_active:
		var covered: Dictionary = {}
		for record in geometry_plan.get("elements", []):
			if record.purpose in [EnvironmentGeometryPlan.BOUNDARY, EnvironmentGeometryPlan.TERRACE]: covered[record.cell] = record
		if not validated_geometry_active:
			for cell in terrain_fill_cells:
				# In a flat map all emitted legacy filler is solid lower backing.
				covered[cell] = true
		cave_background = CaveTerrainBackdrop.new()
		cave_background.name = "CaveBackground"
		add_child(cave_background)
		cave_background.setup(data, covered, self)
		geometry_diagnostics["cave_background"] = cave_background.diagnostics
		if not cave_background.diagnostics.violations.is_empty():
			push_error("Invalid bounded cave background: " + str(cave_background.diagnostics.violations))
			return false
		if geometry_diagnostics_enabled: print("CAVE BACKGROUND ", cave_background.diagnostics)
	return true


func create_planned_element(record: Dictionary) -> void:
	var bounds: AABB = record.bounds
	var mesh := MeshInstance3D.new()
	mesh.name = record.purpose
	var tint := ModularDungeonVisuals.FILL_COLOR
	var ceiling: bool = cave_fill_active and record.purpose in [EnvironmentGeometryPlan.BOUNDARY, EnvironmentGeometryPlan.TERRACE]
	if record.purpose == EnvironmentGeometryPlan.BOUNDARY or ceiling:
		if record.has("rock_profile"):
			var shape := CaveRockSlopes.shape_key(record)
			if not _rock_meshes.has(shape): _rock_meshes[shape] = CaveRockSlopes.mesh(record)
			mesh.mesh = _rock_meshes[shape]
		else:
			mesh.mesh = TerrainFillVisuals.cave_mesh(bounds.size.y) if cave_fill_active else TerrainFillVisuals.mesh(bounds.size.y, record.detailed)
		mesh.position = Vector3(record.cell.x, bounds.end.y, record.cell.y)
		if cave_fill_active and cave_ceiling_variation_enabled and not record.has("rock_profile"): mesh.rotation.y = float(posmod(floor_hash(record.cell), 4)) * PI / 2.0
	else:
		var key := "%s:%s:%s" % [record.purpose, bounds.size, record.layer]
		if not geometry_box_meshes.has(key):
			var box := BoxMesh.new()
			box.size = bounds.size
			box.material = TerrainFillVisuals.material()
			geometry_box_meshes[key] = box
		mesh.mesh = geometry_box_meshes[key]
		mesh.position = bounds.get_center()
		if record.purpose == EnvironmentGeometryPlan.FOUNDATION:
			tint = tint.darkened([0.14, 0.02, 0.09][record.layer])
	add_child(mesh)
	register_fog_visual(mesh, [Vector2i(record.cell)], false, true)
	var visual: Dictionary = fog_visuals.back()
	visual["purpose"] = record.purpose
	visual["plan_id"] = record.id
	visual["owner"] = record.owner
	mesh.set_meta("geometry_purpose", record.purpose)
	mesh.set_meta("geometry_owner", record.owner)
	mesh.set_meta("geometry_id", record.id)
	visual.materials[0] = ModularDungeonVisuals.materials(mesh.mesh.surface_get_material(0), dim_material.albedo_color, other_elevation_material.albedo_color, tint)
	if ceiling:
		var factor := 1.0
		if cave_ceiling_variation_enabled: factor += (float(posmod(floor_hash(record.cell) / 4, 9)) / 4.0 - 1.0) * cave_ceiling_color_variation
		visual.materials[1] = ModularDungeonVisuals.materials(mesh.mesh.surface_get_material(1), dim_material.albedo_color, other_elevation_material.albedo_color, ModularDungeonVisuals.FILL_COLOR * Color(factor, factor, factor, 1))
	# Keep the existing three fog states and selective transparency ownership.
	# Duplicate cached variants before adding optional world-space stone detail.
	if cave_stone_mapping_enabled and record.purpose != EnvironmentGeometryPlan.WALKWAY:
		for surface in range(visual.materials.size()):
			for state in range(visual.materials[surface].size()):
				var original: StandardMaterial3D = visual.materials[surface][state]
				var key := original.get_instance_id()
				if not _stone_variants.has(key):
					var stone: StandardMaterial3D = original.duplicate()
					CaveStoneMaterial.configure(stone)
					_stone_variants[key] = stone
				visual.materials[surface][state] = _stone_variants[key]
	if record.purpose == EnvironmentGeometryPlan.WALKWAY:
		visual["support"] = true
	else:
		visual.filler = true
		visual.candidate = true
		visual.fill_owner = record.owner
		visual.fill_elevation = dungeon_data.get_elevation(record.owner)
		visual.fill_distance = record.get("distance", 1)


func verify_environment_geometry() -> bool:
	if not validated_geometry_active: return true
	var registered: Dictionary = {}
	for visual in fog_visuals:
		if is_instance_valid(visual.get("mesh")): registered[visual.mesh.get_instance_id()] = true
	for child in get_children():
		if child is MeshInstance3D and not registered.has(child.get_instance_id()):
			geometry_diagnostics.repairs.append({"code": "unregistered_mesh", "id": child.name, "cell": Vector2i(roundi(child.position.x), roundi(child.position.z))})
			child.free()
	var problems := EnvironmentGeometryPlan.inspect_instances(geometry_plan, dungeon_data, fog_visuals)
	geometry_diagnostics["initial_violations"] = problems.duplicate(true)
	var records: Dictionary = {}
	for record in geometry_plan.elements: records[record.id] = record
	# One bounded local repair pass. Required structure is never omitted for camera
	# clearance; runtime selective fading handles genuine sprite obstruction.
	for problem in problems:
		if problem.code == "orphan_unplanned_instance":
			for index in range(fog_visuals.size() - 1, -1, -1):
				if is_instance_valid(fog_visuals[index].get("mesh")) and fog_visuals[index].mesh.get_instance_id() == problem.instance:
					fog_visuals[index].mesh.free()
					fog_visuals.remove_at(index)
			geometry_diagnostics.repairs.append(problem)
			continue
		if problem.code == "unexpected_instance":
			for index in range(fog_visuals.size() - 1, -1, -1):
				if fog_visuals[index].get("plan_id", "") == problem.id:
					if is_instance_valid(fog_visuals[index].get("mesh")): fog_visuals[index].mesh.free()
					fog_visuals.remove_at(index)
			geometry_diagnostics.repairs.append(problem)
			continue
		if not records.has(problem.id): continue
		if problem.code not in ["missing_instance", "misplaced_instance", "duplicate_instance"]: continue
		for index in range(fog_visuals.size() - 1, -1, -1):
			if fog_visuals[index].get("plan_id", "") == problem.id:
				if is_instance_valid(fog_visuals[index].get("mesh")): fog_visuals[index].mesh.free()
				fog_visuals.remove_at(index)
		create_planned_element(records[problem.id])
		geometry_diagnostics.repairs.append(problem)
	geometry_diagnostics.unresolved = EnvironmentGeometryPlan.inspect_instances(geometry_plan, dungeon_data, fog_visuals)
	var expected: Dictionary = {}
	var actual: Dictionary = {}
	for record in geometry_plan.elements: expected[record.purpose] = int(expected.get(record.purpose, 0)) + 1
	for visual in fog_visuals: actual[visual.purpose] = int(actual.get(visual.purpose, 0)) + 1
	geometry_diagnostics["expected_planned"] = expected
	var expected_surfaces: Dictionary = {}
	for record in geometry_plan.surfaces: expected_surfaces[record.purpose] = int(expected_surfaces.get(record.purpose, 0)) + 1
	geometry_diagnostics["expected_surface_cells"] = expected_surfaces
	geometry_diagnostics["actual_meshes"] = actual
	geometry_diagnostics["validated"] = geometry_diagnostics.unresolved.is_empty()
	if geometry_diagnostics_enabled: print("ENVIRONMENT GEOMETRY ", geometry_diagnostics)
	return geometry_diagnostics.validated


func create_terrain_fill(preserve_terrain: bool = false) -> void:
	var layout := TerrainFillVisuals.layout(dungeon_data, terrain_fill_margin)
	var mode := upper_terrain_mode if upper_elevation_open_platforms and not preserve_terrain else UpperTerrainVisuals.Mode.UNLIMITED
	var pitch := 35.0
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get("pitch_degrees") != null: pitch = float(camera.get("pitch_degrees"))
	layout = UpperTerrainVisuals.prepare(dungeon_data, layout, mode, upper_filler_max_distance, terrace_band_width, terrace_irregular_edges, terrace_protected_clearance, pitch)
	terrain_metrics = layout.metrics
	terrain_fill_cells = layout.cells
	var ground_rules: Dictionary = CaveTerrainBackdrop.ground_rules(dungeon_data, {}) if cave_fill_active else {}
	var wall_top := TerrainFillVisuals.wall_top_offset(FLOOR_THICKNESS / 2.0)
	for tile: Vector2i in terrain_fill_cells:
		var entry: Dictionary = terrain_fill_cells[tile]
		# Upper walkways stay narrow. Their support is directly below the floor,
		# rather than the old wall-height filler spreading into neighboring void.
		if is_open_upper_tile(entry.owner) and dungeon_data.get_tile(entry.owner) == DungeonData.TileType.CORRIDOR:
			continue
		var open_platform := is_open_upper_tile(entry.owner)
		var top: float = entry.get("top", entry.height * ELEVATION_HEIGHT + (FLOOR_THICKNESS / 2.0 if open_platform else wall_top))
		if dungeon_data.get_elevation(entry.owner) == 0 and dungeon_data.get_tile(entry.owner) != DungeonData.TileType.RAMP:
			top = TerrainFillVisuals.wall_top_offset(FLOOR_THICKNESS / 2.0, conventional_wall_height_scale)
			if cave_fill_active and cave_ground_height_variation_enabled and dungeon_data.map_bounds.has_point(tile) and CaveTerrainBackdrop.can_vary(tile, ground_rules):
				top = CaveTerrainBackdrop.varied_top(tile, floor_visual_seed)
		var fill := MeshInstance3D.new()
		fill.name = "TerrainFill"
		fill.mesh = TerrainFillVisuals.mesh(top - float(layout.base), entry.distance == 1 and not open_platform and not entry.get("decorative", false))
		fill.position = Vector3(tile.x * TILE_SIZE, top, tile.y * TILE_SIZE)
		add_child(fill)
		register_fog_visual(fill, [tile], false, true)
		var visual: Dictionary = fog_visuals.back()
		visual.filler = true
		visual.candidate = true
		visual.fill_owner = entry.owner
		visual.fill_elevation = entry.elevation
		visual.fill_distance = entry.distance
	for skirt in layout.skirts:
		create_platform_skirt(skirt)


func create_platform_skirt(entry: Dictionary) -> void:
	var tile: Vector2i = entry.owner
	var direction: Vector2i = entry.direction
	var box := BoxMesh.new()
	box.size = Vector3(0.04 if direction.x != 0 else TILE_SIZE, entry.top - entry.bottom, 0.04 if direction.y != 0 else TILE_SIZE)
	box.material = TerrainFillVisuals.material()
	var mesh := MeshInstance3D.new()
	mesh.name = "PlatformStoneEdge"
	mesh.mesh = box
	mesh.position = Vector3(tile.x * TILE_SIZE + direction.x * (TILE_SIZE / 2.0 - 0.02), (entry.top + entry.bottom) / 2.0, tile.y * TILE_SIZE + direction.y * (TILE_SIZE / 2.0 - 0.02))
	add_child(mesh)
	register_fog_visual(mesh, [tile], false, true)
	var visual: Dictionary = fog_visuals.back()
	visual.filler = true
	visual.fill_owner = tile
	visual.fill_elevation = 1
	visual.fill_distance = 1
	visual["platform_edge"] = true
	visual["edge_direction"] = direction
	visual.materials[0] = ModularDungeonVisuals.materials(box.material, dim_material.albedo_color, other_elevation_material.albedo_color, ModularDungeonVisuals.FILL_COLOR)


func create_floor_tile(grid_position: Vector2i) -> void:
	if is_open_upper_tile(grid_position):
		for index in range(ModularDungeonVisuals.FLOOR.get_surface_count()):
			create_asset_surface(grid_position, ModularDungeonVisuals.surface_mesh(ModularDungeonVisuals.FLOOR, index), 0.0, false)
		if dungeon_data.get_tile(grid_position) == DungeonData.TileType.CORRIDOR and not validated_geometry_active:
			create_upper_corridor_support(grid_position)
		return
	var edges: Array[Vector2i] = []
	for direction: Vector2i in DungeonData.CARDINALS:
		if dungeon_data.get_tile(grid_position + direction) in [DungeonData.TileType.WALL, DungeonData.TileType.VOID]:
			edges.append(direction)
	var source: Mesh = ModularDungeonVisuals.FLOOR
	var rotation_angle: float = 0.0
	# Authored walls face +Z; the corner occupies +Z and +X.
	if edges.size() == 1:
		source = ModularDungeonVisuals.FLOOR_WALL
		rotation_angle = atan2(float(edges[0].x), float(edges[0].y))
	elif edges.size() == 2 and edges[0] != -edges[1]:
		source = ModularDungeonVisuals.CORNER
		for turn in range(4):
			var direction := Vector2i.DOWN
			for step in range(turn): direction = Vector2i(direction.y, -direction.x)
			if edges.has(direction) and edges.has(Vector2i(direction.y, -direction.x)):
				rotation_angle = turn * PI / 2.0
				break
	for index in range(source.get_surface_count()):
		var angle := rotation_angle
		if source == ModularDungeonVisuals.FLOOR and index == 0 and can_vary_floor(grid_position) and floor_quarter_turns_enabled:
			angle += float(posmod(floor_hash(grid_position), 4)) * PI / 2.0
		create_asset_surface(grid_position, ModularDungeonVisuals.surface_mesh(source, index), angle, index > 0)
	if source == ModularDungeonVisuals.FLOOR:
		for direction in edges:
			create_asset_surface(grid_position, ModularDungeonVisuals.WALL, atan2(float(direction.x), float(direction.y)), true)


func is_open_upper_tile(tile: Vector2i) -> bool:
	return upper_elevation_open_platforms and dungeon_data.get_elevation(tile) == 1


func create_upper_corridor_support(tile: Vector2i) -> void:
	if upper_corridor_support_height <= 0.0: return
	# Meet the actual imported floor underside, without overlapping its faces.
	var floor_bottom := ELEVATION_HEIGHT + FLOOR_THICKNESS / 2.0 + (ModularDungeonVisuals.FLOOR.get_aabb().position.y - ModularDungeonVisuals.FLOOR_TOP) * ModularDungeonVisuals.SOURCE_SCALE * TILE_SIZE
	var box := BoxMesh.new()
	box.size = Vector3(TILE_SIZE, upper_corridor_support_height, TILE_SIZE)
	box.material = TerrainFillVisuals.material()
	var support := MeshInstance3D.new()
	support.name = "UpperCorridorSupport"
	support.mesh = box
	support.position = Vector3(tile.x * TILE_SIZE, floor_bottom - upper_corridor_support_height / 2.0, tile.y * TILE_SIZE)
	add_child(support)
	register_fog_visual(support, [tile], false, true)
	var visual: Dictionary = fog_visuals.back()
	visual["support"] = true
	# Supporting stone uses the filler palette, independently of floor/wall art.
	visual.materials[0] = ModularDungeonVisuals.materials(box.material, dim_material.albedo_color, other_elevation_material.albedo_color, ModularDungeonVisuals.FILL_COLOR)


func floor_hash(tile: Vector2i) -> int:
	# Separate from every gameplay RNG; bounded inputs avoid 64-bit overflow.
	var value := posmod(tile.x * 73856093 ^ tile.y * 19349663 ^ posmod(floor_visual_seed, 1000000) * 83492791, 2147483647)
	value = posmod((value ^ (value >> 13)) * 1274126177, 2147483647)
	return value ^ (value >> 16)


func can_vary_floor(tile: Vector2i) -> bool:
	return floor_variation_enabled and dungeon_data.get_elevation(tile) == 0 and dungeon_data.get_tile(tile) in [DungeonData.TileType.FLOOR, DungeonData.TileType.CORRIDOR] and not dungeon_data.reserved_transitions.has(tile)


func create_asset_surface(tile: Vector2i, mesh: Mesh, angle: float, wall: bool) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.scale = Vector3.ONE * ModularDungeonVisuals.SOURCE_SCALE * TILE_SIZE
	if wall and dungeon_data.get_elevation(tile) == 0:
		visual.scale.y *= conventional_wall_height_scale
	visual.rotation.y = angle
	visual.position = grid_to_world(tile, dungeon_data.get_elevation(tile))
	# Scale isolated wall surfaces around the floor contact plane, never around
	# the origin of a combined floor-wall/corner model.
	visual.position.y += FLOOR_THICKNESS / 2.0 - ModularDungeonVisuals.FLOOR_TOP * visual.scale.y
	add_child(visual)
	register_fog_visual(visual, [tile], false, true, wall)
	if not wall and can_vary_floor(tile):
		var bucket := posmod(floor_hash(tile) / 4, 9)
		var factor := 1.0 + (float(bucket) / 4.0 - 1.0) * floor_color_variation
		var source := mesh.surface_get_material(0)
		fog_visuals.back().materials[0] = ModularDungeonVisuals.materials(source, dim_material.albedo_color, other_elevation_material.albedo_color, ModularDungeonVisuals.FLOOR_COLOR * Color(factor, factor, factor, 1.0))

func create_ramp_tile(grid_position: Vector2i) -> void:
	# Legacy fixture retains its one-tile footprint using the same height scale.
	create_slope(grid_position, Vector2i.RIGHT, dungeon_data.get_elevation(grid_position), 1)


func create_ramp_segment(segment: Dictionary) -> void:
	create_slope(segment.lower_buffer + segment.direction, segment.direction, segment.lower, 3)


func create_slope(first_tile: Vector2i, uphill: Vector2i, lower: int, tile_count: int) -> void:
	# Each rising tile gets one complete stair asset, stacked along +X.
	var mesh_instance: MeshInstance3D = RAMP_VISUAL.instantiate()
	mesh_instance.mesh = ModularDungeonVisuals.ramp_mesh(tile_count, stair_seams_enabled)
	mesh_instance.basis = Basis(Vector3.UP, -atan2(float(uphill.y), float(uphill.x)))
	var origin := grid_to_world(first_tile, lower) - Vector3(uphill.x, 0, uphill.y) * TILE_SIZE / 2.0
	origin.y += FLOOR_THICKNESS / 2.0
	mesh_instance.position = origin
	add_child(mesh_instance)
	var covered: Array[Vector2i] = []
	for index in range(tile_count):
		covered.append(first_tile + uphill * index)
	register_fog_visual(mesh_instance, covered, false, true)
	ModularDungeonVisuals.tread_fraction(0, 1)


func get_ramp_visual_offset(tile: Vector2i) -> Vector3:
	# Stepped art is decorative: actor roots retain linear logical heights.
	if dungeon_data.legacy_ramp and dungeon_data.get_tile(tile) == DungeonData.TileType.RAMP:
		return Vector3.UP * maxf(0.0, (ModularDungeonVisuals.tread_fraction(0, 1) - 0.5) * ELEVATION_HEIGHT)
	if not dungeon_data.ramp_tiles.has(tile): return Vector3.ZERO
	var difference := ModularDungeonVisuals.tread_fraction(0, 1) - 0.5
	return Vector3.UP * maxf(0.0, difference * ELEVATION_HEIGHT / 3.0)


func create_stairs_tile(grid_position: Vector2i) -> void:
	create_floor_tile(grid_position)
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TILE_SIZE * 0.6, 0.15, TILE_SIZE * 0.6)
	marker.mesh = box
	marker.position = grid_to_world(grid_position, dungeon_data.get_elevation(grid_position)) + Vector3(0, 0.2, 0)
	add_child(marker)
	register_fog_visual(marker, [grid_position], true)
	var illustration: Node3D = STAIRS_VISUAL.instantiate()
	illustration.set_meta("geometry_purpose", "stairs_art")
	illustration.set_meta("geometry_owner", grid_position)
	illustration.position = Vector3(0, box.size.y / 2.0 + 0.005, box.size.z / 2.0)
	illustration.scale = Vector3.ONE * TILE_SIZE
	marker.add_child(illustration)


func register_fog_visual(mesh: MeshInstance3D, covered: Array[Vector2i], stairs: bool = false, asset: bool = false, wall: bool = false) -> void:
	var tile: Vector2i = covered[0]
	var room := dungeon_data.get_room_id(tile)
	var terrain_candidate := room >= 0 or dungeon_data.get_tile(tile) in [DungeonData.TileType.CORRIDOR, DungeonData.TileType.RAMP] or dungeon_data.reserved_transitions.has(tile)
	var candidate := terrain_candidate
	var materials: Array = []
	if asset:
		for index in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(index)
			var albedo: Color = source.albedo_color if source is StandardMaterial3D else Color.WHITE
			if wall:
				albedo = ModularDungeonVisuals.WALL_COLOR
			elif not stairs and dungeon_data.get_tile(tile) in [DungeonData.TileType.FLOOR, DungeonData.TileType.CORRIDOR, DungeonData.TileType.STAIRS]:
				albedo = ModularDungeonVisuals.FLOOR_COLOR
			materials.append(ModularDungeonVisuals.materials(source, dim_material.albedo_color, other_elevation_material.albedo_color, albedo))
	fog_visuals.append({"mesh": mesh, "tiles": covered, "stairs": stairs, "room": room, "candidate": candidate or wall, "occluded": false, "fog_visible": true, "asset": asset, "wall": wall, "filler": false, "materials": materials, "fog_state": 0})
	var purpose := "wall" if wall else ("stairs_marker" if stairs else ("ramp" if dungeon_data.get_tile(tile) == DungeonData.TileType.RAMP else "floor"))
	fog_visuals.back()["purpose"] = purpose
	fog_visuals.back()["owner"] = tile
	mesh.set_meta("geometry_purpose", purpose)
	mesh.set_meta("geometry_owner", tile)


func apply_fog(reference_elevation: int = 0) -> void:
	_occlusion_context.clear()
	for visual in fog_visuals:
		var bright := false
		for tile: Vector2i in visual.tiles:
			if dungeon_data.is_bright(tile):
				bright = true
				break
		var filler: bool = visual.get("filler", false)
		if filler:
			bright = visual.fill_distance == 1 and dungeon_data.is_bright(visual.fill_owner)
		var mesh: MeshInstance3D = visual.mesh
		visual.fog_visible = bright if visual.stairs else true
		apply_occlusion_state(visual)
		mesh.material_override = normal_material if bright else dim_material
		var tile: Vector2i = visual.tiles[0]
		var elevation_shaded: bool = filler or visual.room >= 0 or dungeon_data.get_tile(tile) == DungeonData.TileType.CORRIDOR
		var elevation: int = visual.fill_elevation if filler else dungeon_data.get_elevation(tile)
		if not bright and elevation_shaded and elevation != reference_elevation:
			mesh.material_override = other_elevation_material
		visual.fog_state = 0 if bright else (2 if mesh.material_override == other_elevation_material else 1)
		if visual.asset:
			mesh.material_override = null
			for index in range(visual.materials.size()):
				mesh.set_surface_override_material(index, visual.materials[index][visual.fog_state])
	if is_instance_valid(cave_background):
		cave_background.apply_fog(dungeon_data, reference_elevation, dim_material.albedo_color, other_elevation_material.albedo_color)


func update_occlusion(camera: Camera3D, player_tile: Vector2i, sprite_points: Array[Vector3]) -> void:
	if dungeon_data == null:
		return
	# Coalesce identical requests within a frame, never across animation frames.
	# Copy points when storing: callers may reuse/mutate their input array.
	var frame := Engine.get_process_frames()
	var context: Array = [camera.get_instance_id(), camera.get_camera_transform(),
		camera.get_camera_projection(), camera.get_viewport().get_visible_rect(),
		global_transform, player_tile, obstructing_wall_opacity, sprite_points]
	if _occlusion_frame == frame and _occlusion_context == context:
		return
	_occlusion_frame = frame
	_occlusion_context = context
	_occlusion_context[7] = sprite_points.duplicate()
	var player_room := dungeon_data.get_room_id(player_tile)
	var ray_origins: Array[Vector3] = []
	for target in sprite_points:
		ray_origins.append(camera.project_ray_origin(camera.unproject_position(target)))
	for visual in fog_visuals:
		var mesh: MeshInstance3D = visual.mesh
		visual.occluded = false
		var tile: Vector2i = visual.tiles[0]
		# A slope extends above its stored lower elevation. Buffers retain their
		# own flat heights and remain independently hideable.
		var top_elevation := float(dungeon_data.get_elevation(tile))
		if dungeon_data.get_tile(tile) == DungeonData.TileType.RAMP:
			top_elevation += 1.0
		var higher_terrain := top_elevation > dungeon_data.surface_elevation(player_tile)
		var own_room: bool = player_room >= 0 and visual.room == player_room
		var fade_visual: bool = visual.wall or visual.get("filler", false)
		var foreground := true
		if fade_visual:
			var center := mesh.global_transform * mesh.get_aabb().get_center()
			var player_world := get_entity_world_position(player_tile)
			var toward_camera := camera.global_position - player_world
			toward_camera.y = 0.0
			# Rear walls stay solid even when the billboard leans behind the feet.
			foreground = (center - player_world).dot(toward_camera) > 0.001
			if visual.get("filler", false):
				# Distant filler outside the viewing stripe cannot cover the sprite.
				var side := Vector3(-toward_camera.z, 0, toward_camera.x).normalized()
				foreground = foreground and absf((center - player_world).dot(side)) <= TILE_SIZE * 2.0
		if foreground and visual.candidate and (higher_terrain or fade_visual) and (not own_room or fade_visual) and (not visual.tiles.has(player_tile) or fade_visual) and visual.fog_visible:
			# Transform the segment into the mesh's local frame. This tests its
			# actual oriented bounds rather than an inflated world-space AABB.
			var inverse := mesh.global_transform.affine_inverse()
			var bounds := mesh.get_aabb()
			for index in range(sprite_points.size()):
				if bounds.intersects_segment(inverse * ray_origins[index], inverse * sprite_points[index]) != null:
					visual.occluded = true
					break
		apply_occlusion_state(visual)


func apply_occlusion_state(visual: Dictionary) -> void:
	var mesh: MeshInstance3D = visual.mesh
	var fade_visual: bool = visual.wall or visual.get("filler", false)
	mesh.visible = visual.fog_visible and (fade_visual or not visual.occluded)
	mesh.transparency = 1.0 - obstructing_wall_opacity if fade_visual and visual.occluded else 0.0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if fade_visual and visual.occluded else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func get_rear_wall_visual_offset(camera: Camera3D, tile: Vector2i, points: Array[Vector3]) -> Vector3:
	# Billboards lean behind their feet. Move only the visual along the view ray
	# when it intersects a nearby rear wall, allowing that wall to stay opaque.
	var player_world := get_entity_world_position(tile)
	var direction := (camera.global_position - player_world).normalized()
	var horizontal := Vector3(direction.x, 0, direction.z)
	var distance := 0.0
	for visual in fog_visuals:
		if not visual.wall and not visual.get("filler", false): continue
		var delta: Vector2i = visual.tiles[0] - tile
		if absi(delta.x) + absi(delta.y) > 1: continue
		var mesh: MeshInstance3D = visual.mesh
		var bounds := mesh.get_aabb()
		var center := mesh.global_transform * bounds.get_center()
		if (center - player_world).dot(horizontal) >= 0.0: continue
		var inverse := mesh.global_transform.affine_inverse()
		for point in points:
			var hit = bounds.intersects_segment(inverse * (point + direction * TILE_SIZE * 2.0), inverse * point)
			if hit != null:
				distance = maxf(distance, (mesh.global_transform * Vector3(hit) - point).dot(direction) + 0.005)
	return direction * distance


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
