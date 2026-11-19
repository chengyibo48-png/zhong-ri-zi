shader_type canvas_item;
uniform sampler2D bank_texture : source_color, filter_linear, repeat_enable;
uniform int season=0;
uniform float snow_cover=0.0;
void fragment() {
 float u=fract(UV.x);
 vec4 trim=texture(bank_texture,vec2(u,UV.y));
 vec4 seam=.5*(texture(bank_texture,vec2(.001,UV.y))+texture(bank_texture,vec2(.999,UV.y)));
 float edge=min(u,1.0-u);
 trim=mix(seam,trim,smoothstep(0.0,.045,edge));
 if(season==2)trim.rgb*=vec3(1.04,.975,.88);
 if(season==3)trim.rgb=mix(trim.rgb,vec3(.83,.85,.79),.30);
 trim.rgb=mix(trim.rgb,vec3(.91,.925,.89),clamp(snow_cover*.65,0.0,.75));
 trim.a*=smoothstep(0.0,.12,UV.y)*(1.0-smoothstep(.82,1.0,UV.y));
 COLOR=trim;
}
