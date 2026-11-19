shader_type canvas_item;
uniform float occlusion_alpha=1.0;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 night_tint : source_color = vec4(0.72, 0.79, 0.91, 1.0);
void fragment() {
	vec4 base = COLOR;
	float rim=clamp(base.a-texture(TEXTURE,UV-vec2(0.0,TEXTURE_PIXEL_SIZE.y*1.5)).a,0.0,1.0);
	base.rgb+=vec3(.025,.019,.011)*rim;
	float luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Existing warm paint remains visible; alpha and seasonal silhouettes are exact.
	float warm = smoothstep(0.08, 0.28, base.r - base.b) * smoothstep(0.45, 0.85, luma);
	vec3 evening = base.rgb * night_tint.rgb;
	evening += vec3(0.12, 0.065, 0.015) * warm;
	COLOR = vec4(mix(base.rgb, evening, night_amount), base.a);
	if(TEXTURE_PIXEL_SIZE.x<0.1){COLOR.a*=mix(1.0,occlusion_alpha,1.0-smoothstep(0.66,0.86,UV.y));}
}
