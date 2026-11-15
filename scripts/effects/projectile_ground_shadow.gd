extends MeshInstance3D
## Rendering-only projection. Reads the current surface and fog; never changes them.

const SHADER: Shader = preload("res://scripts/effects/projectile_shadow.gdshader")
var dungeon: DungeonData
var terrain: Node3D
var lane: Vector3
var shadow_material: ShaderMaterial


func setup(data: DungeonData, renderer: Node3D, texture: Texture2D, direction: Vector3, hollow: bool) -> void:
	dungeon = data
	terrain = renderer
	lane = Vector3(direction.x, 0, direction.z).normalized()
	var plane := PlaneMesh.new()
	plane.size = Vector2(64, 48) * ProjectileEffect.PIXEL_SIZE
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow_material = ShaderMaterial.new()
	shadow_material.shader = SHADER
	shadow_material.set_shader_parameter("sheet_texture", texture)
	shadow_material.set_shader_parameter("hollow", hollow)
	material_override = shadow_material


func update_projection(head: Vector3, time: float) -> void:
	# Match the source frame's (48,24) anchor, not the center of its long wake.
	var center := head - lane * (16.0 * ProjectileEffect.PIXEL_SIZE)
	var tile := Vector2i(roundi(center.x / DungeonData.TILE_SIZE), roundi(center.z / DungeonData.TILE_SIZE))
	visible = dungeon.is_walkable(tile)
	if not visible:
		return
	var normal := Vector3.UP
	var slope := Vector3.ZERO
	if dungeon.ramp_tiles.has(tile):
		var segment: Dictionary = dungeon.ramp_segments[dungeon.ramp_tiles[tile].segment]
		var uphill := Vector2i(segment.direction)
		slope = Vector3(uphill.x, 0, uphill.y) * DungeonData.ELEVATION_HEIGHT / (3.0 * DungeonData.TILE_SIZE)
	elif dungeon.legacy_ramp and dungeon.get_tile(tile) == DungeonData.TileType.RAMP:
		slope = Vector3.RIGHT * DungeonData.ELEVATION_HEIGHT / DungeonData.TILE_SIZE
	var surface: Vector3 = terrain.get_entity_world_position(tile)
	center.y = surface.y + slope.dot(center - surface) + 0.02
	normal = Vector3(-slope.x, 1, -slope.z).normalized()
	var tangent := (lane - normal * lane.dot(normal)).normalized()
	global_basis = Basis(tangent, normal, tangent.cross(normal))
	global_position = center
	var frame := minf(time * 60.0, 47.0)
	shadow_material.set_shader_parameter("frame_index", floorf(frame))
	shadow_material.set_shader_parameter("frame_blend", fposmod(frame, 1.0))
	shadow_material.set_shader_parameter("fade_amount", 1.0 - smoothstep(2.75, 4.0, time / ProjectileEffect.SECONDS_PER_TILE))
	var darkness := 0.35 if dungeon.bright_tiles.has(tile) else (0.65 if dungeon.discovered_tiles.has(tile) else 0.8)
	shadow_material.set_shader_parameter("darkness", darkness)
