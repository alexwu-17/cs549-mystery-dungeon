extends SceneTree
const Helper=preload("res://tests/round_test_helper.gd")
func _initialize(): call_deferred("run")
func difference(a:Image,b:Image) -> float:
 var aa=a.get_data()
 var bb=b.get_data()
 var total:=0.0
 for i in range(aa.size()): total+=abs(int(aa[i])-int(bb[i]))
 return total/aa.size()
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
 for i in range(30): await process_frame
 main.hud.hide()
 main.process_mode=Node.PROCESS_MODE_DISABLED
 var ground=main.get_node("SunlightAtmosphere").ground_mist
 var uploads=ground.uploads
 ground.material.set_shader_parameter("preview_time",0.0)
 var a=await capture()
 var frozen=await capture()
 assert(difference(a,frozen)==0.0,"Frozen scene must match exactly")
 ground.material.set_shader_parameter("preview_time",3.0)
 var b=await capture()
 var delta=difference(a,b)
 assert(delta>0.01,"Mist alone must visibly change the frame")
 a.save_png("res://.godot/sunlight_prototypes/mist_motion_0.png")
 b.save_png("res://.godot/sunlight_prototypes/mist_motion_3.png")
 ground.material.set_shader_parameter("preview_time",-1.0)
 var live_a=await capture()
 for i in range(180): await process_frame
 var live_b=await capture()
 var live_delta=difference(live_a,live_b)
 assert(live_delta>0.01 and ground.uploads==uploads)
 print("PASS: isolated fog animation; frozen delta=0, 3s fog-only delta=",delta," live idle delta=",live_delta," (mean 8-bit channel levels); no mask uploads")
 main.free()
 quit()
