shader_type canvas_item;
uniform sampler2D floor_texture : source_color, filter_linear, repeat_enable;
uniform int floor_kind = 0;
uniform vec3 wood_tint=vec3(1.0);
uniform float night_amount=0.0;
varying vec2 floor_point;
void vertex() { floor_point=VERTEX; }
void fragment() {
 vec2 p=floor_point-vec2(112.0,200.0);
 vec2 tile_size=floor_kind==0?vec2(288.0,192.0):floor_kind==1?vec2(160.0):floor_kind==2?vec2(64.0):vec2(128.0);
 vec3 color=texture(floor_texture,p/tile_size).rgb;
 if(floor_kind==0)color*=wood_tint;
 float edge=min(min(p.x,736.0-p.x),min(p.y,375.0-p.y));
 color*=.78+.22*smoothstep(0.0,22.0,edge);
 color*=mix(vec3(1),vec3(.64,.68,.73),night_amount);
 COLOR=vec4(color,1.0);
}
