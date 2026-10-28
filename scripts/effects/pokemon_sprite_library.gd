class_name PokemonSpriteLibrary
extends RefCounted

# One immutable atlas/metadata set shared by every actor of a species.
static var cache: Dictionary = {}
const CARDINAL_ROWS := [0, 2, 4, 6]

static func load_species(directory: String, names: Array = ["Idle", "Walk", "Attack", "Hurt"]) -> Dictionary:
	var cache_key := directory + str(names)
	if cache.has(cache_key):
		return cache[cache_key]
	var parser := XMLParser.new()
	if parser.open(directory.path_join("AnimData.xml")) != OK:
		push_warning("Pokémon metadata unavailable: " + directory)
		return {}
	var records: Dictionary = {}
	var record: Dictionary = {}
	var field := ""
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			field = parser.get_node_name()
			if field == "Anim": record = {"durations": []}
		elif parser.get_node_type() == XMLParser.NODE_TEXT:
			var value := parser.get_node_data().strip_edges()
			if value.is_empty(): continue
			if field == "Duration": record.durations.append(maxi(1, int(value)) / 60.0)
			elif field in ["Name", "CopyOf", "FrameWidth", "FrameHeight", "HitFrame", "RushFrame", "ReturnFrame"]: record[field] = value
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "Anim":
			records[record.Name] = record
	var requested := names.duplicate()
	if records.has("Faint") and not requested.has("Faint"): requested.append("Faint")
	var result: Dictionary = {}
	# Load only configured actions, including optional boss clips; retain source files untouched.
	for name: String in requested:
		if not records.has(name):
			push_warning(directory + ": missing " + name + "; using Idle/placeholder fallback")
			continue
		var info: Dictionary = records[name]
		var source: String = str(info.get("CopyOf", name))
		if source != name:
			if not records.has(source): continue
			info = records[source]
		var size := Vector2i(int(info.get("FrameWidth", 0)), int(info.get("FrameHeight", 0)))
		var durations: Array = info.durations
		var path := directory.path_join(source + "-Anim.png")
		if size.x <= 0 or size.y <= 0 or durations.is_empty() or not ResourceLoader.exists(path):
			push_warning("Missing or invalid Pokémon animation: " + path)
			continue
		var sheet := load(path) as Texture2D
		var pixels := sheet.get_image()
		if pixels != null and pixels.is_compressed(): pixels.decompress()
		if pixels == null or pixels.get_width() != size.x * durations.size() or pixels.get_height() not in [size.y, size.y * 8]:
			push_warning("Invalid Pokémon sheet dimensions: " + path)
			continue
		var offset_path := directory.path_join(source + "-Offsets.png")
		var offsets: Image
		if ResourceLoader.exists(offset_path):
			offsets = (load(offset_path) as Texture2D).get_image()
			if offsets != null and offsets.is_compressed(): offsets.decompress()
		var rows: Dictionary = {}
		for row in CARDINAL_ROWS:
			var frames: Array = []
			for index in range(durations.size()):
				var region := Rect2i(Vector2i(index * size.x, (row if pixels.get_height() > size.y else 0) * size.y), size)
				var body := Vector2(size) / 2.0
				var top := size.y
				var left := size.x
				var right := -1
				var bottom := -1
				for y in range(size.y):
					for x in range(size.x):
						var point := region.position + Vector2i(x,y)
						if pixels.get_pixelv(point).a > 0.5:
							top = mini(top, y)
							bottom = maxi(bottom, y)
							left = mini(left, x)
							right = maxi(right, x)
						if offsets != null and offsets.get_size() == pixels.get_size():
							var marker := offsets.get_pixelv(point)
							if marker.a > 0.5 and marker.g > 0.5 and marker.r < 0.5 and marker.b < 0.5:
								body = Vector2(x,y)
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(region)
				atlas.filter_clip = true
				var uvs := PackedVector2Array()
				for y in range(9):
					for x in range(9):
						var uv := Vector2((x + 0.5) / 9.0, (y + 0.5) / 9.0)
						if pixels.get_pixelv(region.position + Vector2i(Vector2(size) * uv)).a > 0.5: uvs.append(uv)
				atlas.set_meta("pokemon_opaque_uvs", uvs)
				atlas.set_meta("pokemon_opaque_top", top)
				atlas.set_meta("pokemon_opaque_rect", Rect2i(left,top,maxi(0,right-left+1),maxi(0,bottom-top+1)))
				frames.append({"texture": atlas, "body": body})
			rows[row] = frames
		var total := 0.0
		for duration: float in durations: total += duration
		result[name] = {"rows": rows, "durations": durations, "total": total, "hit_frame": int(info.get("HitFrame", 0)), "rush_frame": int(info.get("RushFrame", 0)), "return_frame": int(info.get("ReturnFrame", durations.size()-1))}
	cache[cache_key] = result
	return result
