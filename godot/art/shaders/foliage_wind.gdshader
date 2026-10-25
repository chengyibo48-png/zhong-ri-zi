shader_type canvas_item;
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float wind = 0.0;
uniform float height = 64.0;
uniform float softness = 1.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
	float weight = clamp(-VERTEX.y / max(height, 1.0), 0.0, 1.0);
	float gust = sin(clock * 1.35 + phase) + 0.32 * sin(clock * 2.7 + phase * 1.7);
	VERTEX.x += gust * wind * weight * weight;
}
void fragment() {
	vec2 uv = UV;
	if (TEXTURE_PIXEL_SIZE.x < 0.1) {
		float canopy = pow(1.0 - UV.y, 2.0);
		uv.x += sin(clock * 2.3 + phase + UV.y * 11.0) * wind / max(height, 1.0) * 0.14 * softness * canopy;
		vec4 pixel = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
		if (uv.x < 0.0 || uv.x > 1.0) { pixel.a = 0.0; }
		COLOR = vertex_tint * pixel;
	} else { COLOR = vertex_tint; }
}
