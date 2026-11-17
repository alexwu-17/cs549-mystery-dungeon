extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	assert(InputMap.action_get_events("hold_still")[0].physical_keycode == KEY_SHIFT)
	var main = load("res://scenes/main/main.tscn").instantiate()
	main.use_elevation_test = true
	root.add_child(main)
	Helper.complete_introduction(main)
	var player: Player = main.player
	var data := DungeonData.new()
	for x in range(5):
		data.set_tile(Vector2i(x, 0), DungeonData.TileType.FLOOR)
		data.bright_tiles[Vector2i(x, 0)] = true
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	var rounds := [0]
	main.round_finished.connect(func(): rounds[0] += 1)
	var pp := player.battle_state.remaining_pp.duplicate()
	Input.action_press("hold_still")
	player.holding_still = true
	var event := InputEventAction.new()
	event.action = &"move_right"
	event.pressed = true
	player._unhandled_input(event)
	assert(player.facing == Vector2i.RIGHT and player.grid_position == Vector2i.ZERO)
	assert(rounds[0] == 0 and player.held_action == &"")
	assert(player.battle_state.remaining_pp == pp and main.peaceful_turns == 0)
	var guide = preload("res://scripts/ui/facing_guide.gd").new()
	guide.player = player
	assert(guide.highlighted_tiles().size() == 5)
	data.bright_tiles.erase(Vector2i(3, 0))
	assert(guide.highlighted_tiles().size() == 3)
	data.set_tile(Vector2i(2, 0), DungeonData.TileType.WALL)
	assert(guide.highlighted_tiles().size() == 2)
	player.round_locked = true
	assert(guide.highlighted_tiles().is_empty())
	event.action = &"move_left"
	player._unhandled_input(event)
	assert(player.facing == Vector2i.RIGHT)
	player.round_locked = false
	Input.action_release("hold_still")
	player.holding_still = false
	assert(guide.highlighted_tiles().is_empty())
	player.try_move(Vector2i.RIGHT)
	Helper.complete(main)
	assert(player.grid_position == Vector2i(1, 0) and rounds[0] == 1)
	guide.free()
	main.free()
	await process_frame
	print("PASS: Shift free facing, no movement/turn/PP/recovery, fog/traversal lane, locks and release")
	quit()
