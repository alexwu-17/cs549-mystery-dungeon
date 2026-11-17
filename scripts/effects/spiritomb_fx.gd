class_name SpiritombFx
extends RefCounted
static var cache: Dictionary = {}
static func layout(id: String) -> Dictionary:
	if not cache.has(id):
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/pixelfx/" + id + ".json"))
		var info: Dictionary = document.meta.pixelfx
		var size := Vector2(info.frameSize[0],info.frameSize[1])
		cache[id] = {"texture":load("res://assets/effects/pixelfx/"+id+".png"),"columns":int(info.columns),"rows":ceili(float(info.frames)/info.columns),"frames":int(info.frames),"size":size,"pivot":Vector2(info.runtimePivot[0],info.runtimePivot[1])}
	return cache[id]
