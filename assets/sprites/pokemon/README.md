# Alpha Pokémon sprites

The user-supplied `chimchar.zip`, `stunky.zip` and `drapion.zip` were extracted
without changing any member bytes, directly into `Chimchar/`, `Stunky/`, and
`Drapion/`. All original animation, offset and shadow PNGs and `AnimData.xml`
are preserved. Local ZIPs are ignored by Git to avoid duplicate committed data.
Older AI artwork remains in `assets/sprites/source/` and the existing placeholder
frame directories.

Roles are visual only: Chimchar = Player, Stunky = Skeleton, Drapion = Minotaur.
Internal gameplay class names and mechanics intentionally remain unchanged.

## Animation data

Dimensions and durations below come from each supplied XML. Durations are in
source ticks (1/60 second), not engine movement/turn durations.

| Species | Clip | Frame pixels | Frames | Duration ticks |
| --- | --- | --- | --- | --- |
| Chimchar | Idle | 24 × 40 | 5 | 30, 2, 4, 6, 2 |
| Chimchar | Walk | 32 × 48 | 7 | 6, 4, 4, 4, 6, 6, 4 |
| Chimchar | Attack | 64 × 80 | 10 | 2, 4, 1, 1, 1, 2, 2, 2, 2, 2 |
| Chimchar | Hurt | 32 × 48 | 2 | 2, 8 |
| Chimchar | Faint (available, player death unchanged) | 32 × 32 | 4 | 8, 12, 4, 10 |
| Stunky | Idle | 32 × 48 | 6 | 1, 2, 4, 3, 1, 40 |
| Stunky | Walk | 32 × 40 | 4 | 8, 8, 8, 8 |
| Stunky | Attack | 72 × 80 | 11 | 2, 2, 6, 1, 1, 2, 2, 6, 2, 2, 2 |
| Stunky | Hurt | 40 × 56 | 2 | 2, 8 |
| Stunky | Faint | 32 × 32 | 4 | 8, 12, 4, 10 |
| Drapion | Idle | 48 × 40 | 4 | 40, 20, 20, 20 |
| Drapion | Walk | 48 × 40 | 4 | 8, 8, 8, 8 |
| Drapion | Attack | 80 × 88 | 12 | 2, 2, 6, 1, 2, 2, 2, 2, 2, 2, 1, 2 |
| Drapion | Hurt | 56 × 64 | 2 | 2, 8 |
| Drapion | Charge | 48 × 40 | 10 | 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 |
| Drapion | Swing | 72 × 72 | 9 | 2, 1, 2, 2, 3, 2, 2, 1, 1 |

No requested animation is missing. Actual sheets were inspected: rows 0/2/4/6
are South/East/North/West. Diagonals are never selected, and frames are never
mirrored or resampled. `AtlasTexture` regions reference the imported source sheets.

## Controller and anchoring

`PokemonCharacterVisual` extends the existing `CharacterVisual` presentation
contract, configured by `config/pokemon_*.tres`. `PokemonSpriteLibrary` reads XML
once per species/configuration, resolves `CopyOf`, and shares immutable atlas
frames, body markers and opacity masks across actors. Frame updates perform no
image readback, decoding, terrain scanning, mesh rebuilds or root transforms.

Idle/Walk use XML durations. A movement notification holds Walk for 0.24
presentation seconds; another move extends that window without resetting its
phase. Idle always runs at source speed, including its jump/hover/rest holds,
even when other actions are accelerated by held movement. Hurt is a nonblocking
one-shot, then Idle. Attack uses its full XML duration: Chimchar 19/60 seconds,
Stunky 28/60 seconds, Drapion 26/60 seconds. Active actions still honor the existing
3× held-movement speed. These native presentation lengths replace the earlier
forced 0.24-second leap / 0.64-second boss window; action order, input locks,
health/damage events, logical movement and boss warning/cooldown turns are intact.

The existing `AttackLeap` completion contract remains the blocking action owner.
For Pokémon it samples the source attack clock and disables procedural motion;
placeholder fallback retains its original one-tile, 0.15-high, 0.24-second leap.
Drapion's existing boss action uses a source-duration Tween with the same finish
signal. This avoids both duplicate travel and two competing animation clocks.
Damage still occurs once at the original combat event; XML HitFrame never
schedules extra damage. Exact hit-frame damage synchronization remains limited
by the unchanged gameplay timing. No Hop/LeapForth combination is necessary.

Green pixels in `*-Offsets.png` mark body centers, per the
[PMD sprite format](https://wiki.pmdo.pmdcollab.org/Tutorial%3APMD_Sprite_Format).
A fixed canvas-space ground reference is calibrated once from Idle's first South
frame and the profile's `body_to_ground` distance. The same reference is used
across all frames and canvas sizes. Per-frame body markers no longer pin the body
in place, so authored idle jumps, walk bob and attack travel remain visible. No
hand/head attachments, generated frames, mirroring or source-image edits are used.

Some native forward attack pixels extend below the billboard's ground origin.
A presentation-only clearance offset moves the billboard along the camera ray,
with perspective size compensation preserving the authored screen-space motion
and size. The existing AttackLeap surface-offset machinery owns this transform;
Drapion has an inert `SpriteClearance` instance of that helper. Opaque bounds are
cached once with the species library, never read back/scanned per frame. Clearance
updates immediately on a changed animation frame (including late Tween samples),
so it cannot lag by a rendered frame. Grid roots, occupancy and dungeon data never
move. Existing ramp clearance, wall occlusion, fog visibility and character shadow
settings remain in force. PMD shadow images remain unused.

This supersedes the initial integration's per-frame body pinning and compressed
attack timing. The original source PNGs, metadata and nearest-neighbor pixel
filtering are unchanged. Drapion's initial visible width remains two tiles and
its logical 1×2 footprint / sprite Z offset remain unchanged.

## Adding a species or rolling back

1. Put its XML and original sheets directly in a new species directory.
2. Duplicate a `PokemonSpriteProfile` resource, set `directory`, `pixel_size` and
   `body_to_ground`; optional action mappings select alternate existing clips.
3. Assign that profile to the actor's existing VisualController. No gameplay script
   or independent per-species animator is needed.

Missing actions warn and use Idle. An unconfigured/unavailable species keeps the
original placeholder controller/artwork. Clear the profile on a VisualController
before scene startup to restore its original placeholder visuals. Imported PNGs
remain lossless with no mipmaps. The existing export preset now includes Pokémon
XML metadata; no exports were regenerated and Web compatibility is not certified.

Validation: `tests/validate_pokemon_sprites.gd`; normal Forward+ 1920×1080 capture
helper: `tests/capture_pokemon_sprites.gd`. Captures/logs live under ignored
`.godot/pokemon_validation/`. The installed test engine is 4.7.2; project target
4.4.1 still requires a check on that version.

## Additional rendering and performance validation

`capture_pokemon_visibility.gd` passed with native Forward+ rendering: two-room
fog hide/reveal for Stunky and Drapion, inherited Sprite3D double-sided shadows,
all 276 cardinal frame atlas dimensions and GPU-readback opacity-mask agreement,
and actual Chimchar samples hiding obstructing upper geometry without changing
its fog state. Captures include `visibility_first_room.png`,
`visibility_second_room.png` and `occlusion_{Idle,Walk,Attack,Hurt}.png`.
`validate_pokemon_sprites.gd` additionally repeats 40 consecutive Walk updates
without restarting phase, allocating new frame textures or changing baseline
pixel size, and checks Attack/Hurt completion with preserved facing in every
cardinal direction for every actor.

`profile_pokemon_sprites.gd` runs normal rendering at 1920×1080 with seed 4,
120-frame warmup and 600 measured frames per workload. Movement uses actual
sequential enemy presentations, a requested 3× action speed and an 80 ms minimum
movement interval; the test player is invincible. `-- --placeholder` runs the
preserved artwork through the same harness (profiles cleared before actor ready).
No production settings or mechanics are changed by the profiler.

Initial integration runs (before native-motion correction) on this Apple M1 Pro / Godot 4.7.2 / Metal Forward+ host:

| Workload | Pokémon mean / p95 / max ms | Placeholder mean / p95 / max ms |
| --- | --- | --- |
| Animated procedural idle | 8.57 / 9.01 / 26.04 | 9.18 / 8.88 / 1002.10 |
| Procedural 3× movement | 10.55 / 21.54 / 975.57 | 7.88 / 20.48 / 23.72 |
| Boss arena 3× movement | 7.06 / 10.04 / 19.89 | 6.99 / 10.58 / 18.14 |

Procedural movement exceeded 16.667 ms on 51/600 Pokémon frames and 56/600
placeholder frames. Large outliers are retained, with cause unproven. This is a
short workload comparison, not a matched action trace: real-time scheduling
produced 48/56 procedural moves and 35/33 arena moves respectively. Both have
turn-frame budget misses; these samples do not certify sustained 60 FPS or prove
that the new animation has no regression. The GPU timing API returned zero on
this backend, so GPU times are reported as unavailable (`null`), not free.
The target remains 60 FPS at 1080p; no graphics/detail or unrelated gameplay was
changed to mask stalls. JSON reports: ignored `.godot/pokemon_validation/`
`performance_pokemon.json` and `performance_placeholder.json`.

## Files in this integration

- Assets: `assets/sprites/pokemon/Chimchar/`, `Stunky/`, `Drapion/`, this README.
- New reusable presentation: `scripts/effects/pokemon_sprite_profile.gd`,
  `pokemon_sprite_library.gd`, `pokemon_character_visual.gd` and their `.uid` files.
- Species resources: `config/pokemon_chimchar.tres`, `pokemon_stunky.tres`,
  `pokemon_drapion.tres`.
- Scene assignments: `scenes/player/player.tscn`,
  `scenes/enemies/test_enemy.tscn`, `scenes/enemies/minotaur.tscn`.
- Notification-only actor hooks: `scripts/player/player.gd`,
  `scripts/enemies/skeleton.gd`, `scripts/enemies/minotaur.gd`.
- Shared presentation: `scripts/effects/character_visual.gd` (optional visual
  hooks and precomputed ramp metadata), `scripts/core/presentation_camera.gd`
  (immutable atlas opacity masks).
- Checks: `tests/validate_pokemon_sprites.gd`, `capture_pokemon_sprites.gd`,
  `capture_pokemon_visibility.gd`, `profile_pokemon_sprites.gd` and `.uid` files.
- Documentation/configuration: `docs/CODEX_HANDOFF.md`, `.gitignore` (local ZIPs),
  `export_presets.cfg` (include runtime XML; no export regenerated).

Earlier held-movement work remains intact. This native-motion correction also
updates `scripts/effects/attack_leap.gd` (optional procedural motion and elapsed
sampling), `scripts/core/main.gd` (boss presentation clearance only), the boss
scene/script (SpriteClearance reference), and related tests. The working tree's
pre-existing engine/import changes are separate. Original placeholder PNGs/source
art were not changed.


Native-motion regression checks also cover the source Idle first-frame hold at
3× action speed, native attack first/last-frame durations, unchanged logical roots,
all 276 cardinal frames clearing the ground while retaining projected placement,
and the original placeholder leap contract separately. Renderer captures from
`capture_pokemon_native_motion.gd` show the native jump apex and attack
anticipation/reach/recovery under `.godot/pokemon_validation/native_*.png`.
Performance figures above predate this correction and are not certification of
the updated animation. The 1080p/60 FPS target and 4.4.1 verification limitations
remain.


Final native-motion checks: all 45 validation scripts have passing results. The
old ramp fixture assumed non-UP directions always needed zero visual clearance;
it now checks actual native opaque bounds for all directions, idempotence and
neutral-pose restoration, while separately retaining the original placeholder
assertions. Both 35° gameplay and 50° test camera angles pass, including legacy
ramp orientations. Normal visibility/shadow/readback checks and import passed.
The final isolated 1920×1080 native-motion run (same 120 warmup / 600 samples per
workload) measured idle mean/p95 8.35/8.87 ms, procedural 3× movement
10.44/22.87 ms (59/600 frames over 16.667 ms; max 27.89 ms), and boss arena
8.34/11.18 ms. GPU timing remains unavailable. These short samples confirm the
remaining movement-frame budget misses; sustained 60 FPS is not certified.
Logs: `.godot/pokemon_native_validation/final/`, `/tmp/native-ramp.log`,
`/tmp/native-performance.log`; latest JSON remains
`.godot/pokemon_validation/performance_pokemon.json`.


## Ramp-only directed attacks

Native player/Stunky melee launched while the attacker stands on a RAMP tile now
uses a slope-following visual path. `can_traverse()` must permit the facing edge;
side-entry/cliff misses keep their existing presentation. **Attacks launched from
any flat tile, including a flat buffer facing a ramp, are unchanged.** Boss area
attacks and placeholder fallback retain their existing presentation.

The path uses authoritative renderer world positions and the XML RushFrame,
HitFrame and ReturnFrame timestamps. It eases forward to contact, holds and
recovers within the same native clip duration. Middle ramp tiles give ±45°
travel; exiting to a buffer becomes flat at the shared edge halfway between tile
centers. Logical roots, targets, occupancy, damage events, turn order, waits and
speed factors are unchanged. Source sprites remain upright and unmodified.

Only while the new path is active, per-frame body markers anchor the pose to the
first Attack frame to prevent a second baked-in screen-space lunge. They do not
supply world movement: DungeonData/renderer heights do. Idle, Walk, Hurt and all
flat attacks retain the previous fixed ground reference and authored motion.
AttackLeap owns the path and additive surface correction, and clears it on finish
or cancellation. Tread visual offsets blend toward the buffer's existing offset.

Clearance uses the actual stair asset's cached maximum height above the logical
slope, including neighboring treads while crossing an exit. Its four-corner
camera-ray solve accounts for perspective size compensation after other visual
clearance. This fixed observed stair bands cutting through a descending pose.
The source mesh is inspected once per runtime, not per frame; no collision,
terrain mutation, texture creation, image readback or animation rebuild is added.

Checks: `validate_ramp_attacks.gd` covers 48 native player/enemy ramp paths,
16 unchanged flat approaches, all cardinal ramp orientations, both travel
signs, buffer transitions, pose anchoring, actual tread clearance, finish/cancel
restoration, side-entry protection and real combat damage/healing/occupancy with
sequential rounds. A 168-sample pre/post flat trace (two actors × four facings ×
21 samples) is byte-identical for clip/frame time, atlas regions, offsets, sprite
transforms, pixel sizes, lock state and logical positions. Raw traces and harness:
ignored `.godot/ramp_attacks/flat-*` and `flat_attack_trace.gd`.

`capture_ramp_attacks.gd` takes native 1920×1080 contact/pose captures. Use
`-- --exits --edge` for the ramp-to-buffer boundary. Captures under ignored
`.godot/ramp_attacks/` include full interaction views and `_pose` variants hiding
the target so overlapping bodies cannot obscure the attacking artwork. Both
players/enemies and uphill/downhill cases were inspected. Final full regression:
**46/46 PASS**, logs `.godot/ramp_attacks/final/`. Engine import passed; known
certificate/cleanup warnings remain. These captures are not performance samples.
No new sustained-60 claim is made; installed engine is still 4.7.2, with target
4.4.1 unverified.

Files for this ramp change: `scripts/effects/attack_leap.gd`,
`character_visual.gd`, `pokemon_character_visual.gd`, `pokemon_sprite_library.gd`,
`scripts/dungeon/modular_dungeon_visuals.gd` (cached authored tread clearance),
new `tests/validate_ramp_attacks.gd`, `tests/capture_ramp_attacks.gd`, and these
notes / `docs/CODEX_HANDOFF.md`.


## Drapion directional boss cycle

Drapion's actual boss action now uses its downloaded `Charge` and `Swing` sheets,
with `Idle` for recharge. These extra keys are configured only in
`config/pokemon_drapion.tres`; the other species' profiles are unchanged. All
original assets, including the generic Attack sheet, remain available. Charge
loops with its XML timing while the player considers a dodge. A surviving Hurt
interrupts it briefly, then resumes Charge. Swing is a blocking one-shot using
all nine frames over 16/60 seconds at normal speed; its native sweeping/forward
arc returns to its starting pose without an extra procedural leap or a change
to grid position. Recharge consumes the existing cooldown turn with Idle (Hurt
can still interrupt it). Charge itself is 10 frames over 20/60 seconds per loop.

The old surrounding ten-tile attack ring is replaced by a 2×2 warning/attack
area in front, as requested. Its two ranks start immediately beyond the fixed
1×2 footprint's front edge. East/West use both footprint rows; North/South need
a whole-cell alignment choice because the footprint is one cell wide, so the
extra column is on the facing-relative right. No body/footprint rotation occurs.
Cells outside the arena's walkable floor are omitted. Direction and warning
cells lock on entering Charge; dodging does not retarget the following Swing.
Facing is chosen relative to the footprint's center. Greedy pursuit, one charge
turn, one resolving swing, one recharge turn, 30 boss HP, single 18-damage event,
no boss lifesteal, defeat/restart handling and arena generation remain intact.
Damage keeps its existing action event timing; source HitFrame does not apply
additional damage or change turn ordering.

Checks: new `tests/validate_drapion_swing.gd` exercises exact four-direction
patterns, frozen aim and dodges, the real Charge/Swing textures and XML timing,
Hurt→Charge, Swing→Idle, recharge, constant footprint/position, arena boundaries,
single damage, and native lethal-Swing restart cancellation. Existing boss tests
now expect the four front cells; generic sprite validation also checks the 76
additional cardinal Charge/Swing frames (352 selected cardinal frames total).
**47/47 validation scripts PASS**; normal 1920×1080
`tests/capture_drapion_swing.gd` passed and Charge/Swing/Idle captures were
inspected. Logs/captures: ignored `.godot/drapion_swing/`. A 168-state pre/post
flat player/regular-enemy attack trace still matches exactly. Known certificate
and cleanup warnings, 4.7.2-versus-target-4.4.1 verification limits and the existing
uncertified sustained-60 target remain; captures are not FPS measurements.

Files for this boss change: `scripts/enemies/minotaur.gd` (existing internal
class name retained), `scripts/effects/character_visual.gd`,
`pokemon_character_visual.gd`, `pokemon_sprite_library.gd` (comment),
`config/pokemon_drapion.tres`, `tests/validate_boss.gd`,
`validate_pokemon_sprites.gd`, new `validate_drapion_swing.gd` and
`capture_drapion_swing.gd`, plus these notes and the handoff.


## Two-tile line and enemy knockout presentation

This supersedes the earlier 2×2 boss warning. Drapion now threatens a straight
line of **two tiles forward from its footprint's front edge**. North/South use
its column; East/West choose the nearer of its two occupied rows when aiming at
the player. The lane and facing remain locked throughout Charge. Arena-void
cells are omitted; the footprint, 18 damage and Charge→Swing→Idle cycle remain.

The species loader automatically includes `Faint` when present in XML, without
requiring a new per-species script or profile mapping. Stunky has a native
32×32, four-frame Faint (8/12/4/10 ticks, 34/60 seconds), now played on knockout.
Drapion's supplied archive has **no Faint**: it freezes the final frame of its
configured Hurt animation. A species lacking both uses its existing Idle
fallback, never generated frames. Chimchar also has Faint metadata, so it is
cached as an available clip; player defeat behavior is unchanged. Generic sprite
validation now covers 384 selected cardinal frames.

`CharacterVisual` supplies a separate defeat-finished/completed/cancel contract;
`PokemonCharacterVisual.defeat()` plays the native Faint once, or freezes the
fallback frame, and toggles the child Sprite3D's visibility every **0.075 s**.
The effect lasts at least **0.8 s**, holding the last Faint frame if needed;
longer source Faints keep their full duration. These two defaults are adjustable
on PokemonSpriteProfile. Defeat playback is not sped up by held movement. Child
visibility preserves parent fog visibility and automatically suppresses hidden
sprite shadows. Normal action/frame updates cannot overwrite an active defeat.
No images/textures/animations are recreated per frame.

Regular enemies leave the live list and occupancy immediately, with the same
immediate healing and remaining-enemy round behavior as before. Their nodes stay
in Main's visual-only `retiring_enemies` list until blinking finishes. They
cannot act or block tiles, stay subject to fog and clearance, and are freed on
finish; floor/reset cleanup invalidates the list before freeing interrupted
corpses. This does not add a second occupancy/topology representation.

Boss victory locks gameplay and clears threats immediately, but the **Demo
Complete** screen waits for Drapion to disappear and for the finishing player
attack to complete. The final player animation is allowed to finish. Completion
and cancellation are distinct; generation/owner/disposed checks prevent an old
knockout from showing the screen after restart. Music stops on victory as before.
Scene-exit clearance now explicitly skips disposed/out-of-tree visuals.

Validation: **48/48 scripts PASS**, including new
`tests/validate_enemy_defeat.gd` for auto-discovery, source timing, unscaled
blink/hide, last-Hurt fallback, no dead turns/occupancy, immediate healing,
fog-safe visibility, visual cleanup, delayed Demo Complete, a longer finishing
attack and reset cancellation. Deterministic round helpers complete defeat
presentations explicitly rather than sleeping. Existing boss/sprite tests now
expect a two-tile line and Demo Complete. Player/regular-enemy flat attack traces
still match the 168-state pre-change baseline exactly.

Normal Forward+ `tests/capture_enemy_defeat.gd` captures Stunky's source collapse,
visible/hidden blink phases, disappearance and Drapion's fallback before the
completion screen. Inspected hidden-phase captures leave no corpse shadow.
`capture_drapion_swing.gd` also refreshes the warning-line preview. Artifacts:
ignored `.godot/enemy_defeat/` (final logs in `final/`) and
`.godot/drapion_swing/`. These are not FPS measurements; sustained 60 FPS and
Godot 4.4.1 remain unverified on this installed 4.7.2 host. Known shutdown and
certificate warnings remain.

Files for this update: `scripts/enemies/minotaur.gd`, `skeleton.gd`,
`scripts/core/main.gd`, `scripts/effects/character_visual.gd`,
`pokemon_character_visual.gd`, `pokemon_sprite_library.gd`,
`pokemon_sprite_profile.gd`, `scripts/ui/player_hud.gd`, existing boss/sprite
validation and deterministic round helper, new knockout validation/capture,
updated boss capture, and these notes / the handoff. Original PNGs/XML/offsets
and archives are untouched.


Species profiles expose `display_name` for dialogue: currently Chimchar, Stunky and Drapion. Main reads each actor's profile when an event occurs, allowing future selected player profiles and mixed enemy species without hardcoded dialogue names. Empty display names use the species folder name; placeholder visuals use generic scene names. Earlier history retains its original resolved names.

Ordinary native poses now include cached raised-tread clearance on front-facing ramps, using the same perspective-aware camera-ray correction as ramp attacks. This preserves projected sprite size/position and gameplay roots; side-facing and flat presentation retain their existing paths. Source images, offsets and animation timings are unchanged. Native diagnostic captures live in `.godot/front_ramps/`; these image-readback runs are not performance measurements.


### Drapion Strike presentation (2026-10-28)

Drapion now maps its existing logical Swing action to the authored Strike clip through `config/pokemon_drapion.tres` (`"Swing": "Strike"`). Strike is 72×88, ten frames, durations 2,2,6,2,1,2,6,2,2,2 ticks (27/60 seconds). All cardinal rows, original offsets and native motion are retained. Only animation configuration changed in production: charge/recharge states, two-tile warning line, damage event timing/amount, footprint, targeting and turn consumption remain unchanged. The presentation now waits for the longer authored clip through the existing completion contract.

Headless import and four focused scripts PASS: Drapion action/telegraph/timing, generic species frame/anchoring, boss gameplay and defeat/restart lifecycle. Normal 1920×1080 capture passed four directions and inspected Strike pose; capture now forces diagnostic draws to avoid inactive-window waits. No fresh FPS certification or target-4.4.1 validation (installed engine 4.7.2).

Dungeon title remains user-editable: open `scenes/main/demo_main.tscn`, select the root, and set exported **Dungeon Name**. This overrides the shared `@export var dungeon_name` default in `scripts/core/main.gd:6` for Demo only. No dungeon rename was made.
