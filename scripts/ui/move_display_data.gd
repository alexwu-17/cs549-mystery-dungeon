extends Resource
## Presentation data only. Combat owns move definitions, PP and damage calculation.

@export var move_name: String = ""
@export var attribute_name: String = "Normal"
@export var attribute_icon: Texture2D
@export_enum("Physical", "Special", "Status") var category: String = "Physical"
@export var category_icon: Texture2D
@export var current_pp: int = 0
@export var maximum_pp: int = 0
## Include a label, e.g. "Power: 40" or "Damage: 3"; do not imply power is damage.
@export var damage_text: String = "Damage: —"
@export_multiline var description: String = ""
