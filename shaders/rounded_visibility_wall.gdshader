shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;
uniform vec2 visibility_center;
uniform float visibility_height = 0.6;
uniform vec3 wall_color : source_color;
uniform float wall_opacity = 0.2;
uniform float roughness_value = 1.0;
uniform sampler2D wall_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
varying vec3 visibility_world;
void vertex() { visibility_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Project the occluding surface onto the player's body plane along the view.
	// A wall farther toward the camera must still open over the player's sprite.
	vec3 ray = visibility_world - CAMERA_POSITION_WORLD;
	float scale = (visibility_height - CAMERA_POSITION_WORLD.y) / min(ray.y, -0.0001);
	vec2 projected = (CAMERA_POSITION_WORLD + ray * scale).xz;
	float coverage = 1.0 - smoothstep(1.30, 1.50, distance(projected, visibility_center));
	ALBEDO = wall_color * (use_texture ? texture(wall_texture, UV).rgb : vec3(1.0));
	ROUGHNESS = roughness_value;
	ALPHA = mix(1.0, wall_opacity, coverage);
}
