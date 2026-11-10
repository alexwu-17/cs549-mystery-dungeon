extends SceneTree
const Helper=preload("res://tests/round_test_helper.gd")
const Support=preload("res://tests/capture_support.gd")
var label="current"
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--label="): label=a.trim_prefix("--label=")
 call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  push_error("Profile requires normal rendering")
  quit(1)
  return
 root.size=Vector2i(1920,1080)
 TestDungeonFactory.rng.seed=54903
 var main=load("res://scenes/main/demo_main.tscn").instantiate()
 main.get_node("Player").species_data=load("res://config/species/piplup.tres")
 main.get_node("Player/VisualController").profile=load("res://config/pokemon_piplup.tres")
 root.add_child(main)
 # Let the introduction actually render before measuring gameplay steps.
 var warm_start=Time.get_ticks_usec()
 for warm_frame in range(3):
  await process_frame
  RenderingServer.force_draw(false)
 print("INTRO pipeline preparation ms=",(Time.get_ticks_usec()-warm_start)/1000.0)
 Helper.complete_introduction(main)
 main.cancel_round()
 main.set_process(false)
 main.player.character_visual.set_process(false)
 var positions:Array[Vector2i]=[]
 for room in main.dungeon.rooms:
  positions.append(room.end-Vector2i.ONE)
  positions.append(Vector2i(room.position.x,room.end.y-1))
 var results=[]
 for trial in range(2):
  for index in range(positions.size()):
   var tile=positions[index]
   main.player.setup(tile,main.dungeon,main.dungeon_renderer)
   var refresh_start=Time.get_ticks_usec()
   main.refresh_fog()
   var refresh_cpu=Time.get_ticks_usec()-refresh_start
   await process_frame
   var start=Time.get_ticks_usec()
   main.update_presentation()
   var cpu=Time.get_ticks_usec()-start
   start=Time.get_ticks_usec()
   RenderingServer.force_draw(false)
   var draw=Time.get_ticks_usec()-start
   var active=0
   for v in main.dungeon_renderer.fog_visuals:
    if v.occluded:active+=1
   results.append({"trial":trial,"tile":str(tile),"cpu_ms":cpu/1000.0,"draw_ms":draw/1000.0,"refresh_ms":refresh_cpu/1000.0,"faded":active})
   if trial==0 and index<3: Support.save(self,"res://.godot/visibility-"+label+"-"+str(index)+".png")
 var idle=[]
 for frame in range(60):
  await process_frame
  var start=Time.get_ticks_usec()
  main.update_presentation()
  idle.append((Time.get_ticks_usec()-start)/1000.0)
 var file=FileAccess.open("res://.godot/visibility-"+label+"-metrics.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"positions":results,"idle":Support.stats(idle)}," "))
 file.close()
 print("PROFILE ",label,": idle update ",Support.stats(idle),"; positions=",results)
 main.cancel_round()
 main.free()
 print("PASS: reproducible room-corner first/repeated activation profile ",label)
 quit()
