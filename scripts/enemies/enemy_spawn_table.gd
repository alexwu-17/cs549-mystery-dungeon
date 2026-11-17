extends Resource
## Regular-enemy species selection only; placement stays owned by DungeonData/Main.
const TypeChart = preload("res://scripts/combat/pokemon_type_chart.gd")
const SPECIES := ["stunky", "glameow", "mankey", "vulpix", "psyduck", "tangela"]
const ELEMENT_TYPES := ["Fire", "Water", "Grass"]

@export var early_last_floor: int = 2
@export var typed_first_floor: int = 3
## Zero means no upper floor limit.
@export var typed_last_floor: int = 0
@export var early_weights := PackedInt32Array([45, 45, 4, 2, 2, 2])


func weights_for(floor_number: int, player_types: PackedStringArray) -> PackedInt32Array:
	if floor_number >= 1 and floor_number <= early_last_floor:
		return early_weights.duplicate()
	if floor_number >= typed_first_floor and (typed_last_floor == 0 or floor_number <= typed_last_floor):
		var weights := PackedInt32Array([10, 10, 20, 15, 15, 15])
		for index in range(ELEMENT_TYPES.size()):
			for player_type in player_types:
				if TypeChart.effectiveness(player_type, PackedStringArray([ELEMENT_TYPES[index]])) > 1.0:
					weights[index + 3] += 15
					return weights
		# Future typeless/nonstarter players have no favored elemental matchup.
		return PackedInt32Array([10, 10, 20, 20, 20, 20])
	return PackedInt32Array([100, 0, 0, 0, 0, 0])


func choose(floor_number: int, player_types: PackedStringArray, rng: RandomNumberGenerator) -> String:
	var weights := weights_for(floor_number, player_types)
	var roll := rng.randi_range(0, 99)
	for index in range(weights.size()):
		if roll < weights[index]: return SPECIES[index]
		roll -= weights[index]
	push_error("Enemy spawn weights must total 100")
	return "stunky"
