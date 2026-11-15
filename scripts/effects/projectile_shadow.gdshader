shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D sheet_texture : source_color, filter_nearest, repeat_disable;
uniform float frame_index = 0.0;
uniform float frame_blend = 0.0;
uniform float fade_amount = 1.0;
uniform float darkness = 0.35;
uniform bool hollow = false;

void fragment() {
	vec2 grid = vec2(6.0, 8.0);
	float next_frame = min(frame_index + 1.0, 47.0);
	vec2 cell = vec2(mod(frame_index, 6.0), floor(frame_index / 6.0));
	vec2 next_cell = vec2(mod(next_frame, 6.0), floor(next_frame / 6.0));
	// Ignore the translucent water body, retaining the darker opaque rim.
	float current = texture(sheet_texture, (cell + UV) / grid).a;
	float next = texture(sheet_texture, (next_cell + UV) / grid).a;
	if (hollow) {
		current = smoothstep(0.45, 0.85, current);
		next = smoothstep(0.45, 0.85, next);
	}
	ALBEDO = vec3(0.0);
	ALPHA = mix(current, next, frame_blend) * darkness * fade_amount;
}
