shader_type canvas_item;
uniform float occlusion_alpha=1.0;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
	vec4 pixel=texture(TEXTURE,UV)*tint;
	if(TEXTURE_PIXEL_SIZE.x<0.05){pixel.a*=mix(1.0,occlusion_alpha,1.0-smoothstep(0.64,0.86,UV.y));}
	COLOR=pixel;
}
