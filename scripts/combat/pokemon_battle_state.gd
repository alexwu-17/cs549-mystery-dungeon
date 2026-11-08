class_name PokemonBattleState
extends RefCounted
## Mutable state belongs to one actor. Species resources remain read-only.

const HealthScript = preload("res://scripts/entities/health.gd")
var species: PokemonSpeciesData
var health: EntityHealth = HealthScript.new()
var level: int = 1
var attack: int = 1
var special_attack: int = 1
var defense: int = 1
var special_defense: int = 1
# Reserved for later move integration; no moves or stage effects are active yet.
var remaining_pp: Array[int] = []
var stat_stages: Dictionary = {}


func reset(source: PokemonSpeciesData, fallback_hp: int = 1, fallback_level: int = 1) -> void:
	species = source
	level = source.level if source != null else fallback_level
	attack = source.attack if source != null else 1
	special_attack = source.special_attack if source != null else 1
	defense = source.defense if source != null else 1
	special_defense = source.special_defense if source != null else 1
	remaining_pp.clear()
	stat_stages.clear()
	health.reset(source.maximum_hp if source != null else fallback_hp)
