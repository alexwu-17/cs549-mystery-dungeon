extends RefCounted

const TEMPLATES := {
	&"attack": "{actor} attacks {target} for {amount} damage.",
	&"defeat": "{target} was defeated.",
	&"heal": "{character} recovered {amount} HP.",
	&"charging": "{enemy} is powering up!",
	&"charge_miss": "{enemy}'s charged attack missed!",
	&"cooldown": "{enemy} is recovering.",
	&"game_over": "{character} was defeated. Game over.",
	&"victory": "{enemy} was defeated. Victory!"}

static func format_event(kind: StringName, data: Dictionary) -> String:
	var template: String = TEMPLATES.get(kind, "")
	if template.is_empty(): return ""
	var values := {"character": "Player", "enemy": "Enemy", "actor": "Combatant", "target": "Target", "amount": 0}
	values.merge(data,true)
	return template.format(values)
