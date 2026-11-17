shader_type canvas_item;
render_mode unshaded;
uniform vec2 frame_grid = vec2(4.0, 7.0);
uniform float frame_index = 0.0;
uniform vec2 uv_scale = vec2(1.0);

void fragment() {
	vec2 cell = vec2(mod(frame_index, frame_grid.x), floor(frame_index / frame_grid.x));
	vec2 pixel = min(floor(clamp((UV - 0.5) * uv_scale + 0.5,vec2(0.0),vec2(1.0)) * vec2(320.0,180.0)), vec2(319.0,179.0));
	COLOR = texture(TEXTURE, (cell + (pixel + 0.5) / vec2(320.0,180.0)) / frame_grid);
}
