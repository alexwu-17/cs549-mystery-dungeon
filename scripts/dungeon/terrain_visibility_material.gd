class_name TerrainVisibilityMaterial
extends RefCounted
const LIGHT = preload("res://shaders/rounded_visibility_light.gdshader")
const FADE = preload("res://shaders/rounded_visibility_wall.gdshader")
var materials: Dictionary = {}
var center := Vector3.ZERO

func get_material(source: StandardMaterial3D, shadow: StandardMaterial3D, rounded: bool, fade: bool, opacity: float) -> ShaderMaterial:
	var key := "%d:%d:%s:%s:%f" % [source.get_instance_id(), shadow.get_instance_id(), rounded, fade, opacity]
	if materials.has(key): return materials[key]
	var material := ShaderMaterial.new()
	material.shader = FADE if fade else LIGHT
	material.set_shader_parameter("bright_color", linear_color(source.albedo_color))
	material.set_shader_parameter("shadow_color", linear_color(shadow.albedo_color))
	material.set_shader_parameter("rounded_light", rounded)
	material.set_shader_parameter("roughness_value", source.roughness)
	material.set_shader_parameter("specular_value", source.metallic_specular)
	material.set_shader_parameter("metallic_value", source.metallic)
	material.set_shader_parameter("use_roughness", source.roughness_texture != null)
	if source.roughness_texture != null:
		material.set_shader_parameter("roughness_texture", source.roughness_texture)
		var channels := [Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.ONE/3.0, Vector3.ONE/3.0]
		material.set_shader_parameter("roughness_channel", channels[source.roughness_texture_channel])
	material.set_shader_parameter("use_texture", source.albedo_texture != null)
	material.set_shader_parameter("use_normal", source.normal_enabled and source.normal_texture != null)
	material.set_shader_parameter("triplanar", source.uv1_triplanar and source.uv1_world_triplanar)
	material.set_shader_parameter("uv_scale", source.uv1_scale)
	material.set_shader_parameter("uv_offset", source.uv1_offset)
	material.set_shader_parameter("normal_strength", source.normal_scale)
	material.set_shader_parameter("triplanar_sharpness", source.uv1_triplanar_sharpness)
	material.set_shader_parameter("wall_opacity", opacity)
	if source.albedo_texture != null: material.set_shader_parameter("surface_texture", source.albedo_texture)
	if source.normal_texture != null: material.set_shader_parameter("normal_texture", source.normal_texture)
	set_center(material)
	materials[key] = material
	return material

static func linear_color(color: Color) -> Vector3:
	var linear := color.srgb_to_linear()
	return Vector3(linear.r,linear.g,linear.b)

func set_center(material: ShaderMaterial) -> void:
	material.set_shader_parameter("visibility_center", Vector2(center.x,center.z))
	material.set_shader_parameter("visibility_ground", center.y)
	material.set_shader_parameter("visibility_height", center.y + 0.6)

func update_center(position: Vector3) -> void:
	if center.is_equal_approx(position): return
	center = position
	for material: ShaderMaterial in materials.values(): set_center(material)

func warm_up(parent: Node3D, visuals: Array[Dictionary]) -> void:
	if DisplayServer.get_name() == "headless": return
	var camera := parent.get_viewport().get_camera_3d()
	if camera == null: return
	# Use the real vertex layouts and follow the camera. A world-fixed proxy can
	# leave the view when setup positions the camera, leaving the pipeline cold.
	var sources: Dictionary = {}
	for visual in visuals:
		var mesh: Mesh = visual.mesh.mesh
		var layout := str(mesh.surface_get_format(0)) if mesh is ArrayMesh else mesh.get_class()
		sources[layout] = mesh
	for shader: Shader in [LIGHT, FADE]:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("warmup", true)
		for source: Mesh in sources.values():
			var warm := MeshInstance3D.new()
			warm.name = "VisibilityPipelineWarmup"
			warm.mesh = source
			warm.material_override = material
			warm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			camera.add_child(warm)
			warm.scale = Vector3.ONE * 0.000001
			warm.position = Vector3(0,0,-1) - source.get_aabb().get_center()*0.000001
			parent.tree_exiting.connect(warm.queue_free, CONNECT_ONE_SHOT)
			RenderingServer.frame_post_draw.connect(warm.queue_free, CONNECT_ONE_SHOT)
