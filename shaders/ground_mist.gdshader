shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D coverage_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size;
uniform vec3 mist_color : source_color = vec3(0.65,0.70,0.73);
uniform float opacity = 0.085;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float depth=texture(scene_depth,SCREEN_UV).r;
 vec4 view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0); view/=view.w;
 vec3 behind=(INV_VIEW_MATRIX*view).xyz;
 float fragment_depth=-(VIEW_MATRIX*vec4(world_position,1.0)).z;
 float soft=clamp((-view.z-fragment_depth)/0.3,0.0,1.0);
 vec2 mask_uv=(behind.xz-mask_origin+vec2(0.5))/mask_size;
 float coverage=texture(coverage_mask,mask_uv).r;
 vec2 drift=vec2(TIME*0.022,TIME*0.013);
 float wisps=noise(world_position.xz*0.6+drift)*0.65+noise(world_position.xz*1.5-drift)*0.35;
 ALBEDO=mist_color;
 ALPHA=opacity*smoothstep(0.22,0.8,wisps)*soft*coverage*COLOR.a;
}
