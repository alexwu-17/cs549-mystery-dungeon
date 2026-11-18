class_name RockTextureSet
extends RefCounted
## Procedural rock detail for the out-of-bounds terrain, built once per session
## (about 0.3 s) and shared by every floor. Each array layer packs a tangent normal (RG), height (B) and
## albedo variation (A). Layer 0 reuses the authored cave stone grain.

const SIZE := 256
const LAYERS := 3
static var layers: Texture2DArray
static var macro: ImageTexture


static func ensure() -> void:
	if layers != null: return
	var heights: Array[PackedFloat32Array] = [_authored(), _cracks(), _grit()]
	var images: Array[Image] = []
	for index in range(LAYERS):
		images.append(_pack(heights[index], [2.5, 4.0, 1.5][index]))
	layers = Texture2DArray.new()
	layers.create_from_images(images)
	macro = ImageTexture.create_from_image(_macro())


static func _noise_heights(noise: FastNoiseLite) -> PackedFloat32Array:
	var image := noise.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	var result := PackedFloat32Array()
	result.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			result[y * SIZE + x] = image.get_pixel(x, y).r
	return result


static func _authored() -> PackedFloat32Array:
	var image: Image = CaveStoneMaterial.detail().get_image().duplicate()
	image.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	var result := PackedFloat32Array()
	result.resize(SIZE * SIZE)
	var low := INF
	var high := -INF
	for y in range(SIZE):
		for x in range(SIZE):
			var value := image.get_pixel(x, y).r
			result[y * SIZE + x] = value
			low = minf(low, value)
			high = maxf(high, value)
	for index in range(result.size()): result[index] = (result[index] - low) / maxf(0.0001, high - low)
	return result


static func _cracks() -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = 4127
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	var result := _noise_heights(noise)
	# Thin dark crack lines between raised plates.
	for index in range(result.size()): result[index] = smoothstep(0.02, 0.22, result[index])
	return result


static func _grit() -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = 9311
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.frequency = 0.03
	return _noise_heights(noise)


static func _pack(heights: PackedFloat32Array, strength: float) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var left := heights[y * SIZE + posmod(x - 1, SIZE)]
			var right := heights[y * SIZE + posmod(x + 1, SIZE)]
			var up := heights[posmod(y - 1, SIZE) * SIZE + x]
			var down := heights[posmod(y + 1, SIZE) * SIZE + x]
			var normal := Vector3((left - right) * strength, (up - down) * strength, 1.0).normalized()
			var height := heights[y * SIZE + x]
			image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, height, 0.75 + 0.5 * height * height))
	image.generate_mipmaps()
	return image


static func _macro() -> Image:
	var first := FastNoiseLite.new()
	first.seed = 1777
	first.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	first.fractal_octaves = 3
	first.frequency = 0.012
	var second := first.duplicate() as FastNoiseLite
	second.seed = 5003
	second.frequency = 0.02
	var a := first.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	var b := second.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			image.set_pixel(x, y, Color(a.get_pixel(x, y).r, b.get_pixel(x, y).r, 0.0, 1.0))
	image.generate_mipmaps()
	return image
