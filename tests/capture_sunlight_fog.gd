extends SceneTree
const Helper = preload("res://tests/round_test_helper.gd")
const Snapshots = preload("res://tests/validate_terraces.gd")
func _initialize(): call_deferred("run")
func capture() -> Image:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run():
	root.size=Vector2i(1920,1080)
	TestDungeonFactory.rng.seed=4
	var main=load("res://scenes/demos/sunlight_demo.tscn").instantiate()
	root.add_child(main)
	Helper.complete_introduction(main)
	for i in range(15): await process_frame
	var effect=main.get_node("SunlightAtmosphere")
	main.hud.hide()
	main.process_mode=Node.PROCESS_MODE_DISABLED
	effect.ground_mist.material.set_shader_parameter("preview_time",0.0)
	var snapshot=Snapshots.snapshot(main.dungeon)
	var rng=main.turn_rng.state
	var hidden:Array=[]
	for enemy in main.enemies:
		if not enemy.visible: hidden.append(enemy)
	assert(not hidden.is_empty(),"Fixture must include hidden enemies")
	effect.mesh_effect.hide()
	var off=await capture()
	effect.mesh_effect.show()
	var on=await capture()
	var dark_changed:=0
	for y in range(on.get_height()):
		for x in range(on.get_width()):
			var a=off.get_pixel(x,y)
			var b=on.get_pixel(x,y)
			if maxf(a.r,maxf(a.g,a.b))<0.15 and b.r-a.r>0.01: dark_changed+=1
	assert(dark_changed>20,"Beam must render across dark backgrounds")
	assert(Snapshots.snapshot(main.dungeon)==snapshot and main.turn_rng.state==rng)
	for enemy in hidden: assert(not enemy.visible)
	on.save_png("res://.godot/sunlight_prototypes/continuous_fog_beam.png")
	print("PASS: beam crosses dark background pixels=",dark_changed,"; dungeon/fog/RNG unchanged, hidden enemies remain hidden")
	main.free()
	quit()
