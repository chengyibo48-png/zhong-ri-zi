extends RefCounted
## One resident identity, a continuous shoulder/hip mesh, and a bounded pose cache.
const GAIT:=preload("res://scripts/character_gait.gd")
const MOTION := preload("res://scripts/character_motion.gd")
const XS := [0.0,36.0,43.0,49.0,55.0,64.0,73.0,79.0,85.0,92.0,128.0]
const YS := [0.0,46.0,52.0,60.0,70.0,80.0,88.0,96.0,106.0,116.0,128.0]
const CACHE_LIMIT := 768
static var meshes: Dictionary = {}
static var profiles:Dictionary={}
static func profile(actor:String)->Dictionary:
	if profiles.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/resident_visual_profiles.json"))
		if parsed is Dictionary:profiles=parsed
	return profiles.get(actor,{})
static func proportions(point:Vector2,identity:Dictionary,direction:String)->Vector2:
	var result:=point
	var head:=float(identity.get("head",1))
	# Keep face and hair in one rigid group, anchored at the neck.
	var head_weight:=1.0-smoothstep(46,56,point.y)
	var resized:=Vector2(64,52)+(point-Vector2(64,52))*head
	result=result.lerp(resized,head_weight)
	var shoulder:float=exp(-pow((point.y-62.0)/13.0,2.0))
	var waist:float=exp(-pow((point.y-83.0)/11.0,2.0))
	var volume:float=1.0+(float(identity.get("shoulder",1))-1)*shoulder+(float(identity.get("waist",1))-1)*waist
	result.x=64+(result.x-64)*float(identity.get("width",1))*volume
	var side:= -1.0 if direction=="left" else 1.0 if direction=="right" else 0.0
	result.x+=side*float(identity.get("stoop",0))*(1.0-smoothstep(52,108,point.y))
	result.y=116+(result.y-116)*float(identity.get("height",1))
	return result

static func deform(source: Vector2, clip: String, direction: String, time: float, progress: float, animated: bool=true) -> Vector2:
	var side: int=-1 if direction=="left" else 1 if direction=="right" else 0
	var pose:=MOTION.pose_for(clip,time,progress,side)
	if not animated:pose=MOTION.pose_for("idle",0.0,0.0,side)
	if clip=="walk" and animated:pose.gait=GAIT.sample(time*8.0/TAU);pose.arm_near=-float(pose.gait.arm)*.23;pose.arm_far=float(pose.gait.arm)*.21
	return _deform(source,clip,direction,time,pose,animated)

static func _deform(source: Vector2, clip: String, direction: String, time: float, pose: Dictionary, animated: bool) -> Vector2:
	var side: int=-1 if direction=="left" else 1 if direction=="right" else 0
	var p:=source
	var limb_side:=clampf((source.x-64.0)/8.0,-1.0,1.0)
	var stride:=sin(time*8.0) if clip=="walk" and animated else 0.0
	var weight_shift:=sin(time*8.0-.18) if clip=="walk" and animated else 0.0
	var leg:=smoothstep(88.0,103.0,source.y)
	var gait:Dictionary=pose.get("gait",{})
	var near_leg:bool=source.x<64.0 if side<0 else source.x>=64.0
	var step:Dictionary=gait.get("near" if near_leg else "far",{})
	var angle:=-float(step.get("travel",0))*(float(side) if side!=0 else 1.0)*.14 if not gait.is_empty() else stride*limb_side*.16
	var hip:=Vector2(64.0+limb_side*8.0,90.0)
	var leg_source:=Vector2(clampf(source.x,56.0,72.0),minf(source.y,116.0))
	p+=(hip+(leg_source-hip).rotated(angle)-leg_source)*leg
	p.y+=leg*((1.0-cos(angle))*26.0-float(step.get("lift",0))*1.9)
	# Pelvis leads, shoulders counterrotate; head receives only a small delayed sway.
	var body:=1.0-smoothstep(88,111,source.y)
	p.x+=weight_shift*.7*body
	p.y+=absf(stride)*.35*body
	var outer:=smoothstep(7.0 if side!=0 else 12.0,16.0 if side!=0 else 22.0,absf(source.x-64.0))
	var arm:=outer*smoothstep(48.0,59.0,source.y)*(1.0-smoothstep(86.0,96.0,source.y))
	# Profile sleeves overlap the torso in the master; preserve their silhouette.
	if side!=0:arm*=.16
	var near:=source.x<64.0 if side<0 else source.x>=64.0
	var arm_angle:=float(pose.arm_near if near else pose.arm_far)
	if side>0:arm_angle=-arm_angle
	# Keep the far wrist in front of its own torso rather than crossing the mesh.
	if clip!="walk":arm_angle=maxf(-.15,arm_angle)
	if clip=="walk":arm_angle*=.65
	var outward:=-1.0 if source.x<64.0 else 1.0
	var shoulder:=Vector2(64.0+outward*(10.0 if side!=0 else 15.0),57.0)
	var arm_source:=Vector2(clampf(source.x,43.0,85.0),source.y)
	p+=(shoulder+(arm_source-shoulder).rotated(-outward*clampf(absf(arm_angle),0.0,.45)*signf(arm_angle))-arm_source)*arm
	var upper:=1.0-smoothstep(87.0,109.0,source.y)
	var lean:=clampf(float(pose.lean),-.12,.12)
	p=p.lerp(Vector2(64,96)+(p-Vector2(64,96)).rotated(lean),upper)
	p.y+=float(pose.crouch)*1.8*upper
	# Face vertices share one rigid transform, without separate eye/mouth warping.
	if animated and clip=="idle":p.y+=sin(time*2.0)*.35*upper
	return p

static func geometry(spec: Dictionary, clip: String, direction: String, time: float, progress: float, animated: bool=true, identity:Dictionary={}) -> Dictionary:
	var cell:=Vector2(float(spec.frameSize[0]),float(spec.frameSize[1]))
	var anchor:=Vector2(float(spec.anchor[0]),float(spec.anchor[1]))
	var ratio:=float(spec.get("worldHeight",42.0))/108.0
	var row: int=spec.directions.find(direction)
	var vertices:=PackedVector2Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	var side: int=-1 if direction=="left" else 1 if direction=="right" else 0
	var pose:=MOTION.pose_for(clip,time,progress,side) if animated else MOTION.pose_for("idle",0.0,0.0,side)
	if clip=="walk" and animated:pose.gait=GAIT.sample(time*8.0/TAU);pose.arm_near=-float(pose.gait.arm)*.23;pose.arm_far=float(pose.gait.arm)*.21
	if animated and progress<0 and clip not in ["walk","idle"]:
		# Ambient work is a small coordinated cycle, not a repeated full interaction swing.
		pose.arm_near*=.38;pose.arm_far*=.38;pose.crouch*=.35;pose.lean*=.40
	for y: float in YS:
		for x: float in XS:
			var source:=Vector2(x,y)*cell/128.0
			vertices.append((proportions(_deform(Vector2(x,y),clip,direction,time,pose,animated),identity,direction)*cell/128.0-anchor)*ratio)
			uvs.append((source+Vector2(0,row*cell.y))/(cell*Vector2(float(spec.frames),float(spec.directions.size()))))
	for y: int in range(YS.size()-1):
		for x: int in range(XS.size()-1):
			var a:=y*XS.size()+x;var b:=a+1;var c:=a+XS.size();var d:=c+1
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	return {"vertices":vertices,"uvs":uvs,"indices":indices}

static func draw_actor(target: CanvasItem, actor: String, clip: String, direction: String, time: float, progress: float) -> bool:
	var art: Script=load("res://scripts/character_art.gd")
	var spec: Dictionary=art.data().get("actors",{}).get(actor,{}).get("clips",{}).get("idle",{})
	if spec.is_empty() or not bool(spec.get("ready",false)):return false
	var row: int=spec.get("directions",[]).find(direction)
	var texture: Texture2D=art.texture(str(spec.get("path","")))
	if row<0 or texture==null:return false
	var presentation: Script=load("res://scripts/life_presentation.gd")
	var animated: bool=presentation.animate()
	var sample_time:=time
	if clip!="walk" and progress<0:
		var identity:Dictionary=load("res://scripts/resident_life.gd").profile(actor)
		sample_time=time*float(identity.get("tempo",1))+float(identity.get("phase",0))
	var motion:Dictionary=target.resident_motion() if target.has_method("resident_motion") else {}
	if clip=="walk" and bool(motion.get("sampled",false)) and float(motion.get("weight",0))<=.001:clip="idle"
	if clip=="walk" and bool(motion.get("sampled",false)):sample_time=float(motion.get("phase",0))*TAU/8.0
	# Keys describe a cyclic pose, not elapsed session time. All 24 residents'
	# walking phases fit within the bounded cache and survive another stride.
	var sampled_time:=0.0
	if animated:
		if clip=="walk":sampled_time=roundf(fposmod(sample_time*8.0,TAU)/TAU*24.0)/24.0*TAU/8.0
		elif clip=="idle":sampled_time=floorf(fposmod(sample_time,PI)*12.0)/12.0
		elif progress<0:sampled_time=floorf(fposmod(sample_time,1.0/.9)*24.0)/24.0
	var sampled_progress:=roundf(progress*24.0)/24.0 if progress>=0.0 else -1.0
	var key:="%s/%s/%s/%.3f/%.3f/%s"%[actor,clip,direction,sampled_time,sampled_progress,animated]
	var mesh: ArrayMesh=meshes.get(key)
	if mesh==null:
		var geometry_data:=geometry(spec,clip,direction,sampled_time,sampled_progress,animated,profile(actor))
		mesh=_mesh(geometry_data)
		while meshes.size()>=CACHE_LIMIT:meshes.erase(meshes.keys()[0])
		meshes[key]=mesh
	var vertices:PackedVector2Array=mesh.get_meta("vertices")
	var next_vertices:=vertices.duplicate()
	var weight:=float(motion.get("weight",0))*float(motion.get("turn_weight",1))
	if clip=="walk" and bool(motion.get("sampled",false)) and weight<.999:
		var standing:=geometry(spec,"idle",direction,floorf(fposmod(time,PI)*12.0)/12.0,-1,animated,profile(actor))
		for i in next_vertices.size():next_vertices[i]=standing.vertices[i].lerp(vertices[i],weight)
	if clip=="idle" and bool(motion.get("sampled",false)) and weight>.001:
		var walking:=geometry(spec,"walk",direction,float(motion.get("phase",0))*TAU/8.0,-1,animated,profile(actor))
		for i in next_vertices.size():next_vertices[i]=next_vertices[i].lerp(walking.vertices[i],weight)
	# Personality uses small continuous offsets on the original connected surface.
	# Facial vertices share one rigid head transform; feet stay on their original plane.
	var personality:Dictionary=target.resident_personality() if target.has_method("resident_personality") else {}
	if not personality.is_empty() and clip not in ["walk","greet"] and progress<0:
		var ratio:float=float(spec.get("worldHeight",42))/108.0
		var anchor:=Vector2(float(spec.anchor[0]),float(spec.anchor[1]))
		var head_pivot:Vector2=(proportions(Vector2(64,51),profile(actor),direction)-anchor)*ratio
		for i:int in next_vertices.size():
			var source:=Vector2(XS[i%XS.size()],YS[i/XS.size()]);var upper:float=1.0-smoothstep(86,116,source.y)
			var head_weight:float=1.0-smoothstep(46,57,source.y)
			var turn:float=float(personality.get("head",0))
			var point:Vector2=next_vertices[i]
			point=point.lerp(head_pivot+(point-head_pivot).rotated(turn),head_weight)
			point.x+=float(personality.get("stance",0))*upper*.35+float(personality.get("shoulder",0))*upper
			var outer:float=smoothstep(10,21,absf(source.x-64))*smoothstep(51,64,source.y)*(1-smoothstep(88,98,source.y))
			point.y+=float(personality.get("arm_near" if source.x>=64 else "arm_far",0))*outer*8
			next_vertices[i]=point
	var previous_clip:=str(target.get_meta("resident_clip",clip))
	var previous_direction:=str(target.get_meta("resident_direction",direction))
	if previous_clip!=clip and previous_direction==direction:
		target.set_meta("resident_blend_from",target.get_meta("resident_vertices",vertices))
		target.set_meta("resident_blend_start",time)
	if previous_direction!=direction:target.remove_meta("resident_blend_from")
	target.set_meta("resident_clip",clip);target.set_meta("resident_direction",direction)
	var from:PackedVector2Array=target.get_meta("resident_blend_from",PackedVector2Array())
	var blend:=smoothstep(0,.13,maxf(0,time-float(target.get_meta("resident_blend_start",time))))
	if from.size()==next_vertices.size() and blend<1:
		for i in next_vertices.size():next_vertices[i]=from[i].lerp(next_vertices[i],blend)
	elif not from.is_empty():target.remove_meta("resident_blend_from")
	var work:Dictionary=target.resident_work_contact() if target.has_method("resident_work_contact") else {}
	if not work.is_empty() and clip in ["build","read","steam","care","pack"]:
		var near_x:=49.0 if direction=="left" else 79.0
		var ratio:=float(spec.get("worldHeight",42))/108.0
		var anchor:=Vector2(float(spec.anchor[0]),float(spec.anchor[1]))
		var hand:Vector2=(proportions(Vector2(near_x,86),profile(actor),direction)-anchor)*ratio
		var wanted:Vector2=(target as Node2D).to_local(work.target)
		var correction:Vector2=(wanted-hand).limit_length(2.0)*(.55+.45*sin(time*2.2)*sin(time*2.2))
		for i in next_vertices.size():
			var source:=Vector2(XS[i%XS.size()],YS[i/XS.size()])
			var arm_weight:=smoothstep(7,18,absf(source.x-64))*smoothstep(52,70,source.y)*(1.0-smoothstep(89,100,source.y))
			var near_arm:bool=source.x<64 if direction=="left" else source.x>=64
			if near_arm:next_vertices[i]+=correction*arm_weight
		target.set_meta("resident_work_hand",next_vertices[6*XS.size()+(3 if direction=="left" else 7)]);target.set_meta("resident_work_target",wanted)
	if work.is_empty():
		if target.has_meta("resident_work_hand"):target.remove_meta("resident_work_hand")
		if target.has_meta("resident_work_target"):target.remove_meta("resident_work_target")
	if next_vertices!=vertices:
		mesh=_mesh({"vertices":next_vertices,"uvs":mesh.get_meta("uvs"),"indices":mesh.get_meta("indices")})
	target.set_meta("resident_vertices",next_vertices)
	# Draw commands keep the mesh alive even after eviction from the shared cache.
	target.set_meta("resident_mesh_ref",mesh)
	target.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var light:Dictionary=target.actor_light if target.has_method("resident_motion") else preload("res://scripts/actor_lighting.gd").sample(target)
	preload("res://scripts/actor_lighting.gd").shadow(target,light)
	target.draw_mesh(mesh,texture)
	return true

static func _mesh(data:Dictionary)->ArrayMesh:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_TEX_UV]=data.uvs;arrays[Mesh.ARRAY_INDEX]=data.indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.set_meta("vertices",data.vertices);result.set_meta("uvs",data.uvs);result.set_meta("indices",data.indices)
	return result
