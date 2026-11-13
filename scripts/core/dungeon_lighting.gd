class_name DungeonLighting
extends Node
## Event-driven development presets; original scene lighting is captured exactly.
@export var preset_a: DungeonLightingPreset = preload("res://config/lighting/baseline.tres")
@export var preset_b: DungeonLightingPreset = preload("res://config/lighting/natural_sunlight.tres")
@export var preset_c: DungeonLightingPreset = preload("res://config/lighting/atmospheric.tres")
@export var preset_d: DungeonLightingPreset = preload("res://config/lighting/spring_hd2d.tres")
@export_enum("A - Baseline", "B - Natural sunlight", "C - Atmospheric", "D - Spring HD-2D") var selected_preset: int = 0
@export var debug_switch_enabled: bool = true
var sun: DirectionalLight3D
var world: WorldEnvironment
var baseline_light: Dictionary = {}
var baseline_environment: Environment
var baseline_camera_attributes: CameraAttributes
signal preset_changed(index: int, title: String)
const PRESET_COUNT := 4
const LIGHT_PROPERTIES = [&"transform",&"light_color",&"light_energy",&"light_angular_distance",&"shadow_enabled",&"shadow_bias",&"shadow_normal_bias"]

func _ready() -> void:
	sun = get_node("../DirectionalLight3D")
	world = get_node("../WorldEnvironment")
	for property in LIGHT_PROPERTIES: baseline_light[property] = sun.get(property)
	baseline_environment = world.environment.duplicate(true)
	baseline_camera_attributes = world.camera_attributes
	apply_preset(selected_preset)
	set_process_unhandled_key_input(debug_switch_enabled and OS.is_debug_build())

func apply_preset(index: int) -> void:
	assert(index >= 0 and index < PRESET_COUNT)
	selected_preset = index
	if not is_instance_valid(sun): return # Inspector selection before ready.
	for property in baseline_light: sun.set(property,baseline_light[property])
	# Never mutate the PackedScene's shared Environment, nor another Main scene.
	world.environment = baseline_environment.duplicate(true)
	world.camera_attributes = baseline_camera_attributes
	var preset: DungeonLightingPreset = presets()[index]
	if not preset.restore_scene_baseline:
		sun.rotation_degrees = preset.sun_rotation_degrees
		sun.light_color = preset.sun_color
		sun.light_energy = preset.sun_energy
		sun.light_angular_distance = preset.sun_angular_distance
		sun.shadow_bias = preset.shadow_bias
		sun.shadow_normal_bias = preset.shadow_normal_bias
		var environment := world.environment
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = preset.ambient_color
		environment.ambient_light_energy = preset.ambient_energy
		environment.ssao_enabled = preset.ssao_enabled
		environment.ssao_radius = preset.ssao_radius
		environment.ssao_intensity = preset.ssao_intensity
		environment.ssao_power = preset.ssao_power
		environment.ssao_detail = preset.ssao_detail
		_apply_post_processing(environment, preset)
	preset_changed.emit(index,preset.display_name)


func presets() -> Array[DungeonLightingPreset]:
	return [preset_a, preset_b, preset_c, preset_d]


func _apply_post_processing(environment: Environment, preset: DungeonLightingPreset) -> void:
	# Screen-space HD-2D stack. Volumetric fog stays owned by SunlightAtmosphere.
	environment.glow_enabled = preset.glow_enabled
	if preset.glow_enabled:
		environment.glow_intensity = preset.glow_intensity
		environment.glow_bloom = preset.glow_bloom
		environment.glow_hdr_threshold = preset.glow_hdr_threshold
		environment.glow_blend_mode = preset.glow_blend_mode as Environment.GlowBlendMode
	environment.fog_enabled = preset.depth_fog_enabled
	if preset.depth_fog_enabled:
		environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		environment.fog_light_color = preset.fog_light_color
		environment.fog_light_energy = preset.fog_light_energy
		environment.fog_density = preset.fog_density
		environment.fog_aerial_perspective = preset.fog_aerial_perspective
		environment.fog_sky_affect = 0.0
		environment.fog_height_density = 0.0
	environment.adjustment_enabled = preset.adjustments_enabled
	if preset.adjustments_enabled:
		environment.adjustment_brightness = preset.adjustment_brightness
		environment.adjustment_contrast = preset.adjustment_contrast
		environment.adjustment_saturation = preset.adjustment_saturation
	environment.tonemap_mode = preset.tonemap_mode as Environment.ToneMapper
	environment.tonemap_exposure = preset.tonemap_exposure
	if preset.far_blur_enabled:
		var attributes := CameraAttributesPractical.new()
		attributes.dof_blur_far_enabled = true
		attributes.dof_blur_far_distance = preset.far_blur_distance
		attributes.dof_blur_far_transition = preset.far_blur_transition
		attributes.dof_blur_near_enabled = false
		attributes.dof_blur_amount = preset.far_blur_amount
		world.camera_attributes = attributes

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		apply_preset((selected_preset+1)%PRESET_COUNT)
		print("LIGHTING: ",presets()[selected_preset].display_name)
		get_viewport().set_input_as_handled()
