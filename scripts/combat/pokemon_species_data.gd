class_name PokemonSpeciesData
extends Resource
## Shared species configuration. Treat as read-only during a run.
## Stats are authored battle values at the configured level, not mainline base
## stats: do not apply IV/EV/nature calculations or level scaling to them.
## Current HP, PP and temporary stat stages belong to each actor separately.

@export var species_id: StringName = &""
@export var display_name: String = ""
@export_range(1, 100, 1) var level: int = 1
@export_range(1, 9999, 1) var maximum_hp: int = 1
@export_range(1, 9999, 1) var attack: int = 1
@export_range(1, 9999, 1) var special_attack: int = 1
@export_range(1, 9999, 1) var defense: int = 1
@export_range(1, 9999, 1) var special_defense: int = 1
