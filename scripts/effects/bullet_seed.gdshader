shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float progress = 0.0;
uniform bool impact = false;
uniform float release_edge = 0.88;

void vertex() {
	if (impact) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = UV;
	float core = 0.0;
	float glow = 0.0;
	if (!impact) {
		// Five round seeds with luminous wakes; no leaf or thorn silhouettes.
		for (int i = 0; i < 5; i++) {
			float n = float(i);
			vec2 center = vec2(0.88 - n * 0.145, 0.5 + sin(n * 2.4) * 0.07);
			vec2 delta = p - center;
			float d = length(delta);
			core += 1.0 - smoothstep(0.025, 0.042, d);
			glow += exp(-d * d * 650.0) * 0.6;
			float wake = clamp(-delta.x / 0.18, 0.0, 1.0);
			glow += step(delta.x, 0.0) * (1.0 - smoothstep(0.0, 0.20, -delta.x)) * exp(-pow(delta.y / (0.009 + wake * 0.018), 2.0)) * 0.75;
		}
	} else {
		// Deterministic sparks distributed over the body, expanding outwards.
		for (int i = 0; i < 24; i++) {
			float n = float(i);
			float angle = n * 2.399963;
			vec2 ray = vec2(cos(angle), sin(angle));
			vec2 origin = vec2(0.5) + ray * (0.04 + fract(n * 0.37) * 0.15);
			vec2 delta = p - origin - ray * progress * (0.15 + fract(n * 0.61) * 0.22);
			float along = dot(delta, ray);
			float across = dot(delta, vec2(-ray.y, ray.x));
			float d = length(vec2(along * 0.45, across));
			core += (1.0 - smoothstep(0.004, 0.012, d));
			glow += exp(-d * d * 2200.0) * 0.7;
		}
	}
	float fade = impact ? 1.0 - smoothstep(0.4, 1.0, progress) : 1.0;
	vec3 green = mix(vec3(0.15, 1.0, 0.015), vec3(0.78, 1.0, 0.38), clamp(core, 0.0, 1.0));
	ALBEDO = green;
	EMISSION = green * (1.0 + core * 1.5);
	ALPHA = clamp(core + glow, 0.0, 1.0) * fade;
	if (!impact) ALPHA *= smoothstep(release_edge - 0.005, release_edge + 0.005, p.x);
}
