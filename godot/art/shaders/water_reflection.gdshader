shader_type canvas_item;
uniform sampler2D water_cells : filter_nearest, repeat_disable;
uniform sampler2D water_depth : filter_linear, repeat_disable;
uniform float clock=0.0;
uniform float motion=0.0;
uniform float night_amount=0.0;
varying vec2 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
 vec2 grid_uv=world_point/3840.0;
 float kind=floor(texture(water_cells,grid_uv).r*255.0+.5);
 float wet=1.0-step(.5,abs(kind-8.0));
 wet*=step(0.0,world_point.x)*step(0.0,world_point.y)*step(world_point.x,3839.9)*step(world_point.y,3839.9);
 float depth=texture(water_depth,grid_uv).r;
 vec2 uv=UV;
 uv.x+=(sin(world_point.y*.19+clock*.9)+sin(world_point.y*.087-clock*.65))*.007*motion;
 vec4 reflected=texture(TEXTURE,clamp(uv,vec2(.001),vec2(.999)));
 reflected.rgb=mix(reflected.rgb,vec3(.28,.46,.43),.34);
 reflected.rgb*=mix(vec3(1),vec3(.68,.76,.87),night_amount);
 reflected.a*=wet*smoothstep(.035,.15,depth)*smoothstep(0.0,.25,UV.y)*.23;
 COLOR=reflected;
}
