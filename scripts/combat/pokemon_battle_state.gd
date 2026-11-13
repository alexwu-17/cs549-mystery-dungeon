class_name PokemonBattleState
extends RefCounted
## Mutable state belongs to one actor. Species resources remain read-only.

const HealthScript = preload("res://scripts/entities/health.gd")
const MAX_MOVES := 4
signal moves_changed
signal stage_changed(stat: StringName, amount: int)
signal stats_restored
signal stage_duration_refreshed
const STAGE_DURATION := 5
var stage_turns_remaining: int = 0
var stage_duration_fresh: bool = false
const OFFENSIVE_STAGES := [128, 133, 138, 143, 148, 153, 161, 171, 179, 204, 256, 307, 332, 358, 384, 409, 422, 435, 448, 460, 473]
const DEFENSIVE_STAGES := [7, 12, 25, 38, 51, 64, 76, 102, 128, 179, 256, 332, 409, 486, 537, 588, 640, 691, 742, 793, 844]
const STATS := [&"attack", &"defense", &"special_attack", &"special_defense"]
var species: PokemonSpeciesData
var health: EntityHealth = HealthScript.new()
var level: int = 1
var attack: int = 1
var special_attack: int = 1
var defense: int = 1
var special_defense: int = 1
var moves: Array[PokemonMoveData] = []
var remaining_pp: Array[int] = []
# Missing entries represent neutral stage zero.
var stat_stages: Dictionary = {}


func reset(source: PokemonSpeciesData, fallback_hp: int = 1, fallback_level: int = 1) -> void:
	species = source
	level = source.level if source != null else fallback_level
	attack = source.attack if source != null else 1
	special_attack = source.special_attack if source != null else 1
	defense = source.defense if source != null else 1
	special_defense = source.special_defense if source != null else 1
	remaining_pp.clear()
	moves.clear()
	if source != null:
		moves.assign(source.starting_moves.slice(0, MAX_MOVES))
	for move in moves:
		remaining_pp.append(move.maximum_pp if move != null else 0)
	reset_stages()
	health.reset(source.maximum_hp if source != null else fallback_hp)
	moves_changed.emit()


func knows_move(move: PokemonMoveData) -> bool:
	return move != null and moves.has(move)


## Fills the first empty slot, or appends while under MAX_MOVES, with full PP.
## Returns false for null, already-known moves or a full move set.
func learn_move(move: PokemonMoveData) -> bool:
	if move == null or knows_move(move):
		return false
	for slot in range(moves.size()):
		if moves[slot] == null:
			moves[slot] = move
			remaining_pp[slot] = move.maximum_pp
			moves_changed.emit()
			return true
	if moves.size() >= MAX_MOVES:
		return false
	moves.append(move)
	remaining_pp.append(move.maximum_pp)
	moves_changed.emit()
	return true


func can_use_move(slot: int) -> bool:
	return slot >= 0 and slot < moves.size() and moves[slot] != null and remaining_pp[slot] > 0


func spend_pp(slot: int) -> bool:
	if not can_use_move(slot):
		return false
	remaining_pp[slot] -= 1
	moves_changed.emit()
	return true


func get_effective_stat(stat: StringName) -> float:
	var base: int
	match stat:
		&"attack": base = attack
		&"defense": base = defense
		&"special_attack": base = special_attack
		&"special_defense": base = special_defense
		_:
			push_error("Unknown battle stat: " + stat)
			return 1.0
	var table := OFFENSIVE_STAGES if stat in [&"attack", &"special_attack"] else DEFENSIVE_STAGES
	return floorf(base * float(table[get_stage(stat) + 10]) / 256.0)


func get_stage(stat: StringName) -> int:
	return clampi(int(stat_stages.get(stat, 0)), -10, 10)


func change_stage(stat: StringName, amount: int) -> int:
	if not STATS.has(stat): return 0
	var previous := get_stage(stat)
	var current := clampi(previous + amount, -10, 10)
	if previous == current:
		if amount != 0 and _has_stages():
			_refresh_stage_duration()
			stage_duration_refreshed.emit()
		return 0
	stat_stages[stat] = current
	if _has_stages():
		_refresh_stage_duration()
	else:
		stage_turns_remaining = 0
		stage_duration_fresh = false
	stage_changed.emit(stat, current - previous)
	return current - previous


func reset_stages() -> void:
	stat_stages.clear()
	stage_turns_remaining = 0
	stage_duration_fresh = false


func _has_stages() -> bool:
	for stat in STATS:
		if get_stage(stat) != 0: return true
	return false


func _refresh_stage_duration() -> void:
	stage_turns_remaining = STAGE_DURATION
	stage_duration_fresh = true


func finish_stage_turn() -> void:
	if stage_duration_fresh:
		stage_duration_fresh = false # Do not charge the round that applied/refreshed it.
		return
	if stage_turns_remaining <= 0: return
	stage_turns_remaining -= 1
	if stage_turns_remaining == 0:
		var changed := _has_stages()
		reset_stages()
		if changed: stats_restored.emit()
