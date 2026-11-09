# Initial move damage contract — 2026-11-08

Status: implemented initial Normal physical moves and deterministic stat-based
basic attacks. Stunky is restored to 42 HP; starter stats are unchanged. The
logarithmic formula below supersedes the earlier linear approximation and its
proposed 0.6/0.7 multipliers. Stat-changing moves and projectiles remain deferred.

## Current species resources

Read directly from `config/species/{chimchar,piplup,turtwig,stunky}.tres`.
These are authored battle stats, not mainline base stats.

| Species | Level | HP | Attack | Defense | Sp. Atk | Sp. Def |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chimchar | 20 | 76 | 39 | 35 | 38 | 38 |
| Piplup | 20 | 80 | 40 | 36 | 42 | 35 |
| Turtwig | 20 | 67 | 43 | 41 | 43 | 41 |
| Stunky | 15 | 42 | 21 | 18 | 20 | 22 |

## Confirmed initial moves

| Starter | Move | Type | Category | Power | PP |
| --- | --- | --- | --- | ---: | ---: |
| Chimchar | Scratch | Normal | Physical | 6 | 28 |
| Piplup | Pound | Normal | Physical | 6 | 27 |
| Turtwig | Tackle | Normal | Physical | 6 | 30 |

Basic attacks remain PP-free and use a neutral power-1 physical result with a
0.5 multiplier, excluding STAB and effectiveness. Both basics and moves consume
one turn. Initial moves occupy the existing `move_slot_1`/U binding; I/O/P stay
empty. Existing Space and movement mappings are unchanged.

## Calculation assumptions and results

User-supplied Explorers-inspired formula (`ln` is the natural logarithm):

`raw = (153/256) * (A + P) - D/2 + 50 * ln(10 * (L + (A-D)/8) + 500) - 311`

Physical uses effective Attack/Defense; special uses effective Sp. Atk/Sp. Def.
Raw damage is clamped to at least 1 before modifiers. A lower bound of 1 on the
logarithm argument protects extreme future modifiers from NaN. Damage rounds to
nearest once after all modifiers, with a minimum of 1 for positive multipliers;
zero effectiveness returns zero damage. No randomness, critical hits or accuracy
rolls. Basics multiply the unrounded power-1 raw result by 0.5. Hits to defeat are
`ceil(42 / damage)` for a fresh Stunky, without healing or other combat effects.

Current neutral results against Stunky:

| Starter | Raw move result | Basic damage | Basic hits | Move damage | Move hits |
| --- | ---: | ---: | ---: | ---: | ---: |
| Chimchar | 36.28925 | 17 | 3 | 36 | 2 |
| Piplup | 36.97289 | 17 | 3 | 37 | 2 |
| Turtwig | 39.02293 | 18 | 3 | 39 | 2 |

This meets the initial pacing targets. Future projectile powers/range still need
tuning. STAB is 1.5 when a move matches the attacker's species types; these three
Normal moves receive no STAB. Type effectiveness is a supported calculator
modifier (neutral by default); a full type-chart lookup is not implemented yet.

## Integration design

`PokemonDamage` is the shared calculator. It reads offense/defense through
`PokemonBattleState.get_effective_stat()` for both basic and move damage. The
accessor currently returns the actor's copied stat; future stage multipliers
belong there. Stage effects are not implemented yet.

Move resources in `config/moves/` own identity, category, power, type, max PP,
range and targeting pattern. Species data assigns starting moves; actors copy up
to four move references and own independent remaining PP. The existing HUD is
updated through `moves_changed`, including power/description tooltips. Adjacent
hits use `DungeonData.can_traverse()` and Main's existing combat handling.
Executed misses spend PP and a turn; zero PP, unassigned slots and input locks
do not. Floors retain PP; fresh runs restore it. Native attack presentation and
sequential enemy actions are shared with Space. No new effects or input map.

Stunky is level 15 with Scratch (Normal/Physical/power6/PP28). Accepted melee
attacks choose Scratch with probability 0.95 while usable, otherwise a PP-free
basic. Exhausted Scratch always falls back to basic without a selection roll.
Each spawned enemy owns its remaining PP; shared move definitions stay read-only.

| Defender | Scratch damage | Tackle damage (same parameters) | Basic damage |
| --- | ---: | ---: | ---: |
| Chimchar | 10 | 10 | 4 |
| Piplup | 10 | 10 | 3 |
| Turtwig | 7 | 7 | 2 |

Tackle is shown for comparison only; Stunky is assigned Scratch. Both branches
use the shared calculator and effective-stat accessor. Enemy movement never
rolls for a move or spends PP. No PP restoration was added.

Unconfigured legacy actors retain exported
damage as a compatibility fallback; this preserves Drapion's outgoing charge
damage18. Drapion has no authored species stats and its defense is still the
existing placeholder1; incoming stat-based attacks therefore make this boss
easier to defeat, pending a separate boss-stat balancing pass. No boss stats were
invented and its HP30/footprint/charge/recharge/victory lifecycle is unchanged.

## Recovery update (2026-11-08)

Production no longer heals on enemy kills. Walking and J waiting restore 1 HP
after an initial 15 completed peaceful turns, then every five turns in the same
streak; attacking or damage resets progress and the initial delay.
J is blocked whenever an enemy is currently revealed by fog, and a reveal
interrupts held 5x waiting immediately. PP is never restored. See the handoff
for repeat/cancellation contracts and tests.

Exploration floors retain their initial three enemies. Once cleared, thirty full
enemy-free turns spawn one Stunky in a hidden reachable room outside the
player's room/corridor. The clearing turn is excluded; this repeats after each
clear. Boss arena and diagnostic fixtures are exempt.

## Status moves and effective stats (2026-11-08)

I assigns Leer (27 PP, adjacent enemy Defense-1), Growl (20 PP, same-room
enemies Attack-1) and Withdraw (Water, 16 PP, self Defense+1). They cause no
direct damage and cost one turn/PP even with no target or a capped stage.
Stages clamp to -10..10. They last five subsequent turns; another status move
refreshes the affected actor's entire stack timer. Expiry resets all stages and
logs the return to normal. Floors/new runs clear stages and timers silently.
Effective stats floor base times the supplied Explorers offensive/defensive
lookup numerator/256. Base stats and neutral damage results above are unchanged.
One Leer gives Stunky Defense12; Growl gives Attack16; Withdraw gives Turtwig
Defense53. All authored physical/special/basic damage uses this shared accessor.
Drapion still uses its existing fixed18 scripted-charge fallback pending authored
boss stats; no new boss stats or replacement damage formula were introduced.
