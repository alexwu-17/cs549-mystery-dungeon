shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_prepass_alpha;
#include "res://shaders/terrain_visibility_common.gdshaderinc"
void fragment() {
 vec3 ray = visibility_world - CAMERA_POSITION_WORLD;
 float scale = (visibility_height - CAMERA_POSITION_WORLD.y) / min(ray.y, -0.0001);
 vec2 projected = (CAMERA_POSITION_WORLD + ray * scale).xz;
 float coverage = 1.0 - smoothstep(1.30, 1.50, distance(projected, visibility_center));
 // Retain the supporting tread/floor below the feet while opening the body view.
 coverage *= smoothstep(visibility_ground - 0.02, visibility_ground + 0.06, visibility_world.y);
 ALBEDO = surface_color(UV);
 ROUGHNESS = roughness_value * (use_roughness ? dot(sample_surface(roughness_texture, UV), roughness_channel) : 1.0);
 SPECULAR = specular_value;
 METALLIC = metallic_value;
 if (use_normal && triplanar && use_texture) {
  float grain = sample_surface(surface_texture, UV).r;
  vec3 n = normalize(visibility_normal);
  vec3 dx = dFdx(visibility_world);
  vec3 dy = dFdy(visibility_world);
  vec3 r1 = cross(dy,n);
  vec3 r2 = cross(n,dx);
  float determinant = dot(dx,r1);
  vec3 gradient = sign(determinant) * (dFdx(grain)*r1+dFdy(grain)*r2);
  vec3 bumped = normalize(abs(determinant)*n-gradient*normal_strength*0.117);
  NORMAL = normalize((VIEW_MATRIX*vec4(bumped,0.0)).xyz);
 }
 if (use_normal && !triplanar) {
  NORMAL_MAP = texture(normal_texture, UV * uv_scale.xy + uv_offset.xy).rgb;
  NORMAL_MAP_DEPTH = normal_strength;
 }
 ALPHA = warmup ? 0.0 : mix(1.0, wall_opacity, coverage);
}
