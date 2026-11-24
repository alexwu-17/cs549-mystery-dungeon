shader_type spatial;
render_mode diffuse_burley;
// Realistic grey rock without visible tiling, for the out-of-bounds lowland.
// - Texture array: three rock detail layers (authored grain, cracks, grit),
//   each packing a tangent normal (RG), height (B) and albedo variation (A).
// - Randomized sampling: hex/triangle-grid stochastic tiling; every lattice
//   vertex gets a random offset and rotation, three samples blend per layer.
// - Layer blending: slope/macro-weighted, sharpened by layer height.
// - Normal maps: triplanar, whiteout-blended into the surface normal.
// - Macro variation: very low-frequency colour/brightness/rust signals.

uniform sampler2DArray rock_layers : filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 fog_shade : source_color = vec3(1.0);
// Seasons (set per floor by OutOfBoundsFoliage). Summer paints meadow grass on
// gentle ground in patches of the macro noise; instances with COLOR.a = 0
// (stones) never take grass. Winter settles snow on upward-facing ground and
// stone tops.
uniform float grass_amount = 0.0;
uniform float grass_scale = 0.11;
uniform float meadow_low = 0.22;
uniform vec3 grass_color : source_color = vec3(0.34, 0.44, 0.21);
uniform vec3 grass_dry : source_color = vec3(0.47, 0.47, 0.28);
uniform float snow_amount = 0.0;
uniform vec3 snow_color : source_color = vec3(0.9, 0.92, 0.96);
uniform vec3 rock_warm : source_color = vec3(0.50, 0.47, 0.43);
uniform vec3 rock_cool : source_color = vec3(0.46, 0.47, 0.48);
uniform vec3 rock_dark : source_color = vec3(0.24, 0.23, 0.22);
uniform vec3 rock_rust : source_color = vec3(0.47, 0.37, 0.29);
uniform vec3 dust : source_color = vec3(0.63, 0.60, 0.55);
uniform float detail_scale = 0.32;
uniform float normal_strength = 0.9;
uniform float blend_sharpness = 4.0;
uniform float macro_scale = 0.045;
// World heights of the valley floor and the map rim; set by OutOfBoundsScenery.
uniform float height_low = -1.9;
uniform float height_high = 0.6;
varying vec3 world_position;
varying vec3 world_normal;
// Per-instance tint from MultiMesh colors (stones); white for the terrain itself.
varying vec4 instance_tint;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	instance_tint = COLOR;
}

vec2 hash22(vec2 p) {
	vec3 a = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	a += dot(a, a.yzx + 33.33);
	return fract((a.xx + a.yz) * a.zy);
}

// Stochastic triangle-grid tiling (Heitz & Neyret style, no histogram step).
// Returns the blended RGBA texel with its tangent normal already un-rotated.
vec4 sample_stochastic(vec2 uv, float layer) {
	vec2 duvx = dFdx(uv);
	vec2 duvy = dFdy(uv);
	vec2 scaled = uv * 3.4641016;
	vec2 skewed = mat2(vec2(1.0, -0.57735027), vec2(0.0, 1.15470054)) * scaled;
	vec2 base = floor(skewed);
	vec3 t = vec3(fract(skewed), 0.0);
	t.z = 1.0 - t.x - t.y;
	vec3 w;
	vec2 v1; vec2 v2; vec2 v3;
	if (t.z > 0.0) {
		w = vec3(t.z, t.y, t.x);
		v1 = base; v2 = base + vec2(0.0, 1.0); v3 = base + vec2(1.0, 0.0);
	} else {
		w = vec3(-t.z, 1.0 - t.y, 1.0 - t.x);
		v1 = base + vec2(1.0, 1.0); v2 = base + vec2(1.0, 0.0); v3 = base + vec2(0.0, 1.0);
	}
	vec4 result = vec4(0.0);
	vec3 weights = pow(w, vec3(blend_sharpness));
	float total = 0.0;
	vec2 vertices[3] = vec2[3](v1, v2, v3);
	for (int i = 0; i < 3; i++) {
		vec2 random = hash22(vertices[i]);
		float angle = random.x * 6.2831853;
		mat2 rotation = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		vec2 local = rotation * uv + random * 7.0;
		vec4 texel = textureGrad(rock_layers, vec3(local, layer), rotation * duvx, rotation * duvy);
		// Height-aware blend: raised texels win at the transitions.
		float weight = weights[i] * (0.35 + texel.b);
		vec2 n = texel.rg * 2.0 - 1.0;
		n = transpose(rotation) * n;
		result += vec4(n, texel.b, texel.a) * weight;
		total += weight;
	}
	return result / max(total, 0.0001);
}

// One plane: blend the three layers by the given weights.
vec4 sample_layers(vec2 uv, vec3 layer_weights) {
	vec4 grain = sample_stochastic(uv, 0.0);
	vec4 cracks = sample_stochastic(uv * 0.8 + 13.7, 1.0);
	vec4 grit = sample_stochastic(uv * 1.7 + 41.3, 2.0);
	// Sharpen the layer mix by height so layers overlap like real rock surfaces.
	vec3 heights = vec3(grain.b, cracks.b, grit.b) + layer_weights;
	float top = max(max(heights.x, heights.y), heights.z) - 0.25;
	vec3 mask = max(heights - top, vec3(0.0));
	mask /= max(mask.x + mask.y + mask.z, 0.0001);
	return grain * mask.x + cracks * mask.y + grit * mask.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 p = world_position * detail_scale;
	vec2 macro = texture(macro_noise, world_position.xz * macro_scale).rg;
	vec2 macro_fine = texture(macro_noise, world_position.zx * macro_scale * 4.3 + 0.37).rg;
	float steep = 1.0 - smoothstep(0.45, 0.85, n.y);
	// Cracks dominate steep faces, grit gathers on flatter ground; macro shifts both.
	vec3 layer_weights = vec3(0.5 + 0.2 * macro.x, 0.15 + 0.6 * steep * macro_fine.y, 0.25 + 0.5 * (1.0 - steep) * macro.y);
	vec3 blend = pow(abs(n), vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);
	vec4 sx = blend.x > 0.01 ? sample_layers(p.zy, layer_weights) : vec4(0.0, 0.0, 0.5, 1.0);
	vec4 sy = blend.y > 0.01 ? sample_layers(p.xz, layer_weights) : vec4(0.0, 0.0, 0.5, 1.0);
	vec4 sz = blend.z > 0.01 ? sample_layers(p.xy, layer_weights) : vec4(0.0, 0.0, 0.5, 1.0);
	float height = sx.b * blend.x + sy.b * blend.y + sz.b * blend.z;
	float variation = sx.a * blend.x + sy.a * blend.y + sz.a * blend.z;
	// Whiteout triplanar normal blending.
	vec3 tx = vec3(sx.rg * normal_strength, 1.0);
	vec3 ty = vec3(sy.rg * normal_strength, 1.0);
	vec3 tz = vec3(sz.rg * normal_strength, 1.0);
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 detailed = normalize(tx.zyx * blend.x + ty.xzy * blend.y + tz.xyz * blend.z);
	// Colour: warm/cool grey by macro, rust stains on steep faces, dirt in
	// crevices and valleys, dusty weathered crests.
	vec3 color = mix(rock_cool, rock_warm, smoothstep(0.3, 0.7, macro.x));
	color = mix(color, rock_rust, smoothstep(0.62, 0.85, macro_fine.x) * steep * 0.55);
	color *= variation;
	color = mix(rock_dark, color, smoothstep(0.08, 0.55, height));
	float elevation = smoothstep(height_low, height_high, world_position.y);
	color *= mix(0.68, 1.08, elevation);
	color = mix(color, dust, (1.0 - steep) * elevation * 0.35 * macro.y);
	color *= mix(0.9, 1.1, macro_fine.y);
	// Meadow: broad patches cut back to rock on steep faces, with a ragged,
	// noise-jittered slope edge and rock bumps poking through the grass.
	float meadow = smoothstep(meadow_low, meadow_low + 0.22, texture(macro_noise, world_position.xz * grass_scale + vec2(0.61, 0.13)).r);
	float jitter = (macro_fine.x - 0.5) * 0.2 + (macro.y - 0.5) * 0.12;
	float flat_ground = smoothstep(0.58 + jitter, 0.76 + jitter, world_normal.y);
	float grass = grass_amount * meadow * flat_ground * instance_tint.a;
	grass *= 1.0 - 0.7 * smoothstep(0.6, 0.9, height);
	color = mix(color, mix(grass_dry, grass_color, macro_fine.y) * mix(0.85, 1.1, height), grass);
	float snow = snow_amount * smoothstep(0.62, 0.9, detailed.y) * smoothstep(0.15, 0.55, macro_fine.x + 0.25 * macro.y);
	color = mix(color, snow_color, snow);
	ALBEDO = color * fog_shade * instance_tint.rgb;
	ROUGHNESS = mix(0.82, 0.97, height);
	SPECULAR = 0.25;
	NORMAL = normalize((VIEW_MATRIX * vec4(detailed, 0.0)).xyz);
}
