shader_type canvas_item;
uniform vec4 actor_ambient:source_color=vec4(1.0);
uniform float actor_warm=0.0;
varying vec4 actor_tint;
void vertex(){actor_tint=COLOR;}
void fragment(){
	vec4 paint=texture(TEXTURE,UV)*actor_tint;
	float shade=clamp(1.0-dot(paint.rgb,vec3(.299,.587,.114))*.55,.35,1.0);
	vec3 lit=paint.rgb*actor_ambient.rgb;
	lit+=vec3(.12,.055,.009)*actor_warm*shade;
	COLOR=vec4(clamp(lit,vec3(0.0),vec3(1.0)),paint.a);
}
