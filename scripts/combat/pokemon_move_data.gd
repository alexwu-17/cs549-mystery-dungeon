class_name PokemonMoveData
extends Resource
## Shared immutable definition; remaining PP belongs to each actor's battle state.
enum Category { PHYSICAL, SPECIAL, STATUS }
enum Targeting { ADJACENT, STRAIGHT_PROJECTILE, SAME_ROOM, SELF }

@export var move_id: StringName
@export var display_name: String
@export var move_type: String = "Normal"
@export var category: Category = Category.PHYSICAL
@export_range(0, 999, 1) var power: int = 6
@export_range(1, 99, 1) var maximum_pp: int = 1
@export_range(1, 99, 1) var range_tiles: int = 1
@export var targeting: Targeting = Targeting.ADJACENT
@export var animation_action: StringName = &"Attack"
@export var affected_stat: StringName
@export_range(-10, 10) var stage_change: int = 0
@export_multiline var description: String = "Hits the adjacent tile directly ahead. Damages one enemy."
