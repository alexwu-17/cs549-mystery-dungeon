class_name SpiritombReveal
extends Node3D
## Final boss reveal; combat uses the shared enemy lifecycle.
const GLITCH: Texture2D = preload("res://assets/effects/pixelfx/spiritomb_glitch.png")
const DISSOLVE: Texture2D = preload("res://assets/effects/pixelfx/spiritomb_dissolve.png")
const TRANSITION_SHADER: Shader = preload("res://scripts/effects/pixelfx_transition.gdshader")
const CRY: AudioStreamMP3 = preload("res://assets/audio/spiritomb_cry.mp3")
const BATTLE: AudioStreamOggVorbis = preload("res://assets/audio/music/cynthia_battle.ogg")
const SPIRITOMB: PackedScene = preload("res://scenes/enemies/spiritomb.tscn")
var main: Node3D
var sequence: Node3D
var animation: Tween
var music_start: Tween
var overlay: CanvasLayer
var black: ColorRect
var effect: TextureRect
var material: ShaderMaterial
var cry: AudioStreamPlayer
var spiritomb: Node3D
var room_style: SpiritombRoomStyle
var phase: StringName = &"waiting"
var generation: int
var round_token: int
var cancelled: bool = false
var arena_ready: bool = false

func initialize(owner_main: Node3D, owner_sequence: Node3D) -> void:
	main = owner_main
	sequence = owner_sequence
	generation = main.transition_generation
	round_token = main.round_generation
	main.player.stop_held_movement()
	# The finishing projectile/screen move has resolved; this transition owns input.
	main.player.round_locked = false
	main.player.transition_locked = true
	main.get_node("/root/MusicManager").stop_music(main)
	overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	black = ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.hide()
	effect = TextureRect.new()
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = ShaderMaterial.new()
	material.shader = TRANSITION_SHADER
	effect.material = material
	effect.hide()
	cry = AudioStreamPlayer.new()
	cry.stream = CRY
	add_child(cry)
	cry.finished.connect(_on_cry_finished)
	animation = create_tween()
	animation.tween_interval(1.0)
	animation.tween_callback(_begin_glitch)
	animation.tween_method(_glitch_progress, 0.0, 1.0, 0.8)
	animation.tween_callback(_begin_black)
	animation.tween_interval(4.0)
	animation.tween_callback(_begin_dissolve)
	animation.tween_method(_dissolve_progress, 0.0, 1.0, 1.1)
	animation.tween_callback(_begin_settling)
	animation.tween_interval(1.0)
	animation.tween_callback(_finish)

func _current() -> bool:
	return not cancelled and is_inside_tree() and is_instance_valid(main) and main.final_floor_sequence == sequence and generation == main.transition_generation and round_token == main.round_generation and not main.game_over and not main.victory

func _begin_glitch() -> void:
	if not _current(): return
	phase = &"glitch"
	effect.texture = GLITCH
	material.set_shader_parameter("frame_grid", Vector2(4,7))
	material.set_shader_parameter("frame_index", 0.0)
	effect.show()

func _glitch_progress(value: float) -> void:
	if _current() and phase == &"glitch": material.set_shader_parameter("frame_index", floorf(value * 24.0))

func _begin_black() -> void:
	if not _current(): return
	phase = &"black"
	black.show()
	effect.hide()
	main._clear_retiring_enemies()
	main.dungeon = FinalFloorFactory.create_spiritomb_arena()
	if not main.dungeon_renderer.render_dungeon(main.dungeon, true):
		push_error("Spiritomb square arena failed to render.")
		return
	sequence.walls.build(main.dungeon, main.dungeon_renderer, false)
	room_style = SpiritombRoomStyle.new()
	add_child(room_style)
	room_style.apply(main, sequence.walls)
	main.player.facing = Vector2i.UP
	main.player.setup(main.dungeon.player_spawn, main.dungeon, main.dungeon_renderer)
	spiritomb = main._spawn_regular_enemy(FinalFloorFactory.SPIRITOMB_SPAWN, SPIRITOMB)
	if main.player.species_data != null and main.player.species_data.species_id in [&"chimchar", &"piplup", &"turtwig"]:
		main.player.battle_state.learn_move(preload("res://config/moves/recovery.tres"))
	arena_ready = true
	main.refresh_fog()
	cry.play()

func _on_cry_finished() -> void:
	if not _current() or not arena_ready or music_start != null: return
	music_start = create_tween()
	music_start.tween_interval(1.0)
	music_start.tween_callback(func():
		if _current(): main.get_node("/root/MusicManager").play_custom(main, BATTLE)
	)

func _begin_dissolve() -> void:
	if not _current() or not arena_ready: return
	phase = &"dissolve"
	effect.texture = DISSOLVE
	material.set_shader_parameter("frame_grid", Vector2(5,7))
	material.set_shader_parameter("frame_index", 0.0)
	effect.show()
	black.hide()

func _dissolve_progress(value: float) -> void:
	if _current() and phase == &"dissolve": material.set_shader_parameter("frame_index", floorf(value * 33.0))

func _begin_settling() -> void:
	if not _current() or not arena_ready: return
	phase = &"settling"
	overlay.hide()
	if main.learned_move_pending != null:
		animation.pause()
		main.show_move_learning()
		main.move_acknowledged.connect(func():
			if _current(): animation.play()
		, CONNECT_ONE_SHOT)

func _finish() -> void:
	if not _current() or not arena_ready: return
	phase = &"ready"
	main.player.transition_locked = false

func apply_camera() -> void:
	if not arena_ready: return
	# Frame the final square arena and both actors at the regular35-degree pitch.
	var camera = main.presentation_camera
	camera.global_position = main.player.global_position + camera.follow_offset

func occupies(tile: Vector2i) -> bool:
	return is_instance_valid(spiritomb) and spiritomb.health.current > 0 and tile == spiritomb.grid_position

func cancel() -> void:
	cancelled = true
	if animation != null: animation.kill()
	if music_start != null: music_start.kill()
	if is_instance_valid(cry): cry.stop()
	if is_instance_valid(overlay): overlay.hide()

func _exit_tree() -> void:
	cancel()
