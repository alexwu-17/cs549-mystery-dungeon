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


static func use_placeholder_visuals(main: Node3D) -> void:
	# Call before adding Main: retain coverage of the original fallback's contracts.
	main.get_node("Player/VisualController").profile = null
	main.get_node("Entities").child_entered_tree.connect(func(actor: Node):
		if actor.has_node("VisualController"):
			actor.get_node("VisualController").profile = null)


static func complete_defeats(main: Node3D) -> void:
	for enemy in main.retiring_enemies.duplicate():
		if is_instance_valid(enemy): enemy.character_visual.finish_defeat()
	if is_instance_valid(main.boss): main.boss.character_visual.finish_defeat()
