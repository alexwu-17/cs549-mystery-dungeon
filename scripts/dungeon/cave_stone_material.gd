class_name CaveStoneMaterial
extends RefCounted
## One repeatable, neutral stone texture for all floors/chunks. No gameplay RNG.
static var texture: ImageTexture
static var normal_texture: ImageTexture
static var roughness_texture: ImageTexture

static func detail() -> ImageTexture:
	if texture == null:
		var heights := authored_heights()
		# Make only the outer four texels periodic; retain sharp interior relief.
		for edge in range(4):
			var blend := 0.5*(1.0-float(edge)/4.0)
			for index in range(128):
				var a := index*128+edge
				var b := index*128+127-edge
				var original := heights[a]
				heights[a] = lerpf(original,heights[b],blend)
				heights[b] = lerpf(heights[b],original,blend)
				a = edge*128+index
				b = (127-edge)*128+index
				original = heights[a]
				heights[a] = lerpf(original,heights[b],blend)
				heights[b] = lerpf(heights[b],original,blend)
		var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
		# Recover the cracks/chips previously carried by the authored FLOOR mesh.
		# This bakes once, without editing its OBJ or adding per-cell geometry.
		for y in range(128):
			for x in range(128):
				var u := TAU * x / 128.0
				var v := TAU * y / 128.0
				var broad := sin(u * 2.0 + sin(v * 3.0) * 0.7) * cos(v * 2.0 + sin(u))
				var fine := sin(u * 11.0 + sin(v * 7.0)) * cos(v * 13.0 + sin(u * 5.0))
				var depth := clampf((ModularDungeonVisuals.FLOOR_TOP-heights[y*128+x])/0.16,0.0,1.0)
				var value := 0.98-depth*0.62 + broad*0.035 + fine*0.018
				image.set_pixel(x, y, Color(value, value, value, 1))
		var bump := image.duplicate()
		bump.bump_map_to_normal_map(2.0)
		bump.generate_mipmaps()
		normal_texture = ImageTexture.create_from_image(bump)
		var rough := Image.create(128,128,false,Image.FORMAT_L8)
		for y in range(128):
			for x in range(128):
				var value := 0.9+image.get_pixel(x,y).r*0.08
				rough.set_pixel(x,y,Color(value,value,value))
		rough.generate_mipmaps()
		roughness_texture = ImageTexture.create_from_image(rough)
		image.generate_mipmaps()
		texture = ImageTexture.create_from_image(image)
	return texture

static func authored_heights() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(128*128)
	var bounds := ModularDungeonVisuals.FLOOR.get_aabb()
	result.fill(bounds.position.y)
	var faces := ModularDungeonVisuals.FLOOR.get_faces()
	for i in range(0,faces.size(),3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i+1]
		var c: Vector3 = faces[i+2]
		var denominator := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(denominator) < 0.000001: continue
		# Crop the outer model rim, which would otherwise bake a tiled grid line.
		var start := bounds.position+Vector3(bounds.size.x*0.06,0,bounds.size.z*0.06)
		var span := bounds.size*0.88
		var min_x := clampi(floori((minf(a.x,minf(b.x,c.x))-start.x)/span.x*128),0,127)
		var max_x := clampi(ceili((maxf(a.x,maxf(b.x,c.x))-start.x)/span.x*128),0,127)
		var min_y := clampi(floori((minf(a.z,minf(b.z,c.z))-start.z)/span.z*128),0,127)
		var max_y := clampi(ceili((maxf(a.z,maxf(b.z,c.z))-start.z)/span.z*128),0,127)
		for y in range(min_y,max_y+1):
			for x in range(min_x,max_x+1):
				var px := start.x+span.x*(x+0.5)/128.0
				var pz := start.z+span.z*(y+0.5)/128.0
				var u := ((b.z-c.z)*(px-c.x)+(c.x-b.x)*(pz-c.z))/denominator
				var v := ((c.z-a.z)*(px-c.x)+(a.x-c.x)*(pz-c.z))/denominator
				if u < -0.00001 or v < -0.00001 or u+v > 1.00001: continue
				result[y*128+x] = maxf(result[y*128+x],u*a.y+v*b.y+(1.0-u-v)*c.y)
	return result

static func configure(material: StandardMaterial3D) -> void:
	material.albedo_texture = detail()
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.6
	material.uv1_triplanar_sharpness = 4.0
	material.roughness = 0.92
	material.roughness_texture = roughness_texture
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.normal_enabled = true
	material.normal_texture = normal_texture
	material.normal_scale = 0.3
