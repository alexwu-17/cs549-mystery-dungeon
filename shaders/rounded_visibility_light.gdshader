shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled;
uniform vec2 visibility_center;
uniform vec3 dim_color = vec3(0.22);
varying vec3 visibility_world;
void vertex() { visibility_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float coverage = 1.0 - smoothstep(1.30, 1.50, distance(visibility_world.xz, visibility_center));
	ALBEDO = mix(dim_color, vec3(1.0), coverage);
}
