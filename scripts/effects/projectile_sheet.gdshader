shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D sheet_texture : source_color, filter_nearest, repeat_disable;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;
uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;

uniform float cutoff_x : hint_range(0.0, 1.0) = 1.0;

uniform vec2 atlas_grid = vec2(6.0,8.0);
uniform float last_frame = 47.0;

uniform bool camera_facing = false;
uniform bool stable_atlas = false;
uniform float source_frame = 0.0;
void vertex() {
	if (camera_facing) {
		// A true camera-plane billboard, including pitch, for a circular orb.
		// Other projectile materials retain their existing world/lane orientation.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 grid = atlas_grid;
	vec2 cell = floor(UV * grid);
	vec2 local_uv = fract(UV * grid);
	float current_frame = stable_atlas ? floor(source_frame) : cell.y * grid.x + cell.x;
	// Bias integer row boundaries against GPU reciprocal rounding (e.g. 7/7).
	float current_row = floor((current_frame + 0.5) / grid.x);
	vec2 current_cell = vec2(current_frame - current_row * grid.x, current_row);
	float next_frame = min(current_frame + 1.0, last_frame);
	float next_row = floor((next_frame + 0.5) / grid.x);
	vec2 next_cell = vec2(next_frame - next_row * grid.x, next_row);
	vec4 current = texture(sheet_texture, stable_atlas ? (current_cell + local_uv) / grid : UV);
	vec4 next = texture(sheet_texture, (next_cell + local_uv) / grid);
	float alpha = mix(current.a, next.a, frame_blend);
	vec3 color = mix(current.rgb * current.a, next.rgb * next.a, frame_blend);
	ALBEDO = color / max(alpha, 0.00001);
	ALPHA = alpha * fade_amount * step(local_uv.x, cutoff_x);
}
