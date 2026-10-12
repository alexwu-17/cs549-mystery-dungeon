extends RefCounted

static func format_event(kind: StringName, data: Dictionary) -> String:
	match kind:
		&"attack": return "%s attacks %s for %d damage." % [data.actor, data.target, data.amount]
		&"defeat": return "%s was defeated." % data.target
		&"heal": return "Swordsman recovered %d HP." % data.amount
		&"charging": return "Minotaur is powering up!"
		&"charge_miss": return "Minotaur's charged attack missed!"
		&"cooldown": return "Minotaur is recovering."
		&"game_over": return "Swordsman was defeated. Game over."
		&"victory": return "Minotaur was defeated. Victory!"
	return ""
