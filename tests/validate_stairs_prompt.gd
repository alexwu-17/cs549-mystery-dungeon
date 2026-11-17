extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
func _initialize() -> void: call_deferred("validate")
func validate() -> void:
 root.size = Vector2i(1920,1080)
 var main = load("res://scenes/main/main.tscn").instantiate()
 main.use_elevation_test = true
 root.add_child(main)
 Helper.complete_introduction(main)
 main.cancel_round()
 var data := DungeonData.new()
 data.set_tile(Vector2i.ZERO,DungeonData.TileType.FLOOR)
 data.set_tile(Vector2i.RIGHT,DungeonData.TileType.STAIRS)
 data.stairs_position = Vector2i.RIGHT
 main.dungeon = data
 assert(main.dungeon_renderer.render_dungeon(data))
 main.spawn_test_enemies()
 main.player.setup(Vector2i.ZERO,data,main.dungeon_renderer)
 var floor_before: int = main.floor_number
 main.dialogue.append_event(&"fully_restored")
 var saved_history: Array = main.dialogue.history.duplicate(true)
 var saved_sequence: int = main.dialogue.sequence
 main.player.try_move(Vector2i.RIGHT)
 assert(main.stairs_prompt != null and main.player.transition_locked)
 assert(main.dialogue.history.size() == 1 and main.dialogue.history[0].type == &"stairs_question")
 for frame in range(3): await process_frame
 main.stairs_prompt._position()
 assert(main.stairs_prompt.choice_panel.position.y + main.stairs_prompt.choice_panel.size.y < main.dialogue.panel.global_position.y)
 assert(main.floor_number == floor_before and not main.resolving_turn)
 var key := InputEventKey.new()
 key.pressed = true
 key.keycode = KEY_S
 main.stairs_prompt._input(key)
 assert(main.stairs_prompt.selected == 1)
 key.keycode = KEY_ENTER
 main.stairs_prompt._input(key)
 assert(main.stairs_prompt == null and not main.player.transition_locked)
 assert(main.dialogue.history == saved_history and main.dialogue.sequence == saved_sequence)
 assert(main.player.grid_position == Vector2i.RIGHT)
 main.player.holding_still = true
 main.player.try_move(Vector2i.UP)
 assert(main.player.grid_position == Vector2i.RIGHT and main.player.facing == Vector2i.UP and main.stairs_prompt == null)
 main.player.holding_still = false
 main.player.try_move(Vector2i.LEFT)
 Helper.complete(main)
 main.player.try_move(Vector2i.RIGHT)
 assert(main.stairs_prompt != null)
 main.stairs_prompt.choose(true)
 assert(main.player.transition_locked and main.stairs_prompt == null)
 Helper.complete_introduction(main)
 assert(main.floor_number == floor_before+1)
 var panel = main.hud.get_node("Screen/MovePanel")
 main.floor_introduction.hide()
 panel._show_details(0)
 assert(panel.details.visible)
 main.floor_introduction.cover_immediately()
 assert(not panel.details.visible)
 panel._show_details(0)
 assert(not panel.details.visible)
 assert(main.floor_introduction.z_index > panel.details.z_index)
 main.free()
 await process_frame
 print("PASS: stairs choice/navigation/stay/rotation/reentry/proceed; no outgoing enemy phase; tooltip suppression/title priority")
 quit()
