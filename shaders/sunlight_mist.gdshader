shader_type fog;
uniform sampler2D bright_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size;
uniform vec3 beam_start;
uniform vec3 beam_direction;
uniform vec3 beam_receiver;
uniform float beam_length = 6.0;
uniform float beam_width = 1.6;
uniform float density = 0.035;
uniform vec3 mist_color : source_color = vec3(1.0,0.98,0.93);
void fog() {
	vec3 relative = WORLD_POSITION-beam_start;
	float along = dot(relative,beam_direction);
	float t = along/beam_length;
	float radius = beam_width*mix(0.3,0.65,clamp(t,0.0,1.0));
	float distance = length(relative-beam_direction*along);
	float profile = 1.0-smoothstep(radius*0.35,radius,distance);
	float ends = smoothstep(0.0,0.12,t)*(1.0-smoothstep(0.82,1.0,t));
	// Gate the shaft by its receiver, not by the unrelated ground beneath its
	// high end. Otherwise a valid diagonal ray is chopped at room boundaries.
	float travel = max(0.0,(beam_receiver.y-WORLD_POSITION.y)/min(beam_direction.y,-0.01));
	vec3 receiver_point = WORLD_POSITION+beam_direction*travel;
	vec2 uv = (receiver_point.xz-mask_origin+vec2(0.5))/mask_size;
	float bright = texture(bright_mask,uv).r;
	float variation = 0.9+0.1*sin(dot(WORLD_POSITION,vec3(1.7,0.8,1.1)));
	DENSITY = density*profile*ends*bright*variation;
	ALBEDO = mist_color;
}
