extends RefCounted
## Player-only presentation. No state writes, action commits, movement or NPC rules.
const GAIT:=preload("res://scripts/character_gait.gd")
const MOTION := preload("res://scripts/character_motion.gd")
const STRIDE_DISTANCE := 120.0
const SETTLE_TIME := 0.12
const START_TIME:=0.10
const TELEPORT_DISTANCE := 64.0
const HAIR_SIZES := {"short":Vector2(17,12),"bob":Vector2(18,18),"bun":Vector2(17,21),"wave":Vector2(18,17)}
const TOOL_SPECS := {
	"hoe":{"pack":"tools","key":"hoe","limit":Vector2(15,24),"grips":[Vector2(.5,.45),Vector2(.68,.45),Vector2(.32,.45),Vector2(.5,.45)]},
	"dig":{"pack":"tools","key":"spade","limit":Vector2(12,25),"grips":[Vector2(.5,.43),Vector2(.5,.43),Vector2(.5,.43),Vector2(.5,.43)]},
	"chop":{"pack":"tools","key":"axe","limit":Vector2(14,24),"grips":[Vector2(.65,.75),Vector2(.67,.75),Vector2(.67,.75),Vector2(.65,.75)],"angle":PI},
	"water":{"pack":"tools","key":"water","limit":Vector2(16,12),"limits":[Vector2(12,10),Vector2(16,12),Vector2(16,12),Vector2(12,10)],"grips":[Vector2(.5,.16),Vector2(.78,.24),Vector2(.22,.24),Vector2(.5,.16)]},
	"cut":{"pack":"tools","key":"sickle","limit":Vector2(17,23),"grips":[Vector2(.5,.75),Vector2(.65,.75),Vector2(.35,.75),Vector2(.5,.75)]},
	"fish":{"pack":"tools","key":"rod","limit":Vector2(13,34),"grips":[Vector2(.5,.82),Vector2(.5,.82),Vector2(.5,.82),Vector2(.5,.82)]},
	"brush":{"pack":"props","key":"brush","limit":Vector2(10,13),"grip":Vector2(.5,.75)},
	"build":{"pack":"props","key":"hammer","limit":Vector2(12,19),"grip":Vector2(.5,.8),"angle":PI},
	"read":{"pack":"props","key":"book","limit":Vector2(13,13),"grip":Vector2(.5,.8)},
	"pack":{"pack":"props","key":"parcel","limit":Vector2(13,12),"grip":Vector2(.5,.7)},
	"steam":{"pack":"props","key":"ladle","limit":Vector2(11,17),"grip":Vector2(.5,.75)},
	"bell":{"pack":"props","key":"bell","limit":Vector2(10,13),"grip":Vector2(.5,.1)}
}
var stride_phase := 0.0
var walk_weight := 0.0
var sampled := false
var moving := false
var settle_elapsed := SETTLE_TIME
var settle_start := 0.0
var attack_start:=0.0
var attack_elapsed:=0.0
var display_direction:=Vector2.DOWN
var requested_direction:=Vector2.DOWN
var turn_elapsed:=.10
var support_origin:=Vector2.ZERO
var support_anchors:Array[Vector2]=[Vector2.ZERO,Vector2.ZERO]
var support_offsets:Array[Vector2]=[Vector2.ZERO,Vector2.ZERO]
var support_active:Array[bool]=[false,false]
var support_age:Array[float]=[0.0,0.0]
var last_delta:=1.0/60
var effective_stride:=STRIDE_DISTANCE

func face(direction:Vector2)->void:
	if direction==requested_direction:return
	requested_direction=direction
	if sampled and walk_weight>.1 and moving:turn_elapsed=0.0
	else:display_direction=direction;turn_elapsed=.10
	support_active=[false,false];support_offsets=[Vector2.ZERO,Vector2.ZERO]

func presentation_direction(fallback:Vector2)->Vector2:
	return display_direction if sampled else fallback

func _support(displacement:Vector2,delta:float)->void:
	support_origin+=displacement
	for i in range(2):
		var step:=GAIT.leg(stride_phase+(.5 if i==0 else 0.0))
		var side:=display_direction.x
		var nominal:=Vector2(side*float(step.travel)*3.7 if side!=0 else float(step.travel)*.45,0)
		if bool(step.support) and moving:
			if not support_active[i]:support_anchors[i]=support_origin+nominal;support_age[i]=0.0
			support_age[i]+=delta
			var correction:=support_anchors[i]-support_origin-nominal
			# A short support constraint releases before the foot exceeds its reach.
			var release:=1.0-smoothstep(.025,.085,support_age[i])
			support_offsets[i]=correction.limit_length(1.8)*release
		else:support_offsets[i]=support_offsets[i].move_toward(Vector2.ZERO,delta*45)
		support_active[i]=bool(step.support) and moving


func sample(displacement: Vector2, delta: float) -> void:
	sampled = true
	if not displacement.is_finite() or not is_finite(delta) or delta <= 0.0: return
	var distance := displacement.length()
	if distance > TELEPORT_DISTANCE:
		stride_phase = 0.0; walk_weight = 0.0; moving = false; settle_elapsed = SETTLE_TIME
		support_origin=Vector2.ZERO;support_active=[false,false];support_offsets=[Vector2.ZERO,Vector2.ZERO];turn_elapsed=.10;display_direction=requested_direction
		return
	var was_moving := moving
	moving = distance > 0.001
	if moving:
		var speed:=distance/delta
		effective_stride=clampf(STRIDE_DISTANCE*lerpf(.82,1.08,smoothstep(0,265,speed)),84,132)
		stride_phase = fposmod(stride_phase + minf(distance/effective_stride,delta*2.2),1.0)
		if not was_moving:attack_start=walk_weight;attack_elapsed=0.0
		attack_elapsed=minf(START_TIME,attack_elapsed+delta)
		walk_weight=lerpf(attack_start,1.0,smoothstep(0,START_TIME,attack_elapsed));settle_elapsed=0.0
	elif was_moving:
		settle_start = walk_weight; settle_elapsed = 0.0
	last_delta=delta
	_support(displacement,delta)

func advance(delta: float) -> void:
	turn_elapsed=minf(.10,turn_elapsed+maxf(0,delta))
	if turn_elapsed>=.05:display_direction=requested_direction
	if moving or walk_weight <= 0.0: return
	settle_elapsed = minf(SETTLE_TIME,settle_elapsed + maxf(0.0,delta))
	walk_weight = settle_start * (1.0-smoothstep(0.0,SETTLE_TIME,settle_elapsed))

func snapshot() -> Dictionary:
	return {"sampled":sampled,"phase":stride_phase,"weight":walk_weight,"turn_weight":.45+.55*absf(turn_elapsed/.05-1.0),"support_offsets":support_offsets.duplicate(),"support":support_active.duplicate(),"stride_distance":effective_stride,"turning":turn_elapsed<.10}

static func tool_spec(kind: String, direction: String) -> Dictionary:
	var id: String = "fish" if kind.begins_with("fish") and kind != "fish_catch" else "brush" if kind == "care" else "pack" if kind == "trade" else "steam" if kind == "eat" else kind
	var source: Dictionary = TOOL_SPECS.get(id,{})
	if source.is_empty(): return {}
	var result := source.duplicate(true)
	var index: int = ["down","left","right","up"].find(direction)
	result.grip = source.grips[maxi(0,index)] if source.has("grips") else source.grip
	if source.has("limits"):result.limit = source.limits[maxi(0,index)]
	return result

static func _gesture(p: float, values: Array) -> float:
	var times := [0.0,.25,.52,.74,1.0]
	for i in range(4):
		if p <= times[i+1]:return lerpf(float(values[i]),float(values[i+1]),smoothstep(times[i],times[i+1],p))
	return float(values[-1])

static func pose_for(kind: String, time: float, phase: float, side: int) -> Dictionary:
	var pose := MOTION.pose_for(kind,time,phase,side)
	if kind in ["hoe","dig","chop","water","seed","harvest","gather"] and phase >= 0.0:
		var p := clampf(phase,0,1)
		var sign_side := -float(side) if side != 0 else 1.0
		var contact := _gesture(p,[0.0,.25,1.0,.45,0.0])
		var recovery := _gesture(clampf(p+.035,0,1),[0.0,.3,1.0,.5,0.0])
		if kind in ["hoe","dig","chop"]:
			var values := [.12,2.05,.65,.35,.12] if kind=="chop" else [.12,.95,1.42,.58,.12]
			pose.arm_near = sign_side*_gesture(p,values)
			pose.arm_far = sign_side*_gesture(clampf(p-.025,0,1),values)*.85
			pose.lean = sign_side*.12*recovery;pose.crouch = 1.6*contact
			pose.head = -sign_side*.054*_gesture(clampf(p-.055,0,1),[0.0,.3,1.0,.5,0.0])
			pose.tool = sign_side*.55*_gesture(clampf(p-.035,0,1),[0.0,-.5,1.0,.25,0.0])
		elif kind == "water":
			pose.arm_near = sign_side*_gesture(p,[.05,.62,.82,.68,.05]);pose.arm_far=0.0
			pose.tool = sign_side*.42*_gesture(clampf(p-.055,0,1),[0.0,.45,1.0,.8,0.0])
			pose.lean = sign_side*.035*contact
		else:
			pose.crouch = 4.0*recovery;pose.lean = sign_side*.15*recovery
			pose.arm_near = sign_side*.72*contact;pose.arm_far=sign_side*.18*contact
			pose.head = -sign_side*.0525*_gesture(clampf(p-.055,0,1),[0.0,.3,1.0,.5,0.0])
	return pose

static func elbow(start: Vector2, end: Vector2, first: float, second: float, bend: float) -> Vector2:
	var axis := end-start
	var distance := clampf(axis.length(),absf(first-second)+.05,first+second-.001)
	var along := (first*first-second*second+distance*distance)/(2.0*distance)
	var height := sqrt(maxf(0.0,first*first-along*along))
	var unit := axis.normalized() if axis.length_squared()>.000001 else Vector2.DOWN
	return start+unit*along+Vector2(-unit.y,unit.x)*height*bend

static func limb_mesh(row: Dictionary, region: Rect2, texture_size: Vector2) -> Dictionary:
	var joints: PackedVector2Array = row.joints
	var breaks: Array = [0.0,.45,.82,1.0] if row.limb=="arm" else [0.0,.46,.81,1.0]
	var vertices := PackedVector2Array();var uvs := PackedVector2Array();var indices := PackedInt32Array()
	# Shared cross-sections bend the existing painting continuously at each joint.
	var samples: Array[float] = [0.0,.12,.28,.40,.45,.46,.52,.65,.76,.81,.82,.90,1.0]
	for v: float in samples:
		var center: Vector2
		var tangent: Vector2
		var taper := 1.0-smoothstep(.3,.78,v)*(.48 if row.limb=="arm" else .38)
		if v>=breaks[2]:taper=lerpf(.52 if row.limb=="arm" else .62,.78 if row.limb=="arm" else 1.0,(v-float(breaks[2]))/(1.0-float(breaks[2])))
		var width := float(row.size.x)*taper
		if v >= breaks[2]:
			center = joints[2].lerp(joints[3],(v-float(breaks[2]))/(1.0-float(breaks[2])))
			tangent = (joints[3]-joints[2]).normalized()
		else:
			var f := v/float(breaks[2]);var inverse := 1.0-f
			var a := joints[0];var c := joints[2]-(joints[3]-joints[2]).normalized()*minf(3.0,joints[2].distance_to(joints[0])*.25)
			var b := joints[0].lerp(joints[2],.5).lerp(joints[1],.5 if row.limb=="leg" else .7);var d := joints[2]
			center = inverse*inverse*inverse*a+3.0*inverse*inverse*f*b+3.0*inverse*f*f*c+f*f*f*d
			var derivative := 3.0*(inverse*inverse*(b-a)+2.0*inverse*f*(c-b)+f*f*(d-c))
			var second := 6.0*(inverse*(c-2.0*b+a)+f*(d-2.0*c+b))
			tangent = derivative.normalized()
			var curvature := absf(derivative.cross(second))/maxf(.0001,pow(derivative.length(),3))
			if curvature > .0001:width=minf(width,1.0/curvature)
		var normal := Vector2(tangent.y,-tangent.x)
		for u: float in [0.0,1.0]:
			vertices.append(center+normal*(u-.5)*width)
			uvs.append((region.position+Vector2(u,v)*region.size)/texture_size)
	for i in range(samples.size()-1):
		var a:=i*2;indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
	return {"vertices":vertices,"uvs":uvs,"indices":indices}

static func _part(pack: String,key: String,at: Vector2,size: Vector2,pivot := Vector2(.5,0),angle := 0.0,kind := .8) -> Dictionary:
	return {"pack":pack,"key":key,"at":at,"size":size,"pivot":pivot,"angle":angle,"kind":kind,"flip_x":false}

static func solve(profile: Dictionary, clothes: Dictionary, pack: String, direction: String, clip: String, time: float, progress: float, locomotion: Dictionary = {}, animated := true) -> Dictionary:
	var side := -1 if direction == "left" else 1 if direction == "right" else 0
	var pose := pose_for(clip,time,progress,side)
	var sampled_motion := bool(locomotion.get("sampled",false))
	var weight := float(locomotion.get("weight",1.0))*float(locomotion.get("turn_weight",1.0))
	var walking := clip == "walk" or (clip == "idle" and sampled_motion and weight > 0.0)
	var phase:=float(locomotion.get("phase",0)) if sampled_motion else fposmod(time*8.0/TAU,1.0)
	var gait:Dictionary=GAIT.sample(phase,weight if sampled_motion else 1.0)
	if walking:
		if not animated:gait=GAIT.sample(0,0)
		pose.leg_near=float(gait.near.travel)*.27*float(gait.weight)
		pose.leg_far=float(gait.far.travel)*.27*float(gait.weight)
		pose.arm_near=-float(gait.arm)*.23*(float(side) if side!=0 else 1.0)
		pose.arm_far=(float(gait.arm)*.21+sin(TAU*phase*2)*.012*float(gait.weight))*(float(side) if side!=0 else 1.0)
		pose.lean=float(gait.roll)*(float(side) if side!=0 else 1.0);pose.crouch=float(gait.drop)
		pose.head=-float(pose.lean)*.65+float(gait.head)*(float(side) if side!=0 else 1.0)
	elif not animated and progress < 0.0 and not bool(pose.mounted):
		pose = MOTION.pose_for("idle",0.0,0.0,side)
	if side == 0 and clip in ["hoe","dig","chop","cut","build","seed","harvest","gather","fish_cast"] and progress >= 0.0:
		var envelope := smoothstep(0.0,.34,progress)*(1.0-smoothstep(.64,1.0,progress))
		pose.arm_near = .10 + (.36 if direction == "down" else 2.55)*envelope
		pose.arm_far = -float(pose.arm_near)
	if side==0 and clip in ["fish","fish_wait","fish_reel"]:
		pose.arm_near=(.4 if direction=="down" else 2.1)+.12*sin(PI*clampf(progress,0,1))
	var blend_from:Dictionary=locomotion.get("blend_from",{})
	var blend:float=float(locomotion.get("blend",1.0))
	if not blend_from.is_empty() and blend<1.0:
		for key:String in pose:
			if key!="mounted":pose[key]=lerpf(float(blend_from.get(key,pose[key])),float(pose[key]),blend)
	var lean := float(pose.lean)
	var lift := float(pose.crouch)
	var breath := sin(time*1.85)*.12 if animated and clip=="idle" and weight<=0.0 else 0.0
	var hip := Vector2(float(gait.pelvis)*(.45*float(side) if side!=0 else 1.0) if walking else 0.0,-14+lift+breath)
	var chest := hip + Vector2(0,-15.8).rotated(lean)
	var head := chest + Vector2(0,1.2).rotated(lean)
	var near_sign := -1.0 if side < 0 else 1.0
	var shoulder_near := chest + Vector2(near_sign*(1.0 if side != 0 else 6.2),3).rotated(lean)
	var shoulder_far := chest + Vector2(-near_sign*(1.0 if side != 0 else 6.2),3).rotated(lean)
	var near_angle := float(pose.arm_near)+lean
	var far_angle := float(pose.arm_far)+lean
	var effort := sin(PI*clampf(progress,0,1)) if progress>=0.0 else .25 if walking else .15
	var reach_near := 15.8-2.0*effort
	var hand := shoulder_near + Vector2(0,reach_near).rotated(near_angle)
	var layers: Dictionary = {}
	var foot_points: Array[Vector2] = []
	for limb in ["far","near"]:
		var angle := float(pose["leg_"+limb])
		var leg_x := near_sign*(1.4 if side != 0 else 2.8)*(1.0 if limb == "near" else -1.0)
		var step:Dictionary=gait[limb]
		var foot_lift:=float(step.lift)*float(gait.weight) if walking else 0.0
		var at := Vector2(leg_x,-14*cos(angle)-foot_lift)
		if bool(pose.mounted): at = hip+Vector2(leg_x,0)
		var key := "leg_left" if (limb == "near") == (side < 0) else "leg_right"
		layers[limb+"_leg"] = _part(pack,key,at,Vector2(6.5,14),Vector2(.5,0),angle,.5)
		var foot := at+Vector2(0,14).rotated(angle)
		if walking:
			var travel:=float(step.travel)*float(gait.weight)
			foot=Vector2(leg_x+(float(side)*travel*3.7 if side!=0 else travel*.45),-foot_lift)
		if walking:
			var offsets:Array=locomotion.get("support_offsets",[])
			if offsets.size()==2:foot+=Vector2(offsets[0 if limb=="far" else 1])*float(gait.weight)
		if not bool(pose.mounted):
			var root := hip+Vector2(leg_x,0)
			var ankle := foot-Vector2(0,2.4).rotated(float(step.toe)*float(gait.weight) if walking else 0.0)
			if root.distance_to(ankle)>12.3:
				ankle=root+(ankle-root).normalized()*12.3
				foot=ankle+Vector2(0,2.4).rotated(float(step.toe)*float(gait.weight) if walking else 0.0)
			var knee := elbow(root,ankle,6.4,6.0,-float(side)*.9 if side!=0 else -signf(leg_x)*.45)
			layers[limb+"_leg"].joints = PackedVector2Array([root,knee,ankle,foot])
			layers[limb+"_leg"].limb = "leg"
		foot_points.append(foot)
	layers.far_arm = _part(pack,"arm_right" if side < 0 else "arm_left",shoulder_far,Vector2(5.2,18),Vector2(.5,0),far_angle,.4)
	layers.near_arm = _part(pack,"arm_left" if side < 0 else "arm_right",shoulder_near,Vector2(5.2,18),Vector2(.5,0),near_angle,.4)
	var torso_height := 22.0 if pack in ["apron","rain"] else 18.0 if pack in ["cold","festival"] else 17.0
	layers.torso = _part(pack,"torso",chest,Vector2(12.5 if side != 0 else 17,torso_height),Vector2(.5,0),lean,.3)
	layers.head = _part("heads","head",head,Vector2(12,12.5),Vector2(.5,1),lean+float(pose.head),.1)
	var hair: String = ["short","bob","bun","wave"][clampi(int(profile.get("hair",0)),0,3)]
	var hair_size: Vector2 = HAIR_SIZES[hair] * (.74 if pack == "rain" else .82)
	layers.hair = _part("heads",hair,head+Vector2(0,-3.3 if hair == "short" else .7),hair_size,Vector2(.5,1),lean+float(pose.head),.2)
	if pack == "rain": layers.hood = _part("transport","hood",head+Vector2(0,1),Vector2(16.5,17.5),Vector2(.5,1),lean,.7)
	if pack == "cold": layers.hat = _part("transport","beanie",head+Vector2(0,-7.5),Vector2(15,7.5),Vector2(.5,1),lean,.7)
	elif pack != "rain" and bool(profile.get("hat",true)): layers.hat = _part("heads","hat",head+Vector2(0,-6.8),Vector2(20.5,9.5),Vector2(.5,1),lean,.8)
	if bool(profile.get("bag",false)):
		var bag_offset := Vector2(-5,1) if side == 0 else Vector2(-side*6,1)
		if direction == "up": bag_offset = Vector2(0,1)
		layers.bag = _part(pack,"bag",chest+bag_offset.rotated(lean),Vector2(9,14),Vector2(.5,0),lean,.8)
	var tool := tool_spec(clip,direction)
	if not tool.is_empty():
		var angle := near_angle + float(tool.get("angle",0.0)) + float(pose.tool)*.35
		if clip == "water": angle = -float(pose.tool)*1.4
		elif clip.begins_with("fish"): angle = side*(.25+.6*sin(PI*clampf(progress,0,1))) if clip == "fish_cast" else side*.25+float(pose.tool)
		if side==0 and clip in ["fish","fish_wait","fish_reel"]:angle=(.38 if direction=="down" else -.24)+float(pose.tool)*.35
		layers.tool = _part(str(tool.pack),str(tool.key),hand,tool.limit,tool.grip,angle,.8)
		layers.tool.fit_aspect = true
	var secondary_hand := shoulder_far+Vector2(0,15.5).rotated(far_angle)
	if clip in ["hoe","dig","chop","cut","build","fish","fish_cast","fish_reel","fish_wait"]:
		# The second hand follows the same shaft instead of waving beside it.
		var shaft_angle := float(layers.tool.angle) if layers.has("tool") else near_angle
		var shaft_sign := 1.0 if clip in ["chop","build"] else -1.0
		secondary_hand = hand+Vector2(0,2.5*shaft_sign).rotated(shaft_angle)
		var reach := secondary_hand-shoulder_far
		var reach_length := reach.length()
		layers.far_arm.angle = reach.angle()-PI*.5
		layers.far_arm.size = Vector2(5.2,18*reach_length/16.7)
	# Elbows and wrists deform the same continuous source, without cut-out seams.
	var bend_near := float(side)*.75 if side!=0 else -.35
	var bend_far := -bend_near
	var wrist_near := hand-Vector2(0,1.9).rotated(near_angle)
	var wrist_far := secondary_hand-Vector2(0,1.9).rotated(float(layers.far_arm.angle))
	layers.near_arm.joints = PackedVector2Array([shoulder_near,elbow(shoulder_near,wrist_near,7.2,7.0,bend_near),wrist_near,hand+Vector2(0,.6).rotated(near_angle)])
	layers.far_arm.joints = PackedVector2Array([shoulder_far,elbow(shoulder_far,wrist_far,7.2,7.0,bend_far),wrist_far,secondary_hand+Vector2(0,.6).rotated(float(layers.far_arm.angle))])
	layers.near_arm.limb = "arm";layers.far_arm.limb = "arm"
	var order: Array[String] = ["bag","far_leg","near_leg","far_arm","torso","hood","head","hair","hat","near_arm","tool"]
	if direction == "up": order = ["far_leg","near_leg","far_arm","tool","near_arm","torso","bag","head","hair","hood","hat"]
	elif direction == "left": order = ["far_leg","far_arm","bag","near_leg","torso","hood","head","hair","hat","near_arm","tool"]
	elif direction == "right": order = ["far_leg","bag","far_arm","near_leg","torso","hood","head","hair","hat","near_arm","tool"]
	var commands: Array[Dictionary] = []
	if bool(pose.mounted): commands.append(_part("transport","pony" if clip == "ride" else "bike",Vector2(0,1),Vector2(35,31) if side != 0 else Vector2(20,31),Vector2(.5,1)))
	for role: String in order:
		if layers.has(role):
			layers[role].role = role
			layers[role].shade = .9 if role in ["far_arm","far_leg"] else 1.0
			commands.append(layers[role])
	return {"pose":pose,"commands":commands,"sockets":{"hip":hip,"chest":chest,"head":head,"hand":hand,"shoulder_near":shoulder_near,"shoulder_far":shoulder_far,"secondary_hand":secondary_hand},"feet":foot_points,"tool":tool}
