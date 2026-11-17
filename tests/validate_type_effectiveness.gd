extends SceneTree

const Chart = preload("res://scripts/combat/pokemon_type_chart.gd")
# Independent expected rows in Normal/Fire/Water/Electric/Grass/Ice/Fighting/
# Poison/Ground/Flying/Psychic/Bug/Rock/Ghost/Dark/Steel/Dragon order.
# S = 1.5, R = 0.75, I = 0, N = 1.
const TYPES := ["Normal", "Fire", "Water", "Electric", "Grass", "Ice", "Fighting", "Poison", "Ground", "Flying", "Psychic", "Bug", "Rock", "Ghost", "Dark", "Steel", "Dragon"]
const EXPECTED := [
	"NNNNNNNNNNNNRINRN",
	"NRRNSSNNNNNSRNNSR",
	"NSRNRNNNSNNNSNNNR",
	"NNSRRNNNISNNNNNNR",
	"NRSNRNNRSRNRSNNRR",
	"NRRNSRNNSSNNNNNRS",
	"SNNNNSNRNRRRSISSN",
	"NNNNSNNRRNNNRRNIN",
	"NSNSRNNSNINRSNNSN",
	"NNNRSNSNNNNSRNNRN",
	"NNNNNNSSNNRNNNIRN",
	"NRNNSNRRNRSNNRSRN",
	"NSNNNSRNRSNSNNNRN",
	"INNNNNNNNNSNNSRNN",
	"NNNNNNRNNNSNNSRNN",
	"NRRRNSNNNNNNSNNRN",
	"NNNNNNNNNNNNNNNRS",
]


func _initialize() -> void:
	assert(Chart.CHART.size() == 17)
	assert(not Chart.CHART.has("Fairy") and Chart.CHART.has("Dragon"))
	for a in range(TYPES.size()):
		assert(EXPECTED[a].length() == TYPES.size(), "Invalid expected row: " + TYPES[a])
		for d in range(TYPES.size()):
			var first := expected_value(EXPECTED[a][d])
			assert(Chart.effectiveness(TYPES[a], PackedStringArray([TYPES[d]])) == first, TYPES[a] + " -> " + TYPES[d])
			for other in range(TYPES.size()):
				var second := expected_value(EXPECTED[a][other])
				var combined := first if second == 1.0 else second
				if first == 0.0 or second == 0.0:
					combined = 0.0
				elif first != 1.0 and second != 1.0 and first != second:
					combined = 1.0
				assert(Chart.effectiveness(TYPES[a], PackedStringArray([TYPES[d], TYPES[other]])) == combined, "%s -> %s/%s expected %s" % [TYPES[a], TYPES[d], TYPES[other], combined])
	assert(Chart.effectiveness("Unknown", PackedStringArray(["Ghost"])) == 1.0)
	assert(Chart.effectiveness("Fire", PackedStringArray()) == 1.0)
	assert(Chart.effectiveness("Normal", PackedStringArray(["Dragon", "Fairy"])) == 1.0)
	validate_damage()
	print("PASS: all 289 single-type and 4913 dual-type matchups, neutral defaults, final damage scaling, STAB and immunities")
	quit()


func expected_value(code: String) -> float:
	return {"S": 1.5, "N": 1.0, "R": 0.75, "I": 0.0}[code]


func validate_damage() -> void:
	var attacker := PokemonBattleState.new()
	var defender := PokemonBattleState.new()
	attacker.reset(load("res://config/species/chimchar.tres").duplicate())
	attacker.species.types = PackedStringArray(["Fire"]) # Explicit STAB fixture, independent of starter configuration.
	defender.reset(load("res://config/species/stunky.tres").duplicate())
	var move := PokemonMoveData.new()
	move.power = 6
	for category in [PokemonMoveData.Category.PHYSICAL, PokemonMoveData.Category.SPECIAL]:
		move.category = category
		move.move_type = "Fire"
		defender.species.types = PackedStringArray()
		var raw := PokemonDamage.raw_damage(attacker, defender, category, move.power)
		var baseline := PokemonDamage.move_damage(attacker, defender, move)
		assert(baseline == maxi(1, roundi(raw * 1.5)))
		defender.species.types = PackedStringArray(["Grass", "Steel"])
		assert(PokemonDamage.move_damage(attacker, defender, move) == maxi(1, roundi(raw * 1.5 * 1.5)))
		defender.species.types = PackedStringArray(["Water", "Rock"])
		assert(PokemonDamage.move_damage(attacker, defender, move) == maxi(1, roundi(raw * 1.5 * 0.75)))
		defender.species.types = PackedStringArray(["Grass", "Water"])
		assert(PokemonDamage.move_damage(attacker, defender, move) == baseline)
	for attacking_type in ["Normal", "Fighting", "Ghost"]:
		move.move_type = attacking_type
		defender.species.types = PackedStringArray(["Ghost", "Rock"] if attacking_type != "Ghost" else ["Normal", "Psychic"])
		var hp := defender.health.current
		var amount := PokemonDamage.move_damage(attacker, defender, move)
		assert(amount == 0)
		defender.health.damage(amount)
		assert(defender.health.current == hp)
	var basic := PokemonDamage.basic_damage(attacker, defender)
	defender.species.types = PackedStringArray()
	assert(PokemonDamage.basic_damage(attacker, defender) == basic)
	move.category = PokemonMoveData.Category.STATUS
	assert(PokemonDamage.move_damage(attacker, defender, move) == 0)
