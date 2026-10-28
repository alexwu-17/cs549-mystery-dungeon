shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D coverage_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size;
uniform vec3 mist_color : source_color = vec3(0.65,0.70,0.73);
// 50% stronger than Checkpoint 2 (0.085); animation is independent of turns.
uniform float opacity = 0.1275;
// Negative uses engine time; nonnegative values allow isolated render checks.
uniform float preview_time = -1.0;
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
 float mist_time = preview_time < 0.0 ? TIME : preview_time;
 // Both noise scales travel together: opposing flows previously dissolved
 // into one another instead of reading as a moving bank of mist.
 vec2 advected = world_position.xz-vec2(0.24,0.09)*mist_time;
 float wisps=noise(advected*0.6)*0.65+noise(advected*1.5)*0.35;
 ALBEDO=mist_color;
 ALPHA=opacity*smoothstep(0.22,0.8,wisps)*soft*coverage*COLOR.a;
}
