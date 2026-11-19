extends Control
## Demo entry only. Configure the shared player before any gameplay node is ready.
const GAMEPLAY = preload("res://scenes/main/demo_main.tscn")
const Library = preload("res://scripts/effects/pokemon_sprite_library.gd")
const Portrait = preload("res://scripts/ui/starter_portrait.gd")
const SPECIES = [preload("res://config/species/chimchar.tres"), preload("res://config/species/piplup.tres"), preload("res://config/species/turtwig.tres")]
const PROFILES = [preload("res://config/pokemon_chimchar.tres"), preload("res://config/pokemon_piplup.tres"), preload("res://config/pokemon_turtwig.tres")]
## Selection-screen track; leave empty for a silent menu.
@export var menu_music: AudioStream
const PORTRAIT_HEIGHT := 96.0
var menu: CenterContainer
var gameplay: Node3D
var tutorial: Node3D
var choosing: bool = false
var choices: Array[Button] = []
var portraits: Array[Control] = []
var focused_index: int = 0


func _ready() -> void:
	show_tutorial_choice()
	$MenuMusic.finished.connect(_repeat_menu_music)
	if menu_music != null:
		$MenuMusic.stream = menu_music
		$MenuMusic.play()


func _repeat_menu_music() -> void:
	if not is_instance_valid(gameplay) and $MenuMusic.stream != null:
		$MenuMusic.play()


func _shell(title: String) -> VBoxContainer:
	if is_instance_valid(menu):
		remove_child(menu)
		menu.queue_free()
	menu = CenterContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	menu.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	column.add_child(heading)
	return column


func show_tutorial_choice() -> void:
	choosing = false
	var column := _shell("Would you like a tutorial?")
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 24)
	column.add_child(options)
	var yes := _button("Yes", show_tutorial)
	options.add_child(yes)
	options.add_child(_button("No", show_selection))
	yes.grab_focus()


func show_tutorial() -> void:
	if is_instance_valid(tutorial) or is_instance_valid(gameplay):
		return
	$MenuMusic.stop()
	menu.hide()
	$Background.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial = GAMEPLAY.instantiate()
	tutorial.tutorial_mode = true
	tutorial.enemy_respawn_enabled = false
	tutorial.get_node("Player").species_data = preload("res://config/species/pikachu.tres")
	tutorial.get_node("Player/VisualController").profile = preload("res://config/pokemon_pikachu.tres")
	tutorial.tutorial_finished.connect(_finish_tutorial)
	add_child(tutorial)


func _finish_tutorial() -> void:
	if not is_instance_valid(tutorial):
		return
	remove_child(tutorial)
	tutorial.queue_free()
	tutorial = null
	$Background.show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if menu_music != null:
		$MenuMusic.play()
	show_selection()


func show_selection() -> void:
	choosing = true
	choices.clear()
	portraits.clear()
	var column := _shell("Choose your Pokémon")
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 28)
	column.add_child(cards)
	for index in range(3):
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 16)
		cards.add_child(card)
		var clips: Dictionary = Library.load_species(PROFILES[index].directory, ["Idle", "Walk"])
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(230, 180)
		card.add_child(holder)
		var portrait := Portrait.new()
		portrait.configure(clips, PORTRAIT_HEIGHT)
		holder.add_child(portrait)
		portraits.append(portrait)
		var species: PokemonSpeciesData = SPECIES[index]
		var stats := Label.new()
		stats.text = "HP %d\nAtk %d · Sp Atk %d\nDef %d · Sp Def %d" % [species.maximum_hp, species.attack, species.special_attack, species.defense, species.special_defense]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(stats)
		var select := _button(species.display_name, start_starter.bind(index))
		card.add_child(select)
		choices.append(select)
		select.focus_entered.connect(_focus_starter.bind(index))
		card.mouse_entered.connect(_hover_starter.bind(index))
		select.mouse_entered.connect(_hover_starter.bind(index))
	var hint := Label.new()
	hint.text = "A / D or ← / → to choose · Enter / Space to start"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	for index in range(choices.size()):
		choices[index].focus_neighbor_left = choices[index].get_path_to(choices[posmod(index - 1, choices.size())])
		choices[index].focus_neighbor_right = choices[index].get_path_to(choices[(index + 1) % choices.size()])
	choices[0].grab_focus()



func _input(event: InputEvent) -> void:
	if not choosing:
		return
	var direction := 0
	if event.is_action_pressed("move_left"):
		direction = -1
	elif event.is_action_pressed("move_right"):
		direction = 1
	if direction != 0:
		choices[posmod(focused_index + direction, choices.size())].grab_focus()
		get_viewport().set_input_as_handled()


func _hover_starter(index: int) -> void:
	if choosing:
		choices[index].grab_focus()


func _focus_starter(index: int) -> void:
	focused_index = index
	for slot in range(portraits.size()):
		portraits[slot].set_walking(slot == index)


func start_starter(index: int) -> void:
	if is_instance_valid(gameplay) or not choosing or index < 0 or index >= SPECIES.size():
		return
	choosing = false
	for portrait in portraits:
		portrait.set_walking(false)
	$MenuMusic.stop()
	$MenuMusic.stream = null
	gameplay = GAMEPLAY.instantiate()
	gameplay.starter_selection_requested.connect(_return_to_selection)
	gameplay.get_node("Player").species_data = SPECIES[index]
	gameplay.get_node("Player/VisualController").profile = PROFILES[index]
	menu.hide()
	$Background.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Gameplay and floor transitions stay in the inherited Demo scene.
	add_child(gameplay)


func _return_to_selection() -> void:
	if not is_instance_valid(gameplay):
		return
	remove_child(gameplay)
	gameplay.queue_free()
	gameplay = null
	$Background.show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if menu_music != null:
		$MenuMusic.stream = menu_music
		$MenuMusic.play()
	show_selection()


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(230, 52)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	return button
