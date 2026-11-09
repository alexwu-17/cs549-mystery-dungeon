class_name PokemonDamage
extends RefCounted
## Deterministic user-supplied Explorers-inspired formula; independent of targeting.
const BASIC_POWER := 1
const BASIC_MULTIPLIER := 0.5


static func raw_damage(attacker: PokemonBattleState, defender: PokemonBattleState, category: PokemonMoveData.Category, power: int) -> float:
	var special := category == PokemonMoveData.Category.SPECIAL
	var offense := attacker.get_effective_stat(&"special_attack" if special else &"attack")
	var defense := defender.get_effective_stat(&"special_defense" if special else &"defense")
	# Extreme future modifiers must not produce log(0), NaN or negative damage.
	var logarithm := maxf(1.0, 10.0 * (attacker.level + (offense - defense) / 8.0) + 500.0)
	return maxf(1.0, (153.0 / 256.0) * (offense + power) - defense / 2.0 + 50.0 * log(logarithm) - 311.0)


static func modified_damage(raw: float, multiplier: float = 1.0, stab: float = 1.0, effectiveness: float = 1.0) -> int:
	if multiplier <= 0.0 or stab <= 0.0 or effectiveness <= 0.0:
		return 0
	return maxi(1, roundi(raw * multiplier * stab * effectiveness))


static func basic_damage(attacker: PokemonBattleState, defender: PokemonBattleState, fallback_damage: int = 1) -> int:
	# Legacy actors/bosses without authored battle stats keep their existing damage.
	if attacker.species == null:
		return fallback_damage
	return modified_damage(raw_damage(attacker, defender, PokemonMoveData.Category.PHYSICAL, BASIC_POWER), BASIC_MULTIPLIER)


static func move_damage(attacker: PokemonBattleState, defender: PokemonBattleState, move: PokemonMoveData, effectiveness: float = 1.0) -> int:
	if move.category == PokemonMoveData.Category.STATUS:
		return 0
	var stab := 1.0
	if attacker.species != null and attacker.species.types.has(move.move_type):
		stab = 1.5
	return modified_damage(raw_damage(attacker, defender, move.category, move.power), 1.0, stab, effectiveness)
