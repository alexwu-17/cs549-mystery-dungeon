shader_type spatial;
// FloorDetailOverlays: soft grime band where room floors meet walls.
// Multiply blend only darkens, so lighting and fog remain owned by the floor.
// UV.x = world distance along the wall (seamless across tiles);
// UV.y = 0 at the wall face -> 1 at the band's inner end.
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float strength = 0.9;
uniform vec3 grime_color : source_color = vec3(0.22, 0.18, 0.15);

float hash1(float n) { return fract(sin(n) * 43758.5453); }
float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), f);
}
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// Ragged inner edge: reach varies smoothly along the wall.
	float reach = 0.55 + 0.45 * (0.6 * noise1(UV.x * 2.3) + 0.4 * noise1(UV.x * 7.1 + 13.0));
	float fade = clamp(1.0 - UV.y / reach, 0.0, 1.0);
	fade = fade * fade * (3.0 - 2.0 * fade);
	// Fine speckle so it reads as dirt rather than a smooth gradient.
	float speck = 0.8 + 0.4 * hash2(floor(UV * 24.0));
	ALBEDO = mix(vec3(1.0), grime_color, clamp(fade * speck, 0.0, 1.0) * strength);
}
