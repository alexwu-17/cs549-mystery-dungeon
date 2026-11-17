class_name SpiritombRoomStyle
extends Node
## Room-local material copies and reversible lighting. Never edits source art.
const FLOOR_TINT := Color(0.48, 0.25, 0.68)
const STONE_TINT := Color(0.14, 0.055, 0.23)
var camera: Camera3D
var original_environment: Environment
var room_environment: Environment
var sun: DirectionalLight3D
var sun_was_visible: bool
var atmosphere: SunlightAtmosphere
var original_mode: int

func apply(main: Node3D, surround: FinalCorridorEnvironment) -> void:
	camera = main.presentation_camera
	original_environment = camera.environment
	var source: Environment = original_environment if original_environment != null else main.get_node("WorldEnvironment").environment
	room_environment = source.duplicate(true)
	room_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room_environment.ambient_light_color = Color(0.85, 0.8, 1.0)
	room_environment.ambient_light_energy = 0.7
	room_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	room_environment.background_mode = Environment.BG_COLOR
	room_environment.background_color = Color(0.015, 0.005, 0.025)
	camera.environment = room_environment
	sun = main.get_node("DirectionalLight3D")
	sun_was_visible = sun.visible
	sun.hide()
	atmosphere = main.get_node("SunlightAtmosphere")
	original_mode = atmosphere.selected_mode
	atmosphere.apply_mode(SunlightAtmosphere.Mode.ORIGINAL)
	# Replace only these floor instances' fog palettes. Preserve texture detail,
	# independent fog states and renderer-owned occlusion material selection.
	var renderer: DungeonRenderer = main.dungeon_renderer
	for visual in renderer.fog_visuals:
		var tint: Color = STONE_TINT if visual.wall or visual.get("filler",false) else FLOOR_TINT
		var surfaces: Array = []
		for states: Array in visual.materials:
			var replacements: Array[Material] = []
			for index in range(states.size()):
				var material: StandardMaterial3D = states[index].duplicate()
				CaveStoneMaterial.configure(material)
				material.albedo_color = tint * (Color.WHITE if index == 0 else renderer.dim_material.albedo_color if index == 1 else renderer.other_elevation_material.albedo_color)
				replacements.append(material)
			surfaces.append(replacements)
		visual.materials = surfaces
		visual.erase("binding_key")
	for child in surround.get_children():
		if child is GeometryInstance3D and child.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = child.material_override.duplicate()
			material.albedo_color = STONE_TINT
			child.material_override = material

func _exit_tree() -> void:
	if is_instance_valid(camera) and camera.environment == room_environment:
		camera.environment = original_environment
	if is_instance_valid(sun): sun.visible = sun_was_visible
	if is_instance_valid(atmosphere) and atmosphere.is_inside_tree():
		atmosphere.apply_mode(original_mode)
