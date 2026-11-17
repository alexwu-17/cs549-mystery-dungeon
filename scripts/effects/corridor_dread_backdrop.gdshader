shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D sky_sheet : source_color, filter_nearest, repeat_disable;

uniform sampler2D eclipse_sheet : source_color, filter_nearest, repeat_disable;
uniform vec2 eclipse_center = vec2(0.5, 0.2);

uniform float reference_fov_degrees = 65.0;

uniform float zoom_out : hint_range(1.0, 8.0) = 3.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.000001, 1.0);
}

void fragment() {
	// Reconstruct this pixel's world-space view ray. The corridor sky faces
	// world -Z, so pitching the camera changes which part of the sky is seen.
	// Translation is ignored: the sky is infinitely distant.
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec4 view_point = INV_PROJECTION_MATRIX * vec4(ndc, 1.0, 1.0);
	vec3 world_ray = mat3(INV_VIEW_MATRIX) * (view_point.xyz / view_point.w);
	float reference_half_height = tan(radians(reference_fov_degrees) * 0.5);
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 projected = world_ray.xy / max(-world_ray.z, 0.0001);
	vec2 world_uv = vec2(0.5 + projected.x / (2.0 * reference_half_height * aspect),
		0.5 - projected.y / (2.0 * reference_half_height));
	float frame = mod(floor(TIME * 12.0), 144.0);
	vec2 cell = vec2(mod(frame, 9.0), floor(frame / 9.0));
	// Mirror-repeat within the current frame to widen the sky without seams
	// or sampling adjacent animation cells in the atlas.
	vec2 expanded_uv = (world_uv - 0.5) * zoom_out + 0.5;
	vec2 sky_uv = 1.0 - abs(mod(expanded_uv, 2.0) - 1.0);
	vec2 pixel = min(floor(sky_uv * vec2(320.0, 180.0)), vec2(319.0, 179.0));
	vec2 uv = (cell * vec2(320.0, 180.0) + pixel + 0.5) / vec2(2880.0, 2880.0);
	vec3 sky_color = texture(sky_sheet, uv).rgb;
	// One Eclipse centered in the visible sky above the corridor horizon.
	// Keep its aspect ratio circular and independent of mirrored sky zoom.
	vec2 eclipse_size = vec2(0.22, 0.22 * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y * 0.9);
	vec2 eclipse_uv = (world_uv - eclipse_center) / eclipse_size + 0.5;
	if (all(greaterThanEqual(eclipse_uv, vec2(0.0))) && all(lessThanEqual(eclipse_uv, vec2(1.0)))) {
		float eclipse_frame = mod(floor(TIME * 12.0), 48.0);
		vec2 eclipse_cell = vec2(mod(eclipse_frame, 7.0), floor(eclipse_frame / 7.0));
		vec2 eclipse_pixel = min(floor(eclipse_uv * vec2(160.0, 144.0)), vec2(159.0, 143.0));
		vec2 eclipse_atlas_uv = (eclipse_cell * vec2(160.0, 144.0) + eclipse_pixel + 0.5) / vec2(1120.0, 1008.0);
		vec4 eclipse = texture(eclipse_sheet, eclipse_atlas_uv);
		sky_color = mix(sky_color, eclipse.rgb, eclipse.a);
	}
	ALBEDO = sky_color;
}
