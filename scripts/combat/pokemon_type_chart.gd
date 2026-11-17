extends RefCounted
## Attacking move type -> defending types. Unlisted matchups are neutral.
## Columns are super effective, resisted, immune. Fairy is excluded.
const CHART := {
	"Normal": [[], ["Rock", "Steel"], ["Ghost"]],
	"Fire": [["Grass", "Ice", "Bug", "Steel"], ["Fire", "Water", "Rock", "Dragon"], []],
	"Water": [["Fire", "Ground", "Rock"], ["Water", "Grass", "Dragon"], []],
	"Electric": [["Water", "Flying"], ["Electric", "Grass", "Dragon"], ["Ground"]],
	"Grass": [["Water", "Ground", "Rock"], ["Fire", "Grass", "Poison", "Flying", "Bug", "Steel", "Dragon"], []],
	"Ice": [["Grass", "Ground", "Flying", "Dragon"], ["Fire", "Water", "Ice", "Steel"], []],
	"Fighting": [["Normal", "Ice", "Rock", "Dark", "Steel"], ["Poison", "Flying", "Psychic", "Bug"], ["Ghost"]],
	"Poison": [["Grass"], ["Poison", "Ground", "Rock", "Ghost"], ["Steel"]],
	"Ground": [["Fire", "Electric", "Poison", "Rock", "Steel"], ["Grass", "Bug"], ["Flying"]],
	"Flying": [["Grass", "Fighting", "Bug"], ["Electric", "Rock", "Steel"], []],
	"Psychic": [["Fighting", "Poison"], ["Psychic", "Steel"], ["Dark"]],
	"Bug": [["Grass", "Psychic", "Dark"], ["Fire", "Fighting", "Poison", "Flying", "Ghost", "Steel"], []],
	"Rock": [["Fire", "Ice", "Flying", "Bug"], ["Fighting", "Ground", "Steel"], []],
	"Ghost": [["Psychic", "Ghost"], ["Dark"], ["Normal"]],
	"Dark": [["Psychic", "Ghost"], ["Fighting", "Dark"], []],
	"Steel": [["Ice", "Rock"], ["Fire", "Water", "Electric", "Steel"], []],
	"Dragon": [["Dragon"], ["Steel"], []],
}


static func effectiveness(move_type: String, defending_types: PackedStringArray) -> float:
	if not CHART.has(move_type):
		return 1.0
	var row: Array = CHART[move_type]
	var weak := false
	var resistant := false
	for defending_type in defending_types:
		if row[2].has(defending_type):
			return 0.0
		weak = weak or row[0].has(defending_type)
		resistant = resistant or row[1].has(defending_type)
	if weak == resistant:
		return 1.0
	return 1.5 if weak else 0.75
