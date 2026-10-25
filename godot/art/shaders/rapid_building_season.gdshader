shader_type canvas_item;
uniform int season = 0;
uniform float evening : hint_range(0.0, 1.0) = 0.0;
uniform float roof_bottom : hint_range(0.2, 0.8) = 0.57;

varying vec4 vertex_modulate;
void vertex() {
	vertex_modulate = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 color = source.rgb;
	float roof = 1.0 - smoothstep(roof_bottom - 0.03, roof_bottom, UV.y);
	if (season == 1) {
		color *= vec3(1.035, 1.015, 0.965);
	} else if (season == 2) {
		color *= vec3(1.06, 0.97, 0.875);
	} else if (season == 3) {
		float lightness = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		float above_alpha = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 4.0)).a;
		float edge_snow = clamp((source.a - above_alpha) * 3.0, 0.0, 1.0);
		float texture_snow = pow(clamp((lightness - 0.28) * 1.4, 0.0, 1.0), 1.7) * 0.67;
		color = mix(color * vec3(0.94, 0.98, 1.05), vec3(0.92, 0.95, 0.96), roof * max(edge_snow * 0.8, texture_snow));
	}
	// Original blue glazing supplies a window mask. It cannot move frames or doors.
	float glazing = step(roof_bottom + 0.07, UV.y) * step(source.r * 1.06, source.b) * smoothstep(0.30, 0.65, source.b);
	color = mix(color, vec3(0.95, 0.75, 0.41), glazing * evening * 0.68);
	COLOR = vec4(color, source.a) * vertex_modulate;
}
