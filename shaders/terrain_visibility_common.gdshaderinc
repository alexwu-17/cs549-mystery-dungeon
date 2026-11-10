uniform vec3 bright_color = vec3(1.0);
uniform vec3 shadow_color = vec3(0.04);
uniform bool rounded_light = false;
uniform vec2 visibility_center;
uniform float visibility_height = 0.6;
uniform float visibility_ground = 0.0;
uniform float wall_opacity = 0.2;
uniform float roughness_value = 1.0;
uniform float specular_value = 0.5;
uniform float metallic_value = 0.0;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap, repeat_enable;
uniform bool use_roughness = false;
uniform vec3 roughness_channel = vec3(1.0,0.0,0.0);
uniform bool use_texture = false;
uniform bool use_normal = false;
uniform bool triplanar = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float normal_strength = 1.0;
uniform float triplanar_sharpness = 4.0;
uniform bool warmup = false;
varying vec3 visibility_world;
varying vec3 visibility_normal;
void vertex() {
 visibility_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 visibility_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 sample_surface(sampler2D map, vec2 surface_uv) {
 if (!triplanar) { return texture(map, surface_uv * uv_scale.xy + uv_offset.xy).rgb; }
 vec3 weights = pow(abs(normalize(visibility_normal)), vec3(triplanar_sharpness));
 weights /= max(dot(weights, vec3(1.0)), 0.0001);
 vec3 p = visibility_world * uv_scale + uv_offset;
 return texture(map, p.zy).rgb * weights.x + texture(map, p.xz).rgb * weights.y + texture(map, p.xy).rgb * weights.z;
}
vec3 surface_color(vec2 surface_uv) {
 float coverage = rounded_light ? 1.0 - smoothstep(1.30, 1.50, distance(visibility_world.xz, visibility_center)) : 1.0;
 vec3 color = mix(shadow_color, bright_color, coverage);
 return use_texture ? color * sample_surface(surface_texture, surface_uv) : color;
}
