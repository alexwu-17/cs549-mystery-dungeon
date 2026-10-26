class_name DungeonQualitySettings
extends Resource
## Experimental diagnostics only. These values do not reject or repair floors.
@export var enabled: bool = true
@export var same_elevation_gap: int = 1
@export var one_level_gap: int = 5
@export var two_level_gap: int = 9
@export_range(1.0, 89.0) var camera_pitch_degrees: float = 35.0
@export var visual_height: float = 1.0
@export var edge_margin: float = 0.25

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if same_elevation_gap < 0 or one_level_gap < 0 or two_level_gap < 0:
		errors.append("Quality separation thresholds must be nonnegative.")
	if not is_finite(camera_pitch_degrees) or camera_pitch_degrees <= 0 or camera_pitch_degrees >= 90:
		errors.append("Quality camera pitch must be between 0 and 90 degrees, exclusive.")
	if not is_finite(visual_height) or not is_finite(edge_margin) or visual_height < 0 or edge_margin < 0:
		errors.append("Quality visual height and edge margin must be finite and nonnegative.")
	return errors

func gap_for_difference(difference: int) -> int:
	if difference == 0: return same_elevation_gap
	return one_level_gap if difference == 1 else two_level_gap
