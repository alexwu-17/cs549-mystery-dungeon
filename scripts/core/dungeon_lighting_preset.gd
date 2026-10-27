class_name DungeonLightingPreset
extends Resource
## Lighting only. No material, gameplay, camera or geometry ownership.
@export var display_name: String = "A - Current baseline"
@export var restore_scene_baseline: bool = false
@export var sun_rotation_degrees := Vector3(-48,-32,0)
@export var sun_color := Color(1.0,0.94,0.84)
@export_range(0.0,2.0,0.01) var sun_energy: float = 1.0
@export_range(0.0,2.0,0.05) var sun_angular_distance: float = 0.5
@export var ambient_color := Color(0.78,0.85,1.0)
@export_range(0.0,1.0,0.01) var ambient_energy: float = 0.30
@export var shadow_bias: float = 0.025
@export var shadow_normal_bias: float = 0.12
@export var ssao_enabled: bool = false
@export var ssao_radius: float = 0.65
@export var ssao_intensity: float = 0.55
@export var ssao_power: float = 1.15
@export var ssao_detail: float = 0.35
