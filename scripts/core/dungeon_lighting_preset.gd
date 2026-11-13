class_name DungeonLightingPreset
extends Resource
## Lighting and screen-space post-processing only. No material, gameplay,
## camera framing or geometry ownership. Post-processing defaults are off so
## existing presets keep their exact behavior.
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
@export_group("HD-2D post-processing")
@export var glow_enabled: bool = false
@export_range(0.0, 2.0, 0.01) var glow_intensity: float = 0.4
@export_range(0.0, 1.0, 0.01) var glow_bloom: float = 0.05
@export_range(0.0, 4.0, 0.01) var glow_hdr_threshold: float = 1.0
@export_enum("Additive", "Screen", "Softlight", "Replace", "Mix") var glow_blend_mode: int = 2
@export var depth_fog_enabled: bool = false
@export var fog_light_color := Color(0.78, 0.86, 0.74)
@export_range(0.0, 2.0, 0.01) var fog_light_energy: float = 1.0
@export_range(0.0, 0.2, 0.001) var fog_density: float = 0.012
@export_range(0.0, 1.0, 0.01) var fog_aerial_perspective: float = 0.6
@export var far_blur_enabled: bool = false
@export_range(1.0, 100.0, 0.5) var far_blur_distance: float = 19.0
@export_range(0.1, 50.0, 0.5) var far_blur_transition: float = 14.0
@export_range(0.0, 1.0, 0.01) var far_blur_amount: float = 0.06
@export var adjustments_enabled: bool = false
@export_range(0.5, 2.0, 0.01) var adjustment_brightness: float = 1.0
@export_range(0.5, 2.0, 0.01) var adjustment_contrast: float = 1.0
@export_range(0.0, 2.0, 0.01) var adjustment_saturation: float = 1.0
@export_enum("Linear", "Reinhard", "Filmic", "ACES") var tonemap_mode: int = 0
@export_range(0.1, 4.0, 0.01) var tonemap_exposure: float = 1.0
