shader_type canvas_item;
uniform vec4 skin_color:source_color=vec4(0.8902,0.7255,0.5686,1.0);
uniform vec4 shirt_color:source_color=vec4(0.2588,0.4627,0.3765,1.0);
uniform vec4 hair_color:source_color=vec4(0.2235,0.2627,0.2157,1.0);
varying float part_kind;
varying float part_alpha;
void vertex(){part_kind=COLOR.r;part_alpha=COLOR.a;}
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 vec3 rgb=tex.rgb;
 if(part_kind>0.15 && part_kind<0.25){
  float light=dot(rgb,vec3(.299,.587,.114));
  rgb=hair_color.rgb*clamp(light*1.45,.08,1.28);
 }else{
  bool skin_part=(part_kind>.05 && part_kind<.15)||(part_kind>.35 && part_kind<.45)||((part_kind>.25 && part_kind<.35) && UV.y<.22);
  bool fabric_part=(part_kind>.25 && part_kind<.45)||(part_kind>.65 && part_kind<.75);
  // Warm skin and sage cloth are authored as separate color families.
  // Brown shoes, eyes, cream aprons and red embroidery retain their paint.
  bool skin_pixel=rgb.r>rgb.g*1.08 && rgb.g>rgb.b*1.06 && rgb.r>.46 && rgb.b>.24;
  bool green_pixel=rgb.g>rgb.b*1.11 && rgb.r<rgb.g*1.03 && rgb.g>rgb.r*.97 && rgb.g>.15;
  if(skin_part && skin_pixel){rgb*=skin_color.rgb/vec3(.8902,.7255,.5686);}
  else if(fabric_part && green_pixel){rgb*=shirt_color.rgb/vec3(.48,.50,.35);}
 }
 COLOR=vec4(clamp(rgb,vec3(0.0),vec3(1.0)),tex.a*part_alpha);
}
