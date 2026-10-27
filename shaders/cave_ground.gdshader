shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D fog_palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D stone_detail : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 palette_origin;
uniform vec2 palette_size;
uniform bool stone_enabled = true;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 ground_position;
varying vec3 ground_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	ground_position = VERTEX;
	ground_normal = NORMAL;
}

void fragment() {
	// A small inward bias chooses the owning column on vertical boundary faces.
	vec2 cell = floor(ground_position.xz - ground_normal.xz * 0.001 + vec2(0.5));
	vec2 palette_uv = (cell - palette_origin + vec2(0.5)) / palette_size;
	vec4 palette_color = texture(fog_palette, palette_uv);
	vec3 color = palette_color.rgb;
	color *= mix(1.0, palette_color.a * 2.0, abs(normalize(world_normal).y));
	float grain = 1.0;
	if (stone_enabled) {
		vec3 weights = pow(abs(normalize(world_normal)), vec3(4.0));
		weights /= max(dot(weights, vec3(1.0)), 0.0001);
		vec3 p = world_position * 0.6;
		grain = texture(stone_detail, p.zy).r * weights.x
			+ texture(stone_detail, p.xz).r * weights.y
			+ texture(stone_detail, p.xy).r * weights.z;
	}
	ALBEDO = color * grain;
	ROUGHNESS = clamp(0.92 * grain, 0.78, 1.0);
	if (stone_enabled) {
		// Relief from the same sampled stone signal: no additional texture reads.
		vec3 n = normalize(world_normal);
		vec3 dx = dFdx(world_position);
		vec3 dy = dFdy(world_position);
		vec3 r1 = cross(dy,n);
		vec3 r2 = cross(n,dx);
		float determinant = dot(dx,r1);
		vec3 gradient = sign(determinant) * (dFdx(grain)*r1+dFdy(grain)*r2);
		vec3 bumped = normalize(abs(determinant)*n-gradient*0.035);
		NORMAL = normalize((VIEW_MATRIX*vec4(bumped,0.0)).xyz);
	}
}
