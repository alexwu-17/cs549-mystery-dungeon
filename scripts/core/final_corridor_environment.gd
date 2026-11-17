class_name FinalCorridorEnvironment
extends Node3D
## Static, floor-local replacement for low boundary/fill visuals during the approach.
const TORCH: Mesh = preload("res://assets/environment/modular_dungeon/torch.obj")
const TORCH_FLAME: Texture2D = preload("res://assets/effects/pixelfx/torch_flame.png")
static var torch_flame_frames: SpriteFrames
const HEIGHT: float = 2.0
const FLOOR_Y: float = DungeonRenderer.FLOOR_THICKNESS / 2.0
var filled_cells: Array[Vector2i] = []
var torch_anchors: Array[Vector3] = []
var bounds: Rect2i
var approach_active: bool = true

func build(data: DungeonData, renderer: DungeonRenderer, approach: bool = true) -> void:
	approach_active = approach
	for child in get_children(): child.free()
	filled_cells.clear()
	torch_anchors.clear()
	bounds = data.map_bounds
	# Mask only this floor's low walls/fill. Rerendering the sealed arena recreates
	# the normal geometry and layers, without changing renderer configuration.
	for visual in renderer.fog_visuals:
		if (approach and visual.wall) or visual.get("filler", false):
			visual.mesh.layers = 0
	var stone := StandardMaterial3D.new()
	stone.albedo_color = ModularDungeonVisuals.WALL_COLOR
	CaveStoneMaterial.configure(stone)
	var open_cells := data.tiles.duplicate()
	# A rendering-only bay behind spawn keeps the two-tile chase camera out of
	# solid fill. The authoritative corridor still begins at row1.
	if approach:
		for y in range(31, 34):
			for x in range(12, 15):
				open_cells[Vector2i(x, y)] = DungeonData.TileType.VOID
	var caps: Array[Transform3D] = []
	var cores: Array[Transform3D] = []
	var masonry: Array[Transform3D] = []
	var apron: Array[Transform3D] = []
	var floor_scale := Vector3.ONE * ModularDungeonVisuals.SOURCE_SCALE
	var top := FLOOR_Y + HEIGHT if approach else TerrainFillVisuals.wall_top_offset(FLOOR_Y, renderer.conventional_wall_height_scale)
	var core_top := top - 0.16
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var tile := Vector2i(x, y)
			if open_cells.has(tile):
				if not data.is_walkable(tile):
					apron.append(Transform3D(Basis.from_scale(floor_scale), Vector3(x, FLOOR_Y - ModularDungeonVisuals.FLOOR_TOP * floor_scale.y, y)))
				for direction: Vector2i in DungeonData.CARDINALS:
					if not approach or open_cells.has(tile + direction): continue
					for level in range(2):
						var scale := Vector3(0.5, 0.5, 0.5)
						var angle := atan2(float(direction.x), float(direction.y))
						var basis := Basis(Vector3.UP, angle).scaled(scale)
						masonry.append(Transform3D(basis, Vector3(x, FLOOR_Y + level + 0.05, y)))
				continue
			filled_cells.append(tile)
			caps.append(Transform3D(Basis.from_scale(floor_scale), Vector3(x, top - ModularDungeonVisuals.FLOOR_TOP * floor_scale.y, y)))
			cores.append(Transform3D(Basis.IDENTITY, Vector3(x, (core_top - 1.0) / 2.0, y)))
	var core := BoxMesh.new()
	core.size = Vector3(1.0, core_top + 1.0, 1.0)
	_batch("SolidStoneFill", core, cores, stone)
	_batch("AuthoredStoneCaps", ModularDungeonVisuals.FLOOR, caps, stone)
	if approach:
		_batch("TwoLevelWallAssets", ModularDungeonVisuals.WALL, masonry, stone)
		_batch("CameraBayFloor", ModularDungeonVisuals.FLOOR, apron, stone)
	# Symmetrical pairs on alternate rows, mounted in the upper one-tile course.
	for number in range(1, FinalFloorFactory.CORRIDOR_LENGTH if approach else 1, 2):
		for side in [-1, 1]:
			_add_torch(Vector3(13.0 + side * 1.38, FLOOR_Y + 1.45, FinalFloorFactory.corridor_tile(number).y), side)

func _batch(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index in range(transforms.size()):
		instances.set_instance_transform(index, transforms[index])
	batch.multimesh = instances
	batch.material_override = material
	add_child(batch)

func _add_torch(anchor: Vector3, side: int) -> void:
	torch_anchors.append(anchor)
	var torch := MeshInstance3D.new()
	torch.name = "WallTorch"
	torch.mesh = TORCH
	torch.position = anchor
	torch.scale = Vector3.ONE * 0.6
	torch.rotation.y = side * PI / 2.0 # Native +Z bracket faces the wall.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.16, 0.07)
	material.roughness = 0.9
	torch.material_override = material
	add_child(torch)
	var flame := AnimatedSprite3D.new()
	flame.name = "TorchFlame"
	flame.sprite_frames = _flame_frames()
	flame.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	flame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flame.shaded = false
	flame.pixel_size = 0.012
	# Source origin (36,94) sits at the flame's base, rather than sheet center.
	flame.offset = Vector2(0, 34)
	flame.position = torch.transform * Vector3(0, 0.58, -0.05)
	add_child(flame)
	flame.play(&"burn")
	flame.frame = posmod(int(anchor.z) * 7, 60)
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	light.position = flame.position
	light.light_color = Color(1.0, 0.63, 0.27)
	light.light_energy = 1.0
	light.omni_range = 3.0
	light.shadow_enabled = false
	add_child(light)

static func _flame_frames() -> SpriteFrames:
	if torch_flame_frames == null:
		torch_flame_frames = SpriteFrames.new()
		torch_flame_frames.remove_animation(&"default")
		torch_flame_frames.add_animation(&"burn")
		torch_flame_frames.set_animation_speed(&"burn", 30.0)
		torch_flame_frames.set_animation_loop(&"burn", true)
		for frame in range(60):
			var texture := AtlasTexture.new()
			texture.atlas = TORCH_FLAME
			texture.region = Rect2i((frame % 10) * 72, (frame / 10) * 120, 72, 120)
			torch_flame_frames.add_frame(&"burn", texture)
	return torch_flame_frames
