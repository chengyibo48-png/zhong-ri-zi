shader_type canvas_item;
render_mode unshaded;
varying vec4 ink;
void vertex(){ink=COLOR;}
void fragment() {
	vec4 texel=texture(TEXTURE,UV);
	if(texel.a<0.72){discard;}
	COLOR=ink*vec4(texel.rgb,smoothstep(0.72,0.96,texel.a));
}
