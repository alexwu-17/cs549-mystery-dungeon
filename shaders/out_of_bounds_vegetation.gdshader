shader_type spatial;
render_mode diffuse_burley;
// Out-of-bounds trees and bushes. Canopies take their per-instance MultiMesh
// color (spring greens or blossom pink, uploaded in linear space); trunks use
// base_color. fog_shade follows the same lifted border palette as the ridges.

uniform bool use_instance_color = true;
uniform vec3 base_color : source_color = vec3(0.42, 0.29, 0.20);
uniform vec3 fog_shade : source_color = vec3(1.0, 1.0, 1.0);
uniform float top_light : hint_range(0.0, 1.0) = 0.18;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 color = use_instance_color ? COLOR.rgb : base_color;
	// Sky-facing leaves read slightly brighter, as in the soft HD-2D look.
	color *= 1.0 + top_light * max(normalize(world_normal).y, 0.0);
	ALBEDO = color * fog_shade;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
