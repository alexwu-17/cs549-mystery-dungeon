shader_type spatial;
render_mode diffuse_burley;
// Distant out-of-bounds ridges: rock on slopes, spring grass on level faces,
// sparse blossom speckles. Rendering only; fog_shade follows the border palette.

uniform vec3 rock_color : source_color = vec3(0.56, 0.51, 0.47);
uniform vec3 grass_color : source_color = vec3(0.44, 0.68, 0.36);
uniform vec3 blossom_color : source_color = vec3(0.90, 0.70, 0.78);
uniform vec3 fog_shade : source_color = vec3(1.0, 1.0, 1.0);
uniform float grass_slope_start = 0.25;
uniform float grass_slope_end = 0.65;
uniform float blossom_amount : hint_range(0.0, 1.0) = 0.14;
uniform float height_lift : hint_range(0.0, 1.0) = 0.25;
varying vec3 world_position;
varying vec3 world_normal;
varying float local_height;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_height = clamp(VERTEX.y / 1.9, 0.0, 1.0);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float grass = smoothstep(grass_slope_start, grass_slope_end, n.y);
	vec3 color = mix(rock_color, grass_color, grass);
	// Coordinate-hashed speckles: deterministic, independent of any gameplay RNG.
	float speck = hash21(floor(world_position.xz * 7.0) + floor(world_position.y * 3.0));
	float blossom = step(1.0 - blossom_amount, speck) * grass;
	color = mix(color, blossom_color, blossom * 0.85);
	color *= 1.0 + height_lift * local_height;
	ALBEDO = color * fog_shade;
	ROUGHNESS = 0.94;
	SPECULAR = 0.2;
}
