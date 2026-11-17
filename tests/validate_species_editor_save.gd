extends SceneTree
## Run with --headless --editor --path . --script tests/validate_species_editor_save.gd.
## Non-tool Resource placeholder behavior differs from normal gameplay loading.
func _initialize() -> void:
 assert(Engine.is_editor_hint(), "This regression must run in editor mode")
 var expected := {"budew":["Grass"],"chimchar":["Fire"],"drapion":["Poison","Dark"],"feebas":["Water"],"gible":["Ground","Dragon"],"glameow":["Normal"],"mankey":["Fighting"],"piplup":["Water"],"psyduck":["Water"],"riolu":["Fighting"],"spiritomb":["Ghost","Dark"],"stunky":["Poison","Dark"],"tangela":["Grass"],"turtwig":["Grass"],"vulpix":["Fire"]}
 var path := "res://.godot/species_editor_roundtrip.tres"
 for name in expected:
  var species = load("res://config/species/" + name + ".tres")
  assert(typeof(species.get("types")) == TYPE_PACKED_STRING_ARRAY, name)
  assert(species.get("types") == PackedStringArray(expected[name]), name)
  var copy = species.duplicate()
  assert(ResourceSaver.save(copy,path) == OK)
  var reloaded = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
  assert(reloaded.get("types") == PackedStringArray(expected[name]), name)
 # A populated array must be editable in the inspector placeholder, too.
 var editable = load("res://config/species/chimchar.tres").duplicate()
 editable.set("types", PackedStringArray(["Water","Dragon"]))
 assert(editable.get("types") == PackedStringArray(["Water","Dragon"]))
 assert(ResourceSaver.save(editable,path) == OK)
 var saved = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
 assert(saved.get("types") == PackedStringArray(["Water","Dragon"]))
 print("PASS: all 15 species retain types through editor placeholder load/save/reload; inspector edits persist")
 quit()
