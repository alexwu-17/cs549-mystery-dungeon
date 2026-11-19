extends Node

const TutorialDialogue = preload("res://scripts/ui/tutorial_dialogue.gd")
const ELECTRO_BALL = preload("res://config/moves/electro_ball.tres")

var main: Node3D
var stage := &"opening"
var modal: Control
var growl_uses: int = 0
var growl_reminder_pending: bool = false

func _exit_tree() -> void:
	if is_instance_valid(modal):
		modal.free()

func start(game: Node3D) -> void:
	main = game
	main.round_finished.connect(_on_round_finished)
	_show([
		"Welcome to the Mystery Dungeon Tutorial! Press space/enter to continue reading.",
		"Press W to move up, A to move left, S to move down, and D to move right.",
		"Hold down one of the directional buttons to run until you stop holding the button or hit a wall or enemy."
	], &"approach")

func _show(lines: Array[String], next: StringName) -> void:
	main.player.stop_held_movement()
	main.player.transition_locked = true
	modal = TutorialDialogue.new()
	main.hud.get_node("Screen").add_child(modal)
	modal.completed.connect(func():
		modal.queue_free()
		modal = null
		if stage == &"projectile" and next == &"combat":
			# Restore the guided target without heal feedback or a dialogue event.
			for enemy in main.enemies:
				enemy.health.current = enemy.health.maximum
				enemy.health.changed.emit(enemy.health.current, enemy.health.maximum)
		stage = next
		if next == &"finished":
			main.tutorial_finished.emit.call_deferred()
		elif is_instance_valid(main) and not main.game_over:
			main.player.transition_locked = false
	)
	modal.begin(main.dialogue, lines)

func on_player_moved() -> bool:
	if stage != &"approach" or not main.dungeon.rooms[1].has_point(main.player.grid_position):
		return false
	stage = &"encounter"
	main.refresh_fog()
	_show([
		"You have encountered an enemy Pokemon.",
		"Enemy Pokemon will try to follow your Pokemon throughout the dungeon.",
		"Let's engage in combat with this one.",
		"Combat in this game is turn based. Every movement or attack is considered one turn.",
		"You get to take the first action every turn, and enemies will follow with their own actions.",
		"In the top left corner is your HP bar. Once it hits 0, you will be defeated.",
		"Deal damage to other Pokemon to defeat them!",
		"Let's start with the basic attack. Press space to perform one."
	], &"basic")
	return true

func enemy_can_act() -> bool:
	return stage in [&"basic", &"projectile", &"combat"]

func on_enemy_attack(enemy: Skeleton, move: PokemonMoveData) -> void:
	if move != null and move.move_id == &"tackle":
		# The scene guarantees the opening Tackle; this actor then uses basics.
		# A fresh tutorial spawns a new actor with its opening policy restored.
		enemy.attack_policy = null

func enemy_damage(amount: int, enemy: Node) -> int:
	if stage == &"projectile":
		return amount
	if stage != &"combat":
		return 0
	# Ensure the first retaliation can demonstrate healing even on a lethal hit.
	if main.player.health.current == main.player.health.maximum:
		return mini(amount, maxi(0, enemy.health.current - 1))
	return amount

func on_player_move(move: PokemonMoveData) -> void:
	if move == null or move.move_id != &"growl": return
	growl_uses += 1
	if growl_uses > 5:
		var state: PokemonBattleState = main.player.battle_state
		state.remaining_pp[state.moves.find(move)] = 0
		state.moves_changed.emit()
		growl_reminder_pending = true

func on_enemy_defeated() -> void:
	if stage == &"combat":
		stage = &"defeated"

func _on_round_finished() -> void:
	match stage:
		&"combat":
			if growl_reminder_pending:
				growl_reminder_pending = false
				_show(["Use damaging moves to wittle down the enemy's HP!"], &"combat")
		&"basic":
			_show([
				"Basic attacks have no limit to their use. You can use them strategically to consume a turn so the enemy can approach you!",
				"On the left side of the screen. You can see your Pokemon's moves.",
				"Moves can be used a limited number of times, as shown by a number next to them known as Power Points (PP).",
				"Pokemon have stats that determine the amount of damage they can deal and the amount of damage they take from other Pokemon.",
				"Moves that can deal damage are classified as Physical or Special and scale off of a Pokemon's Attack or Special Attack respectively.",
				"Damage taken from these attacks are dependent on the Pokemon's Defense or Special Defense.",
				"Some moves are projectiles that can hit from far away. You have one mapped to the O key.",
				"Hold shift to adjust the direction your Pokemon is facing without consuming a move. Try adjusting the direction and aiming at the enemy with your projectile move."
			], &"projectile")
		&"projectile":
			_show([
				"There are also status moves that affect either your Pokemon's or enemy Pokemon's stats.",
				"Please hover over each move with your mouse to see what they do!",
				"Pokemon and moves have types, which have strengths and weaknesses to other types. Please refer to a Pokemon resistance and strength chart for more details.",
				"You now have the basics of combat down. Go defeat the enemy!"
			], &"combat")
		&"defeated":
			_show([
				"You seem to have taken damage. You are able to heal up over time by not engaging in combat.",
				"Hold J in order to speed up turns and heal faster. You are able to keep holding J until an enemy Pokemon appears in view.",
				"Now hold J until you are healed to full."
			], &"healing")
		&"healing":
			if main.player.health.current == main.player.health.maximum:
				_show(["Search for the staircase tile to progress to the next floor.", "Use the map in the top right corner to keep track of where you are. The map will fill up as you explore the dungeon."], &"stairs")

func can_use_stairs() -> bool:
	return stage == &"stairs"

func finish_tutorial() -> void:
	_show(["You are now ready for the world of Mystery Dungeon! Explore to your heart's content!"], &"finished")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_instance_valid(modal):
		if event.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
		return
	if stage in [&"combat", &"stairs"]:
		return
	var allowed := false
	match stage:
		&"approach":
			allowed = event.is_action_pressed("move_up") or event.is_action_pressed("move_down") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right")
		&"basic":
			allowed = event.is_action_pressed("basic_attack")
		&"projectile":
			allowed = event.is_action_pressed("hold_still")
			if Input.is_action_pressed("hold_still"):
				allowed = allowed or event.is_action_pressed("move_up") or event.is_action_pressed("move_down") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right")
			if event.is_action_pressed("move_slot_3") and main.enemies.size() == 1:
				var delta: Vector2i = main.enemies[0].grid_position - main.player.grid_position
				allowed = delta == main.player.facing * (absi(delta.x) + absi(delta.y)) and absi(delta.x) + absi(delta.y) <= ELECTRO_BALL.range_tiles
		&"healing":
			allowed = event.is_action_pressed("wait_turn")
	if not allowed:
		get_viewport().set_input_as_handled()
