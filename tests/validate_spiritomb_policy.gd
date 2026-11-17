extends SceneTree
func _initialize() -> void:
 var policy: EnemyAttackPolicy = load("res://config/enemy_spiritomb_attack_policy.tres")
 var state := PokemonBattleState.new()
 state.reset(load("res://config/species/spiritomb.tres"))
 var rng := RandomNumberGenerator.new()
 rng.seed = 984321
 var counts := [0,0,0]
 for i in range(20000):
  var slot := policy.choose_slot(state,rng)
  counts[slot if slot >= 0 else 2] += 1
 for i in range(3):
  assert(absf(float(counts[i])/20000.0 - [0.3,0.4,0.3][i]) < 0.015)
 var wind := 0
 for i in range(20000):
  var slot := policy.choose_slot(state,rng,func(move: PokemonMoveData): return move.move_id != &"shadow_ball")
  assert(slot in [-1,0])
  if slot == 0: wind += 1
 assert(absf(float(wind)/20000.0 - 0.7) < 0.015)
 state.remaining_pp[0] = 0
 state.remaining_pp[1] = 0
 assert(policy.choose_slot(state,rng) == -1)
 print("PASS: Spiritomb 30/40/30 choice, blocked Shadow Ball redistributes to 70/30, exhausted PP falls back")
 quit()
