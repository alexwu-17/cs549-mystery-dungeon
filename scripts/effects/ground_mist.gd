class_name GroundMist
extends MeshInstance3D
## Floor-owned, batched low wisps. No lights, environment overrides or gameplay writes.
const SHADER = preload("res://shaders/ground_mist.gdshader")
var coverage: Image
var coverage_texture: ImageTexture
var bounds: Rect2i
var uploads: int = 0
var material := ShaderMaterial.new()

func _init() -> void:
	name = "GroundMist"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shader = SHADER
	material_override = material

func build(main: Node3D, area: Rect2i) -> void:
	bounds = area
	coverage = Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_L8)
	coverage_texture = ImageTexture.create_from_image(coverage)
	material.set_shader_parameter("coverage_mask",coverage_texture)
	material.set_shader_parameter("mask_origin",Vector2(bounds.position))
	material.set_shader_parameter("mask_size",Vector2(bounds.size))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var tile := Vector2i(x,y)
			var center := Vector3(x,0.1,y)
			if main.dungeon.is_walkable(tile):
				center = main.dungeon_renderer.get_entity_world_position(tile)
			else:
				var backdrop: CaveTerrainBackdrop = main.dungeon_renderer.cave_background
				if is_instance_valid(backdrop) and backdrop.ground_surface != null and backdrop.ground_surface.cells.has(tile):
					center.y = backdrop.ground_surface.plateau_height(tile)
			for layer in range(3):
				var height := 0.18+layer*0.25
				var corners := [Vector3(-0.5,height,-0.5),Vector3(0.5,height,-0.5),Vector3(0.5,height,0.5),Vector3(-0.5,height,0.5)]
				for index in [0,1,2,0,2,3]:
					tool.set_color(Color(1,1,1,1.0-layer*0.25))
					tool.add_vertex(center+corners[index])
	mesh = tool.commit()

func refresh(data: DungeonData) -> void:
	if coverage == null: return
	var pixels := PackedByteArray()
	pixels.resize(bounds.size.x*bounds.size.y)
	# One mask upload per discovery change; no image readbacks or per-frame scans.
	for tile: Vector2i in data.bright_tiles:
		for dy in range(-4,5):
			for dx in range(-4,5):
				var p := tile+Vector2i(dx,dy)
				if not bounds.has_point(p): continue
				var pixel := p-bounds.position
				var index := pixel.y*bounds.size.x+pixel.x
				if pixels[index] == 255: continue
				var strength := maxf(0.0,1.0-Vector2(dx,dy).length()/4.5)
				if data.is_walkable(p): strength = 1.0 if data.is_bright(p) else (0.25 if data.discovered_tiles.has(p) else 0.0)
				pixels[index] = maxi(pixels[index],roundi(strength*255.0))
	coverage.set_data(bounds.size.x,bounds.size.y,false,Image.FORMAT_L8,pixels)
	coverage_texture.update(coverage)
	uploads += 1
