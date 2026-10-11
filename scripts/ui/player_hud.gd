extends CanvasLayer

const HealthScript = preload("res://scripts/entities/health.gd")
@export_range(0.0, 1.0) var game_over_opacity: float = 0.7


func set_game_over(active: bool) -> void:
	$Screen/GameOver.color = Color(0, 0, 0, game_over_opacity)
	$Screen/GameOver.visible = active

@onready var hp_bar: ProgressBar = $Screen/TopBar/Row/HPBar
@onready var hp_label: Label = $Screen/TopBar/Row/HPLabel
@onready var floor_label: Label = $Screen/TopBar/Row/FloorLabel
@onready var minimap = $Screen/MinimapPanel/Minimap

var health: HealthScript


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
