shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 beam_color : source_color = vec3(1.0,0.98,0.95);
uniform float intensity = 1.6;
uniform float opacity = 0.16;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float depth = texture(scene_depth,SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0);
	view /= view.w;
	float fragment_depth = -(VIEW_MATRIX*vec4(world_position,1.0)).z;
	float intersection = clamp((-view.z-fragment_depth)/0.45,0.0,1.0);
	// The room gates activation on the CPU. Airborne glow may cross a dark
	// background without changing its fog material or revealing hidden actors.
	float x = abs(UV.x*2.0-1.0);
	float feather = pow(max(0.0,1.0-x*x),2.5);
	float ends = smoothstep(0.0,0.16,UV.y)*(1.0-smoothstep(0.75,1.0,UV.y));
	float streak = 0.78+0.22*cos(UV.x*17.0+UV.y*0.5);
	ALBEDO = beam_color*intensity;
	ALPHA = opacity*feather*ends*streak*intersection*COLOR.a;
}
