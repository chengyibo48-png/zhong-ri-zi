shader_type canvas_item;
render_mode unshaded;
uniform vec2 roots[4];
uniform vec2 tips[4];
uniform vec2 foot_offsets[4];
uniform vec2 knee_offsets[4];
uniform int leg_count=0;
uniform vec2 body_center=vec2(0.0,-20.0);
uniform vec2 body_radius=vec2(15.0,10.0);
uniform vec2 head_center=vec2(0.0,-35.0);
uniform float head_radius=10.0;
uniform float head_angle=0.0;
uniform float breath=0.0;
uniform float torso_width=1.0;
uniform float water=0.0;
uniform float height=40.0;
uniform float visual_clock=0.0;
uniform vec4 coat:source_color=vec4(1.0);
varying vec2 local_position;
varying vec4 surface_ink;
void vertex(){
 surface_ink=COLOR;
 vec2 original=VERTEX;vec2 displacement=vec2(0.0);float total=0.0;
 for(int i=0;i<4;i++){
  if(i>=leg_count){break;}
  float t=clamp((original.y-roots[i].y)/max(1.0,tips[i].y-roots[i].y),0.0,1.0);
  float center_x=mix(roots[i].x,tips[i].x,t);
  float lateral=exp(-pow(abs(original.x-center_x)/max(1.5,height*0.095),4.0));
  float influence=smoothstep(0.0,0.5,t)*lateral;
  displacement+=(foot_offsets[i]*t+knee_offsets[i]*(4.0*t*(1.0-t)))*influence;
  total+=influence;
 }
 if(total>0.0){displacement/=max(1.0,total);}
 float body_weight=exp(-pow(length((original-body_center)/max(body_radius,vec2(1.0))),4.0));
 displacement.x+=(original.x-body_center.x)*(torso_width-1.0+breath)*body_weight;
 displacement.y-=(original.y-body_center.y)*breath*body_weight;
 vec2 d=original-head_center;float head_weight=exp(-pow(length(d)/max(1.0,head_radius),4.0));
 vec2 turned=mat2(vec2(cos(head_angle),sin(head_angle)),vec2(-sin(head_angle),cos(head_angle)))*d;
 displacement+=(turned-d)*head_weight;
 VERTEX+=displacement;VERTEX.y+=water*height*0.13;
 local_position=VERTEX;
}
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 float alpha=tex.a<0.72?0.0:tex.a;
 if(water>0.0){float surface=-height*0.035+sin(visual_clock*2.5+local_position.x*0.23)*height*0.005;alpha*=1.0-water*smoothstep(surface-0.7,surface+0.7,local_position.y);}
 COLOR=vec4(tex.rgb*coat.rgb*surface_ink.rgb,alpha*coat.a*surface_ink.a);
}
