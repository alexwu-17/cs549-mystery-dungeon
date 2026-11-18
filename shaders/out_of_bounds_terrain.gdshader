shader_type spatial;
render_mode diffuse_burley;
// Placeholder shading for the out-of-bounds terrain: one muted ground color,
// shifted toward a darker rock tone on steep slopes. The real shading pass is
// planned separately. fog_shade follows the lifted border fog palette.

uniform vec3 ground_color : source_color = vec3(0.52, 0.58, 0.46);
uniform vec3 slope_color : source_color = vec3(0.42, 0.41, 0.39);
uniform vec3 fog_shade : source_color = vec3(1.0, 1.0, 1.0);
uniform float slope_start = 0.55;
uniform float slope_end = 0.85;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float level = smoothstep(slope_start, slope_end, normalize(world_normal).y);
	ALBEDO = mix(slope_color, ground_color, level) * fog_shade;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
