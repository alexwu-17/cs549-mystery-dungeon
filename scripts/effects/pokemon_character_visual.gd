extends CharacterVisual

const Library = preload("res://scripts/effects/pokemon_sprite_library.gd")
@export var profile: PokemonSpriteProfile
var clips: Dictionary = {}
var clip: String = ""
var action: String = "Idle"
var clip_time: float = 0.0
var walk_remaining: float = 0.0
var hurt_remaining: float = 0.0
var frozen: bool = false
var frame_index: int = -1
var direction_row: int = 0
var ground_reference: Vector2 = Vector2.ZERO
var rest_action: String = "Idle"
var defeat_uses_faint: bool = false
var surface_driver: AttackLeap

func _ready() -> void:
	# Keep all original placeholder resources and behavior available when unconfigured.
	super._ready()
	if profile == null: return
	clips = Library.load_species(profile.directory, profile.animations.values())
	if not clips.has(str(profile.animations.get("Idle", "Idle"))):
		clips = {}
		push_warning("Pokémon Idle unavailable; preserving placeholder: " + profile.directory)
		return
	original_pixel_size = profile.pixel_size
	sprite.pixel_size = original_pixel_size
	var idle: Dictionary = clips[str(profile.animations.get("Idle", "Idle"))]
	var rest: Dictionary = idle.rows[0][0]
	# One canvas-space reference, never a moving per-frame body attachment.
	ground_reference = rest.body - rest.texture.get_size() / 2.0 + Vector2(0, profile.body_to_ground)
	var leap := get_parent().get_node_or_null("AttackLeap") as AttackLeap
	surface_driver = leap if leap != null else get_parent().get_node_or_null("SpriteClearance") as AttackLeap
	var attack_name: String = str(profile.animations.get("Attack", "Attack"))
	if leap != null and clips.has(attack_name):
		leap.procedural_motion = false
		leap.duration = float(clips[attack_name].total)
		leap.presentation_progressed.connect(_sample_attack_time)
	standing()

func row() -> int:
	if facing == Vector2i.RIGHT: return 2
	if facing == Vector2i.UP: return 4
	if facing == Vector2i.LEFT: return 6
	return 0

func play_clip(name: String, restart: bool = false) -> void:
	var selected: String = str(profile.animations.get(name, name))
	if not clips.has(selected):
		selected = str(profile.animations.get("Idle", "Idle"))
		name = "Idle"
	if not clips.has(selected): return
	action = name
	if selected != clip or restart:
		clip = selected
		clip_time = 0.0
		frame_index = -1
	apply_frame()

func apply_frame() -> void:
	if not clips.has(clip): return
	var info: Dictionary = clips[clip]
	var elapsed := fmod(clip_time, float(info.total))
	var index := 0
	while index < info.durations.size() - 1 and elapsed >= info.durations[index]:
		elapsed -= float(info.durations[index])
		index += 1
	var selected_row := row()
	if frame_index == index and direction_row == selected_row: return
	frame_index = index
	direction_row = selected_row
	var frame: Dictionary = info.rows[selected_row][index]
	sprite.texture = frame.texture
	# Different-sized canvases share a fixed origin; authored body travel survives.
	var size := sprite.texture.get_size()
	foot_anchor = size / 2.0 + ground_reference
	if uses_attack_surface():
		# Anchor the pose to the world path instead of stacking its baked 2D lunge.
		var first: Dictionary = info.rows[selected_row][0]
		foot_anchor += (frame.body - size / 2.0) - (first.body - first.texture.get_size() / 2.0)
	sprite.offset = Vector2(size.x / 2.0 - foot_anchor.x, foot_anchor.y - size.y / 2.0)
	_refresh_surface_clearance()

func _refresh_surface_clearance() -> void:
	if disposed or not is_inside_tree(): return
	# Tween samples run after Main's process: correct the current pose before rendering.
	if surface_driver != null:
		var data: DungeonData = get_parent().get("dungeon_data")
		var camera := get_viewport().get_camera_3d()
		if data != null and camera != null:
			clear_ramp_intersection(camera, data, get_parent().grid_position, surface_driver)

func _process(delta: float) -> void:
	if clips.is_empty() or frozen: return
	var elapsed := delta * action_speed
	walk_remaining = maxf(0.0, walk_remaining - elapsed)
	hurt_remaining = maxf(0.0, hurt_remaining - elapsed)
	if action == "Hurt" and hurt_remaining == 0.0:
		standing()
	elif action == "Walk" and walk_remaining == 0.0:
		standing()
	# Idle keeps its authored breathing/jump cadence even during fast movement.
	# Attack is sampled by the existing blocking action Tween, not a second clock.
	if action in ["Attack","Swing"]: return
	clip_time += delta if action == "Idle" else elapsed
	if action == "Hurt":
		clip_time = minf(clip_time, float(clips[clip].total) - 0.000001)
	apply_frame()

func _sample_attack_time(elapsed: float) -> void:
	if action not in ["Attack","Swing"] or frozen or not clips.has(clip): return
	clip_time = minf(elapsed, float(clips[clip].total) - 0.000001)
	var previous_frame := frame_index
	apply_frame()
	if uses_attack_surface() and frame_index == previous_frame:
		_refresh_surface_clearance()

func spin() -> void:
	if defeating: return
	if clips.is_empty() or not clips.has(str(profile.animations.get("Attack", "Attack"))):
		super.spin()
		return
	cancel()
	active = true
	show_frame("spin_01")
	var duration: float = clips[clip].total
	animation = create_tween()
	animation.set_speed_scale(action_speed)
	animation.tween_method(_sample_attack_time, 0.0, duration, duration)
	animation.tween_callback(finish)

func walk() -> void:
	if defeating: return
	if clips.is_empty(): return
	rest_action = "Idle"
	frozen = false
	walk_remaining = 0.24
	if not active and not attacking and hurt_remaining == 0.0:
		play_clip("Walk")

func hurt() -> void:
	if defeating: return
	if clips.is_empty(): return
	var selected: String = str(profile.animations.get("Hurt", "Hurt"))
	if not clips.has(selected):
		play_clip("Idle")
		return
	walk_remaining = 0.0
	hurt_remaining = clips[selected].total
	play_clip("Hurt", true)

func standing() -> void:
	if defeating: return
	super.standing()
	if clips.is_empty(): return
	if hurt_remaining > 0.0: play_clip("Hurt")
	elif walk_remaining > 0.0: play_clip("Walk")
	else: play_clip(rest_action)

func attack() -> void:
	if defeating: return
	super.attack()
	if clips.is_empty(): return
	walk_remaining = 0.0
	hurt_remaining = 0.0
	action = "Attack"
	_configure_ramp_attack()
	play_clip("Attack", true)

func _configure_ramp_attack() -> void:
	var attack_name: String = str(profile.animations.get("Attack", "Attack"))
	if surface_driver == null or not surface_driver.active or not clips.has(attack_name): return
	var info: Dictionary = clips[attack_name]
	var times: Array[float] = [0.0]
	for duration: float in info.durations: times.append(times.back() + duration)
	var last: int = info.durations.size()-1
	surface_driver.configure_ramp_path(get_parent().get("dungeon_data"), get_parent().grid_position, facing, get_parent().get("dungeon_renderer"), times[clampi(info.rush_frame,0,last)], times[clampi(info.hit_frame,0,last)], times[clampi(info.return_frame,0,last)])

func uses_attack_surface() -> bool:
	return not clips.is_empty() and action == "Attack" and surface_driver != null and surface_driver.active and surface_driver.ramp_path

func show_frame(name: String) -> void:
	if clips.is_empty():
		super.show_frame(name)
		return
	# Preserve the shared controller's semantic events and boss completion contract.
	current_frame = name
	frame_changed.emit(name)
	if name == "charge": play_clip("Charge" if clips.has(str(profile.animations.get("Charge","Charge"))) else "Idle")
	elif name == "spin_01": play_clip("Attack", true)

func cancel() -> void:
	rest_action = "Idle"
	walk_remaining = 0.0
	hurt_remaining = 0.0
	frozen = false
	super.cancel()

func freeze_defeated() -> void:
	frozen = true
	walk_remaining = 0.0
	hurt_remaining = 0.0


func ground_clearance_offset(camera: Camera3D, data: DungeonData, tile: Vector2i, origin: Vector3) -> Vector3:
	if uses_attack_surface(): return Vector3.ZERO
	if clips.is_empty() or data == null or not sprite.texture.has_meta("pokemon_opaque_rect"):
		return Vector3.ZERO
	var bounds: Rect2i = sprite.texture.get_meta("pokemon_opaque_rect")
	if not bounds.has_area(): return Vector3.ZERO
	var normal := Vector3.UP
	if data.ramp_tiles.has(tile):
		var segment: Dictionary = data.ramp_segments[data.ramp_tiles[tile].segment]
		var rise := DungeonData.ELEVATION_HEIGHT / (3.0 * DungeonData.TILE_SIZE)
		normal = Vector3(-segment.direction.x * rise, 1, -segment.direction.y * rise).normalized()
	var plane_origin: Vector3 = get_parent().global_position
	var rect := sprite.get_item_rect()
	var clearance := 0.0
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			var point: Vector3 = origin + camera.global_basis.x * (rect.position.x + x) * original_pixel_size * sprite.global_basis.x.length()
			point += camera.global_basis.y * (rect.end.y - y) * original_pixel_size * sprite.global_basis.y.length()
			clearance = minf(clearance, normal.dot(point - plane_origin))
	var toward_camera := (camera.global_position - origin).normalized()
	var gain := normal.dot(toward_camera)
	if clearance < -0.0001 and absf(gain) > 0.001:
		return toward_camera * ((-clearance + 0.005) / gain)
	return Vector3.ZERO


func final_surface_clearance_offset(camera: Camera3D, data: DungeonData, tile: Vector2i, origin: Vector3) -> Vector3:
	if clips.is_empty() or not sprite.texture.has_meta("pokemon_opaque_rect"): return Vector3.ZERO
	var normal := Vector3.UP
	var plane_origin: Vector3 = get_parent().global_position
	var tread_clearance := 0.0
	if uses_attack_surface():
		normal = surface_driver.attack_plane_normal
		plane_origin += surface_driver.attack_world_offset
		tread_clearance = surface_driver.attack_tread_clearance
	else:
		if data == null or not data.ramp_tiles.has(tile): return Vector3.ZERO
		var segment: Dictionary = data.ramp_segments[data.ramp_tiles[tile].segment]
		var uphill := Vector3(segment.direction.x, 0, segment.direction.y)
		var view_horizontal := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
		# Apply only to stairs whose treads face the camera. Preserve side/back presentation.
		if uphill.dot(view_horizontal) > -0.707: return Vector3.ZERO
		var rise := DungeonData.ELEVATION_HEIGHT / (3.0 * DungeonData.TILE_SIZE)
		normal = Vector3(-uphill.x * rise, 1, -uphill.z * rise).normalized()
		tread_clearance = ModularDungeonVisuals.ramp_clearance_height(3)
	var bounds: Rect2i = sprite.texture.get_meta("pokemon_opaque_rect")
	if not bounds.has_area(): return Vector3.ZERO
	var direction := (camera.global_position-origin).normalized()
	var distance := camera.global_position.distance_to(origin)
	var base_scale := 1.0
	var scale_rate := 0.0
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var raw_origin := sprite.global_position - surface_driver.surface_offset
		var raw_depth := -camera.to_local(raw_origin).z
		if raw_depth <= 0.001 or distance <= 0.001: return Vector3.ZERO
		base_scale = -camera.to_local(origin).z / raw_depth
		scale_rate = -base_scale / distance
	var required_clearance := 0.005 + normal.y * tread_clearance
	var lower := -INF
	var upper := INF
	var rect := sprite.get_item_rect()
	# Solve clearance after perspective-size compensation, not before it.
	for x in [bounds.position.x,bounds.end.x]:
		for y in [bounds.position.y,bounds.end.y]:
			var corner: Vector3 = camera.global_basis.x*(rect.position.x+x)*original_pixel_size*sprite.global_basis.x.length()
			corner += camera.global_basis.y*(rect.end.y-y)*original_pixel_size*sprite.global_basis.y.length()
			var clearance := normal.dot(origin+corner*base_scale-plane_origin)
			var gain := normal.dot(direction+corner*scale_rate)
			if gain > 0.000001:
				lower = maxf(lower,(required_clearance-clearance)/gain)
			elif gain < -0.000001:
				upper = minf(upper,(required_clearance-clearance)/gain)
			elif clearance < required_clearance - 0.0001:
				return Vector3.ZERO
	if lower > upper: return Vector3.ZERO
	var travel := lower if lower > 0.0 else (upper if upper < 0.0 else 0.0)
	return direction * travel


func attack_surface_tread_offset() -> Vector3:
	return surface_driver.attack_tread_offset if uses_attack_surface() else Vector3.ZERO


func charge() -> void:
	if defeating: return
	if clips.is_empty():
		super.charge()
		return
	rest_action = "Charge" if clips.has(str(profile.animations.get("Charge","Charge"))) else "Idle"
	walk_remaining = 0.0
	hurt_remaining = 0.0
	attacking = false
	show_frame("charge")

func swing() -> void:
	if defeating: return
	if clips.is_empty() or not clips.has(str(profile.animations.get("Swing","Swing"))):
		super.swing()
		return
	cancel()
	active = true
	play_clip("Swing",true)
	current_frame = "swing"
	frame_changed.emit(current_frame)
	var duration: float = clips[clip].total
	animation = create_tween()
	animation.set_speed_scale(action_speed)
	animation.tween_method(_sample_attack_time,0.0,duration,duration)
	animation.tween_callback(finish)

func recharge() -> void:
	if defeating: return
	rest_action = "Idle"
	walk_remaining = 0.0
	standing()


func defeat() -> void:
	if defeating: return
	if clips.is_empty():
		super.defeat()
		return
	cancel()
	frozen = true
	defeating = true
	defeat_completed = false
	attacking = false
	var faint_name: String = str(profile.animations.get("Faint","Faint"))
	defeat_uses_faint = clips.has(faint_name)
	play_clip("Faint" if defeat_uses_faint else "Hurt",true)
	action = "Defeat"
	current_frame = "faint"
	if not defeat_uses_faint:
		clip_time = float(clips[clip].total)-0.000001
		frame_index = -1
		apply_frame()
	var duration := maxf(profile.defeat_minimum_duration,float(clips[clip].total) if defeat_uses_faint else 0.0)
	defeat_animation = create_tween()
	defeat_animation.tween_method(_sample_defeat,0.0,duration,duration)
	defeat_animation.tween_callback(finish_defeat)

func _sample_defeat(elapsed: float) -> void:
	if not defeating or disposed: return
	if defeat_uses_faint:
		clip_time = minf(elapsed,float(clips[clip].total)-0.000001)
		apply_frame()
	# Child visibility keeps fog-owned parent visibility and hidden shadows intact.
	sprite.visible = int(elapsed/profile.defeat_blink_interval) % 2 == 0


func get_display_name() -> String:
	if profile != null:
		var configured := profile.display_name.strip_edges()
		if not configured.is_empty(): return configured
		var species := profile.directory.trim_suffix("/").get_file()
		if not species.is_empty(): return species
	return super.get_display_name()
