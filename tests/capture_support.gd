extends RefCounted
## Shared capture dispatch, deterministic draw/readback and character fixture.
const Helper = preload("res://tests/round_test_helper.gd")

static func run(tree: SceneTree, scenarios: Dictionary, default_scenario: String) -> void:
	var selected := default_scenario
	for argument in OS.get_cmdline_user_args():
		if argument == "--list":
			print("Scenarios: ", ", ".join(scenarios.keys()), "; all")
			tree.quit()
			return
		if argument.begins_with("--scenario="):
			selected = argument.trim_prefix("--scenario=")
	if selected != "all" and not scenarios.has(selected):
		push_error("Unknown capture scenario: " + selected)
		tree.quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Captures require the normal renderer; use --list for headless discovery.")
		tree.quit(1)
		return
	var names: Array = scenarios.keys() if selected == "all" else [selected]
	for name in names:
		print("CAPTURE SCENARIO: ", name)
		var completed: Variant = await scenarios[name].call()
		if completed != true:
			push_error("Capture scenario did not complete: " + str(name))
			tree.quit(1)
			return
	print("PASS: capture group completed: ", selected)
	tree.quit()

static func image(tree: SceneTree) -> Image:
	# Inactive windows may not emit frame_post_draw; explicitly draw diagnostics.
	RenderingServer.force_draw(false)
	return tree.root.get_texture().get_image()

static func save(tree: SceneTree, path: String) -> void:
	save_image(image(tree), path)

static func save_image(picture: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert(picture != null and not picture.is_empty())
	assert(picture.save_png(path) == OK)

static func character_fixture(tree: SceneTree) -> Node3D:
	tree.root.size = Vector2i(1920,1080)
	var main = load("res://scenes/main/demo_main.tscn").instantiate()
	tree.root.add_child(main)
	Helper.complete_introduction(main)
	main.cancel_round()
	var data := DungeonData.new()
	data.rooms = [Rect2i(-3,-3,9,8)]
	data.room_elevations = [0]
	for y in range(-3,5):
		for x in range(-3,6):
			data.set_tile(Vector2i(x,y),DungeonData.TileType.FLOOR)
	data.player_spawn = Vector2i.ZERO
	data.enemy_spawns = [Vector2i(2,0)]
	main.dungeon = data
	main.dungeon_renderer.render_dungeon(data)
	main.spawn_test_enemies()
	main.player.setup(Vector2i.ZERO, data, main.dungeon_renderer)
	var boss = load("res://scenes/enemies/minotaur.tscn").instantiate()
	main.entities.add_child(boss)
	boss.setup(Vector2i(3,-2),data,main.dungeon_renderer)
	main.boss = boss
	main.refresh_fog()
	return main

static func stats(values: Array) -> Dictionary:
	var sorted:=values.duplicate()
	sorted.sort()
	var total:=0.0
	for value in values: total+=value
	return {"mean":total/values.size(),"p95":sorted[ceili(values.size()*.95)-1],"p99":sorted[ceili(values.size()*.99)-1],"max":sorted.back()}

static func counts(node: Node) -> Dictionary:
	var result: Dictionary={"nodes":1,"mesh_nodes":int(node is MeshInstance3D),"multimesh_nodes":int(node is MultiMeshInstance3D)}
	for child in node.get_children():
		var sub:=counts(child)
		for key in result: result[key]+=sub[key]
	return result
