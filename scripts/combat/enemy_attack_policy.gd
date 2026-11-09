class_name EnemyAttackPolicy
extends Resource
## Invoke only after the AI has accepted an attack. Never owns targeting/turns.
@export_range(0.0, 1.0, 0.01) var move_probability: float = 0.95


func choose_and_spend(state: PokemonBattleState, rng: RandomNumberGenerator, can_execute: Callable = Callable()) -> PokemonMoveData:
	var slot := choose_slot(state, rng, can_execute)
	if slot < 0 or not state.spend_pp(slot): return null
	return state.moves[slot]


func choose_slot(state: PokemonBattleState, rng: RandomNumberGenerator, can_execute: Callable = Callable()) -> int:
	# Charged attacks commit here and spend through BattleState only at execution.
	var usable: Array[int] = []
	for slot in range(state.moves.size()):
		if state.can_use_move(slot) and (not can_execute.is_valid() or can_execute.call(state.moves[slot])):
			usable.append(slot)
	# Exhausted/unavailable moves always fall back, without a probability roll.
	if usable.is_empty() or move_probability <= 0.0:
		return -1
	if move_probability < 1.0 and rng.randf() >= move_probability:
		return -1
	return usable[0] if usable.size() == 1 else usable[rng.randi_range(0, usable.size() - 1)]
