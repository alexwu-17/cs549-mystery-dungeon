extends CanvasLayer

const HealthScript = preload("res://scripts/entities/health.gd")
const MoveDisplayData = preload("res://scripts/ui/move_display_data.gd")
@export_range(0.0, 1.0) var game_over_opacity: float = 0.7


func set_game_over(active: bool) -> void:
	$Screen/GameOver/Center/Text/Title.text = "Game Over"
	$Screen/GameOver/Center/Text/Title.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	$Screen/GameOver/Center/Text/Hint.text = "Press R to restart the game"
	$Screen/GameOver.color = Color(0, 0, 0, game_over_opacity)
	$Screen/GameOver.visible = active

func set_victory(enemy_name: String = "Boss") -> void:
	set_game_over(true)
	$Screen/GameOver/Center/Text/Title.text = "Demo Complete"
	$Screen/GameOver/Center/Text/Title.add_theme_color_override("font_color", Color(0.2, 1, 0.3))
	$Screen/GameOver/Center/Text/Hint.text = "You defeated {enemy}!\nPress R to restart the demo.".format({"enemy": enemy_name})

@onready var hp_bar: ProgressBar = $Screen/TopBar/Row/HPBar
@onready var hp_label: Label = $Screen/TopBar/Row/HPLabel
@onready var floor_label: Label = $Screen/TopBar/Row/FloorLabel
@onready var minimap = $Screen/MinimapPanel/Minimap
@onready var move_panel = $Screen/MovePanel
@onready var damage_numbers: DamageNumbers = $Screen/DamageNumbers

var health: HealthScript
var battle_state: PokemonBattleState


func bind_battle_state(source: PokemonBattleState) -> void:
	if battle_state != null and battle_state.moves_changed.is_connected(refresh_moves):
		battle_state.moves_changed.disconnect(refresh_moves)
	battle_state = source
	battle_state.moves_changed.connect(refresh_moves)
	refresh_moves()


func refresh_moves() -> void:
	var entries: Array[MoveDisplayData] = []
	for slot in range(battle_state.moves.size()):
		var move := battle_state.moves[slot]
		if move == null:
			entries.append(null)
			continue
		var entry := MoveDisplayData.new()
		entry.move_name = move.display_name
		entry.attribute_name = move.move_type
		entry.category = ["Physical", "Special", "Status"][move.category]
		entry.current_pp = battle_state.remaining_pp[slot]
		entry.maximum_pp = move.maximum_pp
		entry.damage_text = "No direct damage" if move.category == PokemonMoveData.Category.STATUS else "Power: %d" % move.power
		entry.description = move.description
		entries.append(entry)
	move_panel.set_moves(entries)


func bind_health(source: HealthScript) -> void:
	if health != null and health.changed.is_connected(update_health):
		health.changed.disconnect(update_health)
	health = source
	health.changed.connect(update_health)
	update_health(health.current, health.maximum)


func update_health(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d HP" % [current, maximum]


func refresh_map(data: DungeonData, player_position: Vector2i, enemies: Array[Skeleton], floor_number: int) -> void:
	floor_label.text = "Floor #%d" % floor_number
	minimap.refresh(data, player_position, enemies)
