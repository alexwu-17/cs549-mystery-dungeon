extends RefCounted

static func complete(main: Node3D) -> void:
	# Signal continuations run synchronously; finish each newly scheduled leap.
	for iteration in range(100):
		if not main.resolving_turn:
			return
		if main.player.attack_leap.active:
			main.player.attack_leap.finish()
		else:
			for enemy in main.enemies:
				if enemy.attack_leap.active:
					enemy.attack_leap.finish()
					break
	assert(not main.resolving_turn, "Round did not complete deterministically")
