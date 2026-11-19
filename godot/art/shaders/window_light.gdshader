shader_type canvas_item;
render_mode blend_add;
uniform float strength=.12;
void fragment() {
 float edge=smoothstep(0.0,.07,UV.x)*(1.0-smoothstep(.93,1.0,UV.x));
 float falloff=1.0-smoothstep(.18,1.0,UV.y);
 float pane=min(abs(UV.x-.333),abs(UV.x-.667));
 float mullion=mix(.22,1.0,smoothstep(.012,.035,pane));
 COLOR=vec4(1.0,.79,.47,strength*edge*falloff*mullion);
}
