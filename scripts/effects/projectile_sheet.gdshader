shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D sheet_texture : source_color, filter_nearest, repeat_disable;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;
uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 grid = vec2(6.0, 8.0);
	vec2 cell = floor(UV * grid);
	vec2 local_uv = fract(UV * grid);
	float next_frame = min(cell.y * 6.0 + cell.x + 1.0, 47.0);
	vec2 next_cell = vec2(mod(next_frame, 6.0), floor(next_frame / 6.0));
	vec4 current = texture(sheet_texture, UV);
	vec4 next = texture(sheet_texture, (next_cell + local_uv) / grid);
	float alpha = mix(current.a, next.a, frame_blend);
	vec3 color = mix(current.rgb * current.a, next.rgb * next.a, frame_blend);
	ALBEDO = color / max(alpha, 0.00001);
	ALPHA = alpha * fade_amount;
}
