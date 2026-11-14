shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D fireball_texture : source_color, filter_nearest, repeat_disable;
uniform float trail_amount : hint_range(0.0, 1.0) = 0.0;
uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Sprite3D supplies atlas UVs for a 4x9 grid of 136x56 source frames.
	vec2 grid = vec2(4.0, 9.0);
	vec2 cell = floor(UV * grid);
	vec2 local_uv = fract(UV * grid);
	float next_frame = mod(cell.y * 4.0 + cell.x + 1.0, 36.0);
	vec2 next_cell = vec2(mod(next_frame, 4.0), floor(next_frame / 4.0));
	vec4 current = texture(fireball_texture, UV);
	vec4 next = texture(fireball_texture, (next_cell + local_uv) / grid);
	// Blend premultiplied colors so transparent pixels do not darken the edges.
	float alpha = mix(current.a, next.a, frame_blend);
	vec3 color = mix(current.rgb * current.a, next.rgb * next.a, frame_blend);
	vec2 pixel = local_uv * vec2(136.0, 56.0);
	vec2 head = pixel - vec2(112.0, 28.0);
	// A single connected silhouette grows out of the ball. Stretch only its
	// rear half, keeping the head anchored and the tail tip softly tapered.
	float rear_stretch = mix(1.0, 5.0, trail_amount);
	vec2 shape = vec2(head.x / (head.x < 0.0 ? rear_stretch : 1.0), head.y);
	float silhouette = 1.0 - smoothstep(8.0, 11.0, length(shape));
	ALBEDO = color / max(alpha, 0.00001);
	ALPHA = alpha * silhouette * fade_amount;
}
