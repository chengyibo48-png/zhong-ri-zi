shader_type canvas_item;
render_mode unshaded;
uniform sampler2D ground_atlas : filter_linear, repeat_disable;
uniform sampler2D cell_atlas : filter_nearest, repeat_disable;
uniform sampler2D shore_detail : filter_linear, repeat_enable;
uniform sampler2D snow_detail : filter_linear, repeat_enable;
uniform float snow_cover = 0.0;
uniform sampler2D surface_palette : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(120.0);
uniform float edge_width = 5.0;
uniform float texture_strength = 0.68;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
vec4 sample_ground(vec2 cell, vec2 offset) {
 vec2 coordinates = floor(texture(cell_atlas, (clamp(cell, vec2(0.0), map_size - 1.0) + 0.5) / map_size).rg * 255.0 + 0.5);
 vec2 pixel = coordinates * 32.0 + clamp(offset, vec2(0.5), vec2(31.5));
 vec4 painted = texture(ground_atlas, pixel / vec2(320.0, 512.0));
 vec3 quiet = texture(surface_palette, (vec2(coordinates.x, floor(coordinates.y / 4.0)) + 0.5) / vec2(10.0, 4.0)).rgb;
 return vec4(mix(quiet, painted.rgb, texture_strength), 1.0);
}
void fragment() {
 vec2 cell = floor(world_point / 32.0);
 vec2 local = world_point - cell * 32.0;
 vec2 direction = mix(vec2(-1.0), vec2(1.0), step(vec2(16.0), local));
 vec2 distance_to_edge = min(local, vec2(32.0) - local);
 vec2 weight = 0.5 * (vec2(1.0) - smoothstep(vec2(0.0), vec2(edge_width), distance_to_edge));
 vec4 center = sample_ground(cell, local);
 vec4 horizontal = sample_ground(cell + vec2(direction.x, 0.0), local - vec2(direction.x * 32.0, 0.0));
 vec4 vertical = sample_ground(cell + vec2(0.0, direction.y), local - vec2(0.0, direction.y * 32.0));
 vec4 diagonal = sample_ground(cell + direction, local - direction * 32.0);
 COLOR = mix(mix(center, horizontal, weight.x), mix(vertical, diagonal, weight.x), weight.y);
 vec2 atlas_uv = (clamp(cell, vec2(0.0), map_size - 1.0) + 0.5) / map_size;
 float column = floor(texture(cell_atlas, atlas_uv).r * 255.0 + 0.5);
 float water = 1.0 - step(0.5, abs(column - 8.0));
 float water_x = 1.0 - step(0.5, abs(texture(cell_atlas, (clamp(cell + vec2(direction.x, 0.0), vec2(0.0), map_size - 1.0) + 0.5) / map_size).r * 255.0 - 8.0));
 float water_y = 1.0 - step(0.5, abs(texture(cell_atlas, (clamp(cell + vec2(0.0, direction.y), vec2(0.0), map_size - 1.0) + 0.5) / map_size).r * 255.0 - 8.0));
 float bank = (1.0 - water) * max(weight.x * water_x, weight.y * water_y);
 COLOR.rgb = mix(COLOR.rgb, texture(shore_detail, world_point / 128.0).rgb, bank * 0.3);
 COLOR.rgb = mix(COLOR.rgb, texture(snow_detail, world_point / 192.0).rgb, (1.0 - water) * snow_cover * 0.2);
}
