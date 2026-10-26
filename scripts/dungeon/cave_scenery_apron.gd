class_name CaveSceneryApron
extends MeshInstance3D
## Four distant ground strips, sized at construction/resize rather than per frame.
var visual_bounds: Rect2i
var detailed_bounds: Rect2i
var guard_margin: int = 0
var _logical_bounds: Rect2i
var _max_surface: float
var _camera: Camera3D

func setup(data: DungeonData, bounds: Rect2i, camera: Camera3D) -> void:
	_logical_bounds = data.map_bounds
	detailed_bounds = bounds
	_camera = camera
	_max_surface = 0.1
	for tile in data.tiles:
		if data.is_walkable(tile):
			_max_surface = maxf(_max_surface, data.surface_elevation(tile) * DungeonData.ELEVATION_HEIGHT + 0.1)
	material_override = TerrainFillVisuals.material().duplicate()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("geometry_purpose", "distant_cave_scenery")
	_rebuild()
	get_viewport().size_changed.connect(_rebuild)

func _rebuild() -> void:
	var width := _logical_bounds.position.x - detailed_bounds.position.x
	guard_margin = width + 12
	if is_instance_valid(_camera):
		var offset: Variant = _camera.get("follow_offset")
		if offset is Vector3:
			guard_margin = width + 2
			var origin: Vector3 = offset + Vector3(0, _max_surface, 0)
			origin += _camera.get_camera_transform().origin - _camera.global_position
			var size := _camera.get_viewport().get_visible_rect().size
			for corner in [Vector2.ZERO, Vector2(size.x,0), size, Vector2(0,size.y)]:
				var ray := _camera.project_ray_normal(corner)
				# Current 35-degree perspective has all corners pointing down.
				var travel := (CaveTerrainBackdrop.GROUND_BASE - origin.y) / minf(ray.y, -0.01)
				var hit := origin + ray * travel
				guard_margin = maxi(guard_margin, ceili(maxf(absf(hit.x),absf(hit.z))) + 2)
	visual_bounds = _logical_bounds.grow(guard_margin)
	var outer := Rect2(Vector2(visual_bounds.position)-Vector2.ONE*0.5,Vector2(visual_bounds.size))
	var inner := Rect2(Vector2(detailed_bounds.position)-Vector2.ONE*0.5,Vector2(detailed_bounds.size))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip(surface,Rect2(outer.position,Vector2(outer.size.x,inner.position.y-outer.position.y)))
	_strip(surface,Rect2(Vector2(outer.position.x,inner.end.y),Vector2(outer.size.x,outer.end.y-inner.end.y)))
	_strip(surface,Rect2(Vector2(outer.position.x,inner.position.y),Vector2(inner.position.x-outer.position.x,inner.size.y)))
	_strip(surface,Rect2(Vector2(inner.end.x,inner.position.y),Vector2(outer.end.x-inner.end.x,inner.size.y)))
	mesh = surface.commit()
	set_meta("geometry_bounds", visual_bounds)

func _strip(surface: SurfaceTool, rect: Rect2) -> void:
	var plane := PlaneMesh.new()
	plane.size = rect.size
	var top := TerrainFillVisuals.wall_top_offset(0.1,0.5)
	surface.append_from(plane,0,Transform3D(Basis.IDENTITY,Vector3(rect.get_center().x,top,rect.get_center().y)))

func apply_shade(shade: Color) -> void:
	var material := material_override as StandardMaterial3D
	material.albedo_color = ModularDungeonVisuals.FILL_COLOR * shade
