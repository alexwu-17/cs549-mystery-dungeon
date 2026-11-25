shader_type spatial;
render_mode cull_disabled;
// Procedural grass tufts (GrassClump). Vertex color is the blade's root-to-tip
// gradient (sRGB) times the per-tuft MultiMesh tint. Both faces use the tuft's
// up axis (tilted with the slope) as their normal, so blades take the same light
// as the ground below. `shade` follows the terrain's fog shade.

uniform vec3 shade : source_color = vec3(1.0);
varying vec3 tint;
varying vec3 up_world;

void vertex() {
	tint = COLOR.rgb;
	up_world = MODEL_NORMAL_MATRIX * vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = pow(max(tint, vec3(0.0)), vec3(2.2)) * shade;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	NORMAL = normalize((VIEW_MATRIX * vec4(up_world, 0.0)).xyz);
}
