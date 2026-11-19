extends RefCounted
## Shared deterministic motion clock for the player rig and resident mesh.
static func pose_for(kind:String,time:float,phase:float,side:int)->Dictionary:
 var p:=clampf(phase,0,1) if phase>=0 else fposmod(time*.9,1.0)
 var pulse:=sin(PI*smoothstep(0.0,1.0,p));var beat:=sin(TAU*p)
 var result:Dictionary={"lean":0.0,"crouch":0.0,"arm_near":0.0,"arm_far":0.0,"leg_near":0.0,"leg_far":0.0,"head":0.0,"tool":0.0,"mounted":false}
 var sign_side:=-float(side) if side!=0 else 1.0
 match kind:
  "walk":
   var stride:=sin(time*8.0);result.leg_near=.32*stride;result.leg_far=-.32*stride;result.arm_near=-.23*stride;result.arm_far=.23*stride
  "chop","dig","hoe","cut","build":
   result.arm_near=sign_side*(.35+1.6*pulse);result.arm_far=sign_side*(.25+1.3*pulse);result.lean=sign_side*.18*pulse;result.crouch=2.0*pulse;result.tool=sign_side*beat*.85
  "seed","harvest","gather","pet","brush","feed","care":
   result.crouch=4.0*pulse;result.lean=sign_side*.22*pulse;result.arm_near=sign_side*.95*pulse;result.arm_far=sign_side*.35*pulse
  "water":result.arm_near=sign_side*.8*pulse;result.arm_far=sign_side*.7*pulse;result.tool=sign_side*.4*pulse
  "greet","bell":result.arm_near=sign_side*(1.8*pulse+.18*beat);result.head=.04*beat
  "fish","fish_wait":result.arm_near=sign_side*.7;result.arm_far=sign_side*.55;result.tool=.035*sin(time*3)
  "fish_cast":result.arm_near=sign_side*(.4+1.45*pulse);result.arm_far=sign_side*(.3+1.2*pulse);result.tool=sign_side*.55*beat
  "fish_reel","fish_catch":result.arm_near=sign_side*(.7+.35*pulse);result.arm_far=sign_side*(.5+.2*beat);result.lean=sign_side*.08*pulse
  "eat","read","pack","trade","steam","door":result.arm_near=sign_side*(.2+1.1*pulse);result.arm_far=-sign_side*.35*pulse;result.head=.05*pulse;result.tool=.12*beat
  "rest","sleep","dress":result.arm_near=sign_side*1.8*pulse;result.arm_far=-sign_side*1.5*pulse;result.head=.08*pulse
  "bike":
   var pedal:=time*TAU*1.5
   result.mounted=true;result.crouch=-8.0-.35*cos(pedal*2.0)
   result.leg_near=.60+sin(pedal)*.45;result.leg_far=.60+sin(pedal+PI)*.45
   result.lean=sign_side*.10;result.arm_near=sign_side*.8;result.arm_far=sign_side*.65
  "ride":
   var gait:=time*TAU*1.2
   result.mounted=true;result.crouch=-8.0-.65*sin(gait*2.0)
   result.leg_near=.28+.10*sin(gait);result.leg_far=-.28-.10*sin(gait+PI)
   result.arm_near=sign_side*.72;result.arm_far=sign_side*.60
 return result
