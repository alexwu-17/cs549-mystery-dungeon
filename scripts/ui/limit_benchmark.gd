class_name LimitBenchmark
extends PanelContainer

static var cap_owner: WeakRef
static var saved_cap: int = 0
var main: Node3D
var selected: int = 20
var counts: Label
var requested: int = 20
var actual: int = 0
var capacity: int = 0

static func apply_cap(owner: Node) -> void:
	if cap_owner == null or cap_owner.get_ref() == null:
		saved_cap = Engine.max_fps
	cap_owner = weakref(owner)
	Engine.max_fps = 60

static func restore_cap(owner: Node) -> void:
	if cap_owner != null and cap_owner.get_ref() == owner:
		Engine.max_fps = saved_cap
		cap_owner = null

func initialize(source: Node3D) -> void:
	main = source
	anchor_left = 1
	anchor_right = 1
	offset_left = -278
	offset_right = -18
	offset_top = 340
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.05, 0.85)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "Enemy test - 30 x 22"
	column.add_child(title)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	for step: int in [-5, 5]:
		var count_button := Button.new()
		count_button.text = "%+d" % step
		count_button.focus_mode = Control.FOCUS_NONE
		count_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_button.pressed.connect(change_count.bind(step))
		controls.add_child(count_button)
	counts = Label.new()
	column.add_child(counts)
	var button := Button.new()
	button.text = "Reset Test"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(main.start_new_run)
	column.add_child(button)
	update_counts()

func change_count(step: int) -> void:
	selected = clampi(selected + step, 0, 1000)
	update_counts()

func prepare() -> void:
	requested = selected
	main.turn_rng.seed = BenchmarkDungeonFactory.SEED

func create_floor() -> DungeonData:
	var data := BenchmarkDungeonFactory.create()
	var candidates := BenchmarkDungeonFactory.candidates(data)
	capacity = candidates.size()
	actual = mini(requested, capacity)
	data.enemy_spawns.assign(candidates.slice(0, actual))
	update_counts()
	return data

func update_counts() -> void:
	if counts == null: return
	counts.text = "Selected: %d (apply with Reset)\nRequested: %d / Spawned: %d\nCapacity: %d" % [selected, requested, actual, capacity]
