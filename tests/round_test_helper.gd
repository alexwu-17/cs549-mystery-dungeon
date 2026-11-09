extends RefCounted

static func complete(main: Node3D) -> void:
	# Signal continuations run synchronously; finish each newly scheduled leap.
	for iteration in range(100):
		if not main.resolving_turn:
			if main.victory: main.player.attack_leap.finish()
			complete_defeats(main)
			return
		if main.player.attack_leap.active:
			main.player.attack_leap.finish()
		elif is_instance_valid(main.boss) and main.boss.character_visual.active:
			main.boss.character_visual.finish()
		else:
			for enemy in main.enemies:
				if enemy.attack_leap.active:
					enemy.attack_leap.finish()
					break
	assert(not main.resolving_turn, "Round did not complete deterministically")


static func complete_introduction(main: Node3D) -> void:
	for iteration in range(5):
		if not main.player.transition_locked:
			return
		var tween: Tween = main.floor_introduction.animation
		if tween == null or not tween.is_valid():
			return
		tween.pause()
		tween.custom_step(10.0)
	assert(not main.player.transition_locked)


static func use_static_test_visuals(main: Node3D) -> void:
	# Generic procedural transform/timing fixture; art is still native Pokemon.
	configure_static_test_visual(main.get_node("Player"))
	main.get_node("Entities").child_entered_tree.connect(func(actor: Node):
		if actor.has_node("VisualController"): configure_static_test_visual(actor))


static func configure_static_test_visual(actor: Node) -> void:
	var visual: Node = actor.get_node("VisualController")
	var profile: PokemonSpriteProfile = visual.profile
	var sprite_path: NodePath = visual.sprite_path
	var sprite: Sprite3D = actor.get_node(sprite_path.get_concatenated_names().trim_prefix("../"))
	var clips := PokemonSpriteLibrary.load_species(profile.directory, profile.animations.values())
	visual.set_script(preload("res://scripts/effects/character_visual.gd"))
	visual.sprite_path = sprite_path
	visual.display_name = profile.display_name
	var names := ["front", "right", "back", "left"]
	var rows := [0, 2, 4, 6]
	for index in range(4):
		visual.textures[names[index]] = clips.Idle.rows[rows[index]][0].texture
		visual.textures["attack_" + names[index]] = clips.Attack.rows[rows[index]][0].texture
	visual.textures["charge"] = clips.get("Charge", clips.Idle).rows[0][0].texture
	var strike: Dictionary = clips.get("Strike", clips.Attack)
	for index in range(8):
		visual.textures["spin_%02d" % (index + 1)] = strike.rows[0][mini(index, strike.durations.size()-1)].texture
	sprite.texture = visual.textures.front
	sprite.pixel_size = profile.pixel_size
	visual.foot_anchor = Vector2(sprite.texture.get_width()/2.0, sprite.texture.get_height())


static func complete_defeats(main: Node3D) -> void:
	for enemy in main.retiring_enemies.duplicate():
		if is_instance_valid(enemy): enemy.character_visual.finish_defeat()
	if is_instance_valid(main.boss): main.boss.character_visual.finish_defeat()


static func use_legacy_battle_stats(main: Node3D) -> void:
	# Existing combat fixtures intentionally retain HP20/HP6 and level5.
	# Production species binding is exercised by validate_battle_state.gd.
	main.get_node("Player").species_data = null
	main.healing_on_kill = 3
	main.get_node("Entities").child_entered_tree.connect(func(actor: Node):
		if actor is Skeleton or actor is Minotaur:
			actor.species_data = null)
