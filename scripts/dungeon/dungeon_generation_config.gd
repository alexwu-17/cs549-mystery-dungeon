class_name DungeonGenerationConfig
extends Resource

enum ElevationMode { TWO_LEVEL, LEGACY_THREE_LEVEL }

@export var map_size: Vector2i = Vector2i(30, 22)
@export var minimum_rooms: int = 5
@export var maximum_rooms: int = 7
@export var minimum_room_size: Vector2i = Vector2i(4, 4)
@export var maximum_room_size: Vector2i = Vector2i(7, 6)
@export var skeleton_limit: int = 3
@export var placement_attempts: int = 250
@export var layout_attempts: int = 32
@export var require_minimum_rooms: bool = true
@export var invincible_player: bool = false
@export var quality_settings: DungeonQualitySettings # Null uses config/layout_quality.tres; diagnostics only.
@export var elevation_mode: ElevationMode = ElevationMode.TWO_LEVEL
@export var prefer_both_elevations: bool = true
# Camera is on +Z: downhill -Z is hidden behind the upper platform.
@export var restrict_camera_hidden_ramps: bool = true

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if elevation_mode not in [ElevationMode.TWO_LEVEL, ElevationMode.LEGACY_THREE_LEVEL]:
		errors.append("Unknown elevation mode.")
	if map_size.x < 16 or map_size.y < 8 or map_size.x > 128 or map_size.y > 128:
		errors.append("Map dimensions must be between 16x8 and 128x128 to fit the fallback and bound allocation.")
	if minimum_rooms < 2 or maximum_rooms < minimum_rooms or maximum_rooms > 100:
		errors.append("Room counts must satisfy 2 <= minimum <= maximum <= 100.")
	if minimum_room_size.x < 3 or minimum_room_size.y < 3 or maximum_room_size.x < minimum_room_size.x or maximum_room_size.y < minimum_room_size.y:
		errors.append("Room dimensions must be ordered and at least 3x3.")
	if maximum_room_size.x > map_size.x - 3 or maximum_room_size.y > map_size.y - 3:
		errors.append("Maximum room dimensions must fit inside the map margins.")
	if skeleton_limit < 0 or skeleton_limit > 1000:
		errors.append("Skeleton limit must be between 0 and 1000.")
	if placement_attempts < 0 or placement_attempts > 10000 or layout_attempts < 1 or layout_attempts > 128:
		errors.append("Placement attempts must be 0..10000 and layout attempts 1..128.")
	return errors
