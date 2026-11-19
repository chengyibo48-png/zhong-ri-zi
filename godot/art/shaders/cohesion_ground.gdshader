shader_type canvas_item;
render_mode unshaded;
uniform sampler2D ground_atlas : filter_linear, repeat_disable;
uniform sampler2D cell_atlas : filter_nearest, repeat_disable;
uniform sampler2D shore_detail : filter_linear, repeat_enable;
uniform sampler2D snow_detail : filter_linear, repeat_enable;
uniform sampler2D water_depth : filter_linear, repeat_disable;
uniform float water_clock=0.0;
uniform float water_motion=0.0;
uniform float snow_cover = 0.0;
uniform sampler2D surface_palette : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(120.0);
uniform float edge_width = 5.0;
uniform float texture_strength = 0.48;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
vec4 sample_ground(vec2 cell, vec2 offset) {
 vec2 coordinates = floor(texture(cell_atlas, (clamp(cell, vec2(0.0), map_size - 1.0) + 0.5) / map_size).rg * 255.0 + 0.5);
 vec2 pixel = coordinates * 32.0 + clamp(offset, vec2(0.5), vec2(31.5));
 vec4 painted = texture(ground_atlas, pixel / vec2(320.0, 512.0));
 vec3 quiet = texture(surface_palette, (vec2(coordinates.x, floor(coordinates.y / 4.0)) + 0.5) / vec2(10.0, 4.0)).rgb;
 return vec4(mix(quiet, painted.rgb, texture_strength), 1.0);
}
float landscape_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float landscape_noise(vec2 p) {
 vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(landscape_hash(i),landscape_hash(i+vec2(1,0)),f.x),mix(landscape_hash(i+vec2(0,1)),landscape_hash(i+vec2(1,1)),f.x),f.y);
}
float water_cell(vec2 cell) {
 float kind=floor(texture(cell_atlas,(clamp(cell,vec2(0),map_size-1.0)+.5)/map_size).r*255.0+.5);
 return 1.0-step(.5,abs(kind-8.0));
}
void fragment() {
 vec2 bend=vec2(landscape_noise(world_point/76.0),landscape_noise(world_point/91.0+vec2(17.0,31.0)))-0.5;
 vec2 ground_point=world_point+bend*12.0;
 vec2 cell = floor(ground_point / 32.0);
 vec2 local = ground_point - cell * 32.0;
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
 COLOR.rgb *= 0.97+landscape_noise(world_point/185.0)*0.06;
 if(water>.5) {
  if(water_cell(floor(world_point/32.0))>.5) {
  float depth=texture(water_depth,world_point/(map_size*32.0)).r;
  vec3 shallow=vec3(.47,.58,.48);
  vec3 deep=vec3(.25,.43,.43);
  COLOR.rgb=mix(COLOR.rgb,shallow,(1.0-smoothstep(.025,.25,depth))*.32);
  COLOR.rgb=mix(COLOR.rgb,deep,smoothstep(.12,.85,depth)*.32);
  float wave=sin(world_point.x*.031+world_point.y*.087+water_clock*.65+landscape_noise(world_point/93.0)*4.0);
  float glint=pow(max(0.0,wave),14.0)*(.35+.65*landscape_noise(world_point/54.0));
  COLOR.rgb+=vec3(.75,.86,.80)*glint*.028*(.45+.55*water_motion);
  }
  float sx=water_cell(cell+vec2(-1,0))<.5?-1.0:water_cell(cell+vec2(1,0))<.5?1.0:0.0;
  float sy=water_cell(cell+vec2(0,-1))<.5?-1.0:water_cell(cell+vec2(0,1))<.5?1.0:0.0;
  vec2 corner=vec2(sx<0.0?local.x:32.0-local.x,sy<0.0?local.y:32.0-local.y);
  if(abs(sx)>.5&&abs(sy)>.5&&corner.x<24.0&&corner.y<24.0) {
   float rounded=1.0-smoothstep(22.0,26.0,length(corner-vec2(24.0)));
   vec3 earth=sample_ground(cell+vec2(sx,0),local).rgb;
   earth=mix(earth,texture(shore_detail,world_point/96.0).rgb,.28);
   COLOR.rgb=mix(earth,COLOR.rgb,rounded);
  }
 }
 COLOR.rgb = mix(COLOR.rgb, texture(shore_detail, world_point / 128.0).rgb, bank * 0.3);
 COLOR.rgb = mix(COLOR.rgb, texture(snow_detail, world_point / 192.0).rgb, (1.0 - water) * snow_cover * 0.2);
}
