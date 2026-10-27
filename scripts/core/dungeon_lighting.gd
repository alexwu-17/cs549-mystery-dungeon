class_name DungeonLighting
extends Node
## Event-driven development presets; original scene lighting is captured exactly.
@export var preset_a: DungeonLightingPreset = preload("res://config/lighting/baseline.tres")
@export var preset_b: DungeonLightingPreset = preload("res://config/lighting/natural_sunlight.tres")
@export var preset_c: DungeonLightingPreset = preload("res://config/lighting/atmospheric.tres")
@export_enum("A - Baseline", "B - Natural sunlight", "C - Atmospheric") var selected_preset: int = 0
@export var debug_switch_enabled: bool = true
var sun: DirectionalLight3D
var world: WorldEnvironment
var baseline_light: Dictionary = {}
var baseline_environment: Environment
signal preset_changed(index: int, title: String)
const LIGHT_PROPERTIES = [&"transform",&"light_color",&"light_energy",&"light_angular_distance",&"shadow_enabled",&"shadow_bias",&"shadow_normal_bias"]

func _ready() -> void:
	sun = get_node("../DirectionalLight3D")
	world = get_node("../WorldEnvironment")
	for property in LIGHT_PROPERTIES: baseline_light[property] = sun.get(property)
	baseline_environment = world.environment.duplicate(true)
	apply_preset(selected_preset)
	set_process_unhandled_key_input(debug_switch_enabled and OS.is_debug_build())

func apply_preset(index: int) -> void:
	assert(index >= 0 and index < 3)
	selected_preset = index
	if not is_instance_valid(sun): return # Inspector selection before ready.
	for property in baseline_light: sun.set(property,baseline_light[property])
	# Never mutate the PackedScene's shared Environment, nor another Main scene.
	world.environment = baseline_environment.duplicate(true)
	var preset: DungeonLightingPreset = [preset_a,preset_b,preset_c][index]
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
	preset_changed.emit(index,preset.display_name)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		apply_preset((selected_preset+1)%3)
		print("LIGHTING: ",[preset_a,preset_b,preset_c][selected_preset].display_name)
		get_viewport().set_input_as_handled()
