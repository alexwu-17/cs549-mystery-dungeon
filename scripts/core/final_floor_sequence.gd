class_name FinalFloorSequence
extends Node3D
## Only instantiated for the authored final floor. No shared environment overrides.
const RECOVERY_TILE := Vector2i(13, 16)
const ENTRANCE_TILE := Vector2i(13, 15)
const CAMERA_HEIGHT: float = 0.85
const CAMERA_DISTANCE: float = 2.0
const CORRIDOR_FOV: float = 65.0
const TRANSITION_SECONDS: float = 0.7
const ENCOUNTER_BLACKOUT_SECONDS: float = 1.5
const ENCOUNTER_MUSIC_SECONDS: float = 1.0
const ENCOUNTER_SPAWNS := {
	Vector2i(0, -2): preload("res://scenes/enemies/riolu.tscn"),
	Vector2i(-2, 0): preload("res://scenes/enemies/budew.tscn"),
	Vector2i(2, 0): preload("res://scenes/enemies/gible.tscn"),
	Vector2i(0, 2): preload("res://scenes/enemies/feebas.tscn"),
}

const APPROACH_MIST_MULTIPLIER: float = 5.0
var approach_mist_material: ShaderMaterial
var original_mist_opacity: float = 0.1275

var main: Node3D
var sealed: bool = false
var camera_blend: float = 0.0
var recovery_effect: ProjectileImpactEffect
var camera_transition: Tween
var encounter_transition: Tween
var encounter_started: bool = false
var encounter_active: bool = false
var spiritomb_reveal: SpiritombReveal
var backdrop: CorridorDreadBackdrop
var walls: FinalCorridorEnvironment
var recovery_marker: Node3D
var center_marker: Node3D
var corridor_camera_position := Vector3.ZERO

func initialize(owner_main: Node3D) -> void:
	main = owner_main
	var atmosphere: SunlightAtmosphere = main.get_node("SunlightAtmosphere")
	approach_mist_material = atmosphere.ground_mist.material_override
	var opacity: Variant = approach_mist_material.get_shader_parameter("opacity")
	if opacity != null:
		original_mist_opacity = float(opacity)
	approach_mist_material.set_shader_parameter("opacity", original_mist_opacity * APPROACH_MIST_MULTIPLIER)
	backdrop = CorridorDreadBackdrop.new()
	add_child(backdrop)
	walls = FinalCorridorEnvironment.new()
	walls.name = "FinalCorridorEnvironment"
	add_child(walls)
	walls.build(main.dungeon, main.dungeon_renderer)
	recovery_marker = _make_marker(RECOVERY_TILE, Color(0.1, 1.0, 0.25))
	recovery_marker.name = "RecoveryTile"
	center_marker = _make_marker(DemoArenaFactory.ARENA_CENTER, Color(1.0, 0.93, 0.65))
	center_marker.name = "ArenaCenterLight"
	center_marker.hide()
	main.player.facing = Vector2i.UP
	main.player.character_visual.face(Vector2i.UP)

func _make_marker(tile: Vector2i, color: Color) -> Node3D:
	var marker := Node3D.new()
	add_child(marker)
	marker.position = main.dungeon_renderer.get_entity_world_position(tile)
	var surface := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.43
	disc.bottom_radius = 0.43
	disc.height = 0.025
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	disc.material = material
	surface.mesh = disc
	surface.position.y = 0.025
	marker.add_child(surface)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 2.5
	light.position.y = 0.4
	light.shadow_enabled = false
	marker.add_child(light)
	return marker

func apply_camera() -> void:
	var camera: Camera3D = main.presentation_camera
	if sealed and camera_blend >= 1.0:
		if is_instance_valid(spiritomb_reveal): spiritomb_reveal.apply_camera()
		return # Main has already applied its regular camera configuration.
	var regular_position := camera.global_position
	var regular_rotation := camera.rotation
	var regular_fov := camera.fov
	if not sealed:
		corridor_camera_position = main.player.global_position + Vector3(0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	camera.global_position = corridor_camera_position.lerp(regular_position, camera_blend)
	camera.rotation = Vector3.ZERO.lerp(regular_rotation, camera_blend)
	camera.fov = lerpf(CORRIDOR_FOV, regular_fov, camera_blend)
	if is_instance_valid(backdrop) and backdrop.visible:
		backdrop.follow_camera(camera)

func refresh_markers() -> void:
	recovery_marker.visible = not sealed and main.dungeon.is_bright(RECOVERY_TILE)
	center_marker.visible = sealed and not encounter_started and main.dungeon.is_bright(DemoArenaFactory.ARENA_CENTER)

func on_player_moved() -> void:
	if sealed:
		if not encounter_started and main.player.grid_position == DemoArenaFactory.ARENA_CENTER:
			_begin_encounter()
		return
	if main.player.grid_position == RECOVERY_TILE:
		main.player.health.heal(main.player.health.maximum)
		var state: PokemonBattleState = main.player.battle_state
		for slot in range(state.moves.size()):
			state.remaining_pp[slot] = state.moves[slot].maximum_pp if state.moves[slot] != null else 0
		state.moves_changed.emit()
		main.dialogue.append_event(&"fully_restored")
		_play_recovery_bloom()
	if main.player.grid_position == ENTRANCE_TILE:
		_seal_arena()

func _play_recovery_bloom() -> void:
	main.player.stop_held_movement()
	main.player.transition_locked = true
	var generation: int = main.transition_generation
	var token: int = main.round_generation
	recovery_effect = ProjectileImpactEffect.play_on_actor(main.player, &"healing_bloom")
	var played: bool = await recovery_effect.impact_finished
	recovery_effect = null
	if not played or not is_inside_tree() or not is_instance_valid(main): return
	if main.final_floor_sequence != self or generation != main.transition_generation or token != main.round_generation or main.game_over or main.victory: return
	main.player.transition_locked = false


func _seal_arena() -> void:
	sealed = true
	main.player.stop_held_movement()
	main.player.transition_locked = true
	# Capture the corridor pose before the grid/presentation is rebuilt.
	corridor_camera_position = main.player.global_position + Vector3(0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	walls.hide()
	recovery_marker.hide()
	# The arena becomes the original diamond again, including its southern wall.
	for tile in FinalFloorFactory.corridor_tiles():
		main.dungeon.tiles.erase(tile)
		main.dungeon.elevations.erase(tile)
		main.dungeon.discovered_tiles.erase(tile)
		main.dungeon.bright_tiles.erase(tile)
	main.dungeon.player_spawn = ENTRANCE_TILE
	if not main.dungeon_renderer.render_dungeon(main.dungeon, true):
		push_error("Final arena could not be rendered after sealing.")
		return
	walls.build(main.dungeon, main.dungeon_renderer, false)
	walls.show()
	main.refresh_fog()
	var generation: int = main.transition_generation
	var round_token: int = main.round_generation
	camera_transition = create_tween()
	camera_transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_transition.tween_method(_set_camera_blend, 0.0, 1.0, TRANSITION_SECONDS)
	camera_transition.tween_callback(func():
		if generation != main.transition_generation or round_token != main.round_generation or main.game_over or main.victory:
			return
		_release_backdrop()
		main.player.transition_locked = false
	)

func _release_backdrop() -> void:
	if not is_instance_valid(backdrop): return
	# Release the material's texture references as well as the scene node.
	backdrop.hide()
	backdrop.material_override = null
	backdrop.queue_free()
	backdrop = null


func _set_camera_blend(value: float) -> void:
	camera_blend = value
	main.update_presentation()

func _begin_encounter() -> void:
	encounter_started = true
	center_marker.hide()
	main.player.stop_held_movement()
	main.player.transition_locked = true
	main.floor_introduction.cover_immediately()
	main.get_node("/root/MusicManager").stop_music(main)
	_restore_approach_mist()
	var generation: int = main.transition_generation
	var round_token: int = main.round_generation
	var anchor: Vector2i = main.player.grid_position
	encounter_transition = create_tween()
	encounter_transition.tween_interval(ENCOUNTER_MUSIC_SECONDS)
	encounter_transition.tween_callback(func():
		if _encounter_is_current(generation, round_token):
			main.get_node("/root/MusicManager").play_boss(main)
	)
	encounter_transition.tween_interval(ENCOUNTER_BLACKOUT_SECONDS - ENCOUNTER_MUSIC_SECONDS)
	encounter_transition.tween_callback(func():
		if not _encounter_is_current(generation, round_token): return
		# Validate the complete formation before adding any actors.
		for offset: Vector2i in ENCOUNTER_SPAWNS:
			if not main.dungeon.is_walkable(anchor + offset) or main.is_enemy_occupied(anchor + offset):
				push_error("Final encounter formation is blocked at " + str(anchor + offset))
				return
		for offset: Vector2i in ENCOUNTER_SPAWNS:
			var enemy: Skeleton = main._spawn_regular_enemy(anchor + offset, ENCOUNTER_SPAWNS[offset])
			enemy.facing = -offset / 2
			enemy.character_visual.face(enemy.facing)
		main.refresh_fog()
		if not _encounter_is_current(generation, round_token): return
		encounter_active = true
		main.floor_introduction.hide()
		main.player.transition_locked = false
	)

func _encounter_is_current(generation: int, round_token: int) -> bool:
	return is_inside_tree() and is_instance_valid(main) and main.final_floor_sequence == self and generation == main.transition_generation and round_token == main.round_generation and not main.game_over and not main.victory and not main.loading_floor

func try_begin_spiritomb_reveal() -> bool:
	if not encounter_active or not main.enemies.is_empty() or is_instance_valid(spiritomb_reveal):
		return false
	encounter_active = false
	spiritomb_reveal = SpiritombReveal.new()
	add_child(spiritomb_reveal)
	spiritomb_reveal.initialize(main, self)
	return true

func spiritomb_occupies(tile: Vector2i) -> bool:
	return is_instance_valid(spiritomb_reveal) and spiritomb_reveal.occupies(tile)

func _restore_approach_mist() -> void:
	if approach_mist_material != null:
		approach_mist_material.set_shader_parameter("opacity", original_mist_opacity)
		approach_mist_material = null

func cancel_transition() -> void:
	if is_instance_valid(recovery_effect): recovery_effect.finish()
	if is_instance_valid(spiritomb_reveal): spiritomb_reveal.cancel()
	_restore_approach_mist()
	if camera_transition != null:
		camera_transition.kill()
	if encounter_transition != null:
		encounter_transition.kill()

func _exit_tree() -> void:
	cancel_transition()
