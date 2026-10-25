shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float moisture : hint_range(0.0,1.0) = 0.45;
uniform float fertility : hint_range(0.0,1.0) = 1.0;
uniform vec4 soil_tint : source_color = vec4(1.0);
uniform vec2 joined = vec2(0.0);
uniform float seed = 0.0;
uniform float wetland = 0.0;
uniform float fallow = 0.0;
uniform float planted = 0.0;
uniform float animate_water = 1.0;
uniform float snow_cover : hint_range(0.0,1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment() {
	vec4 modulation=COLOR;
	vec2 p=UV;
	float grain=noise(p*vec2(36.0,23.0)+seed);
	float ragged=(grain-0.5)*0.016;
	// Horizontal neighbors share a continuous bed; exposed ends round into the grass.
	float x_left=mix(0.052, -0.04, joined.x);
	float x_right=mix(0.948, 1.04, joined.y);
	float corner=pow(abs(p.y-0.49)*2.0,4.0)*0.045;
	float bank=smoothstep(0.08+ragged,0.13,p.y)*(1.0-smoothstep(0.85,0.93+ragged,p.y));
	bank*=smoothstep(x_left+corner-0.02,x_left+corner+0.015,p.x)*(1.0-smoothstep(x_right-corner-0.015,x_right-corner+0.02,p.x));
	float surface=smoothstep(0.16,0.20,p.y)*(1.0-smoothstep(0.77,0.82,p.y));
	vec2 sample_uv=vec2(p.x*0.23+mod(seed*0.173,1.0),p.y*0.20+mod(seed*0.137,1.0));
	vec3 raw_earth=texture(earth_texture,sample_uv).rgb;
	vec3 earth=mix(vec3(0.43,0.285,0.15),raw_earth,0.76) * soil_tint.rgb;
	// Wide, shallow furrows have a lit lip and a dark bed; no drawn grid at seams.
	float groove=sin(p.x*18.84956+sin(p.y*3.5+seed)*0.22);
	earth*=0.94+groove*0.23;
	earth*=mix(0.73,1.04,surface);
	earth+=vec3(0.115,0.068,0.028)*exp(-pow((p.y-0.19)*40.0,2.0));
	earth=mix(earth,earth*vec3(0.68,0.72,0.72),smoothstep(0.22,0.85,moisture));
	earth=mix(earth,earth*vec3(0.92,0.96,1.0),wetland*0.3);
	earth=mix(earth*vec3(1.07,0.99,0.87),earth,smoothstep(0.1,0.55,fertility));
	// Dry cracks follow short branching lines, strongest on genuinely dry ground.
	float crack=abs(sin(p.x*19.0+noise(p*5.0+seed)*4.0));
	float branches=step(0.66,noise(p*vec2(9,4)+seed));
	earth*=1.0-(1.0-smoothstep(0.025,0.07,crack))*branches*(1.0-smoothstep(0.10,0.28,moisture))*0.30;
	// Saturated soil gets small reflected pools, rather than a blue status stripe.
	float puddle=smoothstep(0.73,0.88,noise(p*vec2(12,6)+seed))*smoothstep(0.80,1.0,moisture)*surface;
	float shimmer=0.5+0.5*sin(p.y*35.0+seed+TIME*animate_water*0.7);
	earth=mix(earth,vec3(0.23,0.28,0.23),puddle*0.20);
	earth+=puddle*shimmer*vec3(0.025,0.04,0.035);
	float straw=step(0.87,noise(p*vec2(45,80)+seed))*fallow;
	earth=mix(earth,vec3(0.64,0.52,0.30),straw*0.6);
	float root_shadow=exp(-dot((p-vec2(0.5,0.57))*vec2(7.0,11.0),(p-vec2(0.5,0.57))*vec2(7.0,11.0)));
	earth*=1.0-root_shadow*planted*0.17;
	float frost=snow_cover*((0.22+grain*0.25)*(1.0-surface)+0.05*smoothstep(0.70,0.95,grain)*surface);
	earth=mix(earth,vec3(0.76,0.80,0.77),frost);
	// The thin apron blends the bank into the existing painted grass.
	float apron=smoothstep(0.0,0.10,p.y)*(1.0-smoothstep(0.91,1.0,p.y));
	apron*=smoothstep(0.0,0.05,p.x)*(1.0-smoothstep(0.95,1.0,p.x));
	float alpha=max(bank,apron*0.18);
	COLOR=vec4(earth,alpha)*modulation;
}
