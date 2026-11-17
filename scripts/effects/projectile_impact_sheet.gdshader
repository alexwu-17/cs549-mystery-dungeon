shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D sheet_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_grid = vec2(6.0, 8.0);
uniform float horizontal_scale = 1.0;
uniform float last_frame = 47.0;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;
uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;

// Keep the feedback camera-facing even with a custom material override.
void vertex() {
    VERTEX.x *= horizontal_scale;
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 grid = atlas_grid;
	vec2 cell = floor(UV * grid);
	vec2 local_uv = fract(UV * grid);
	float next_frame = min(cell.y * grid.x + cell.x + 1.0, last_frame);
	vec2 next_cell = vec2(mod(next_frame, grid.x), floor(next_frame / grid.x));
	vec4 current = texture(sheet_texture, UV);
	vec4 next = texture(sheet_texture, (next_cell + local_uv) / grid);
	float alpha = mix(current.a, next.a, frame_blend);
	vec3 color = mix(current.rgb * current.a, next.rgb * next.a, frame_blend);
	ALBEDO = color / max(alpha, 0.00001);
	ALPHA = alpha * fade_amount;
}
