class_name CorridorDreadBackdrop
extends MeshInstance3D
## World-oriented distant sky decoration; scene lighting, fog and WorldEnvironment stay owned
## by their normal helpers. The GPU selects one pre-baked PixelFX frame.
const SHADER: Shader = preload("res://scripts/effects/corridor_dread_backdrop.gdshader")

func _init() -> void:
	name = "CorridorDreadSky"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("sky_sheet", load("res://assets/effects/pixelfx/dread_sky.png"))
	material.set_shader_parameter("eclipse_sheet", load("res://assets/effects/pixelfx/dread_eclipse.png"))
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ignore_occlusion_culling = true

func follow_camera(camera: Camera3D) -> void:
	# Keep culling bounds inside the view; the shader places the quad behind all
	# dungeon geometry, at the far depth of the reversed-Z projection.
	# The fragment shader projects world view rays, so the artwork itself does
	# not follow camera rotation despite this culling-only transform.
	global_transform = camera.global_transform.translated_local(Vector3(0, 0, -10))
