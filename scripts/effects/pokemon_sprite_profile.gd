class_name PokemonSpriteProfile
extends Resource

## Visual-only species settings. XML remains authoritative for frame sizes/timing.
@export var display_name: String = ""
@export_dir var directory: String
@export var pixel_size: float = 0.04
@export var body_to_ground: float = 8.0
@export var animations: Dictionary = {"Idle": "Idle", "Walk": "Walk", "Attack": "Attack", "Hurt": "Hurt"}
## Zero-based release pose per move; XML HitFrame can describe charging instead.
@export var projectile_release_frames: Dictionary = {}
## World-unit offsets: down is relative to the tile (+Z is forward); other
## directions are relative to the visible release-pose center beneath the sprite.
@export var projectile_offsets: Dictionary = {
	"up": Vector3.ZERO,
	"left": Vector3.ZERO,
	"right": Vector3.ZERO,
	"down": Vector3(0, 0.4, 0.25),
}
@export_range(0.1,5.0,0.05) var defeat_minimum_duration: float = 0.8
@export_range(0.02,0.5,0.005) var defeat_blink_interval: float = 0.075
