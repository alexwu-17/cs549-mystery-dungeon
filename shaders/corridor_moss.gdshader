shader_type spatial;
// FloorDetailOverlays: patchy green moss on corridor floors.
// Multiply blend only darkens, so lighting and fog remain owned by the floor.
// Patterns depend on world position only (no gameplay or generator RNG).
// UV.y = 0 at a corner touching a non-walkable side, 1 otherwise.
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float coverage = 0.45;
uniform float strength = 0.8;
uniform vec3 moss_color : source_color = vec3(0.45, 0.76, 0.48);
uniform vec3 deep_color : source_color = vec3(0.28, 0.55, 0.32);
varying vec3 world_position;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.55 + vnoise(p * 2.3 + 7.1) * 0.3 + vnoise(p * 5.1 + 3.3) * 0.15; }

void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	// Moss gathers toward corridor edges.
	float n = fbm(world_position.xz * 1.6) + (1.0 - UV.y) * 0.35;
	float patch_mask = smoothstep(1.0 - coverage, 1.0 - coverage + 0.18, n);
	// Small clumps so it reads as moss, not paint.
	float clump = 0.75 + 0.5 * vnoise(world_position.xz * 14.0);
	vec3 tint = mix(moss_color, deep_color, smoothstep(0.6, 1.0, n));
	ALBEDO = mix(vec3(1.0), tint, clamp(patch_mask * clump, 0.0, 1.0) * strength);
}
