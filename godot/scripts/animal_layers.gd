extends RefCounted
## Texture components are immutable. All articulation reads a shared transient sample.
static var catalog:Dictionary={}
static var parts:Dictionary={}
static var textures:Dictionary={}
static var alpha_material:ShaderMaterial
static var meshes:Dictionary={}
static var vertices:=PackedVector3Array()
static var uvs:=PackedVector2Array()
static var colors:=PackedColorArray()
static var indices:=PackedInt32Array()
static func data()->Dictionary:
	if catalog.is_empty() and FileAccess.file_exists("res://data/animal_layers.json"):
		catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/animal_layers.json"))
	return catalog
static func component(species:String,row:int,column:int)->Dictionary:
	var key:String=species+"/"+str(row)+"/"+str(column)
	if parts.has(key):return parts[key]
	var entry:Dictionary=data().get(species,{})
	if entry.is_empty():return {}
	if not textures.has(species):
		var source:Image=Image.load_from_file(str(entry.path))
		if source==null:return {}
		var texture:=ImageTexture.create_from_image(source)
		textures[species]={"image":source,"texture":texture}
	var image:Image=textures[species].image
	var region:Variant=entry.get("regions",{}).get(str(row)+":"+str(column))
	if region is Array:
		parts[key]={"texture":textures[species].texture,"rect":Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))}
		return parts[key]
	var cell:=Vector2i(image.get_width()/int(entry.get("columns",6)),image.get_height()/int(entry.rows))
	var origin:=Vector2i(column*cell.x,row*cell.y)
	var low:=cell;var high:=Vector2i.ZERO
	for y:int in range(3,cell.y-3):
		for x:int in range(3,cell.x-3):
			if image.get_pixelv(origin+Vector2i(x,y)).a>.8:
				low=low.min(Vector2i(x,y));high=high.max(Vector2i(x+1,y+1))
	if high.x<=low.x or high.y<=low.y:return {}
	parts[key]={"texture":textures[species].texture,"rect":Rect2(Vector2(origin+low),Vector2(high-low))}
	return parts[key]
static var rig_samples:Dictionary={}
static func named(type_id:String,row:int,name:String)->Dictionary:
	var entry:Dictionary=data().get(type_id,{})
	if not entry.get("parts",{}).has(name):return {}
	if name in entry.get("swapSideParts",[]) and row%4 in [1,2]:row=(2 if row%4==1 else 1)+(4 if row>=4 else 0)
	return component(type_id,row,int(entry.parts[name]))
static func append_piece(part:Dictionary,at:Vector2,size:Vector2,angle:float=0,pivot:Vector2=Vector2(.5,.5),tint:Color=Color.WHITE,crop:Rect2=Rect2(0,0,1,1),flip:bool=false)->void:
	if part.is_empty() or size.x<=0 or size.y<=0:return
	var n:int=vertices.size();var texture_size:Vector2=part.texture.get_size()
	for uv:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		var local:Vector2=(uv-pivot)*size;local.x*=(-1 if flip else 1)
		var point:Vector2=at+local.rotated(angle);vertices.append(Vector3(point.x,point.y,0))
		uvs.append((part.rect.position+(crop.position+uv*crop.size)*part.rect.size)/texture_size);colors.append(tint)
	indices.append_array(PackedInt32Array([n,n+1,n+2,n,n+2,n+3]))
static func piece(_c:CanvasItem,type_id:String,row:int,col:int,at:Vector2,size:Vector2,angle:float=0,pivot:Vector2=Vector2(.5,.5),tint:Color=Color.WHITE)->void:
	append_piece(component(type_id,row,col),at,size,angle,pivot,tint)
static func joint(root:Vector2,foot:Vector2,l1:float,l2:float,bend:float,side:bool=true)->Dictionary:
	var delta:Vector2=foot-root;var reach:float=clampf(delta.length(),.001,l1+l2-.001)
	var direction:Vector2=delta.normalized() if delta.length()>.001 else Vector2.DOWN
	var end:Vector2=root+direction*reach;var projected:float=(l1*l1+reach*reach-l2*l2)/(2.0*reach)
	var lift:float=sqrt(maxf(0,l1*l1-projected*projected))
	var r3:=Vector3(root.x,root.y,0);var e3:=Vector3(end.x,end.y,0)
	var normal:=Vector3(-direction.y,direction.x,0) if side else Vector3(0,0,1)
	var mid:Vector3=r3+Vector3(direction.x,direction.y,0)*projected+normal*lift*bend
	return {"root":root,"joint":Vector2(mid.x,mid.y+mid.z*.10),"foot":end,"root3d":r3,"joint3d":mid,"foot3d":e3,"upper":l1,"lower":l2}
static func ribbon(part:Dictionary,bone:Dictionary,width:float,tint:Color)->void:
	if part.is_empty():return
	var n:int=vertices.size();var a:Vector2=bone.root;var m:Vector2=bone.joint;var z:Vector2=bone.foot
	var d1:Vector2=(m-a).normalized();var d2:Vector2=(z-m).normalized();var mid_normal:Vector2=(d1.orthogonal()+d2.orthogonal()).normalized()
	var rows:Array=[[a-d1*.8,d1.orthogonal(),0.0],[m,mid_normal,.5],[z+d2*.3,d2.orthogonal(),1.0]]
	for row:Array in rows:
		for sign_i:int in [-1,1]:
			var at:Vector2=Vector2(row[0])+Vector2(row[1])*float(sign_i)*width*.5
			vertices.append(Vector3(at.x,at.y,0));uvs.append((part.rect.position+Vector2(0 if sign_i<0 else 1,float(row[2]))*part.rect.size)/Vector2(part.texture.get_size()));colors.append(tint)
	indices.append_array(PackedInt32Array([n,n+1,n+3,n,n+3,n+2,n+2,n+3,n+5,n+2,n+5,n+4]))
static func neck_skin(part:Dictionary,a:Vector2,z:Vector2,root_width:float,head_width:float,tint:Color,source_x:float)->void:
	var delta:Vector2=z-a;var normal:Vector2=delta.normalized().orthogonal();var n:int=vertices.size()
	var cross:Array=[-1.0,-.84,0.0,.84,1.0]
	for y:int in 5:
		var progress:float=float(y)/4;var middle:Vector2=a.lerp(z,progress);var half_width:float=lerpf(root_width,head_width,progress)*.5
		for x:int in 5:
			var point:Vector2=middle+normal*float(cross[x])*half_width;vertices.append(Vector3(point.x,point.y,0))
			uvs.append((part.rect.position+Vector2(source_x+float(cross[x])*.065,.23+progress*.20)*part.rect.size)/Vector2(part.texture.get_size()))
			var shade:float=1.0-absf(float(cross[x]))*.13;var ink:Color=tint*Color(shade,shade,shade);ink.a*=0 if x in [0,4] else 1;colors.append(ink)
	for y:int in 4:
		for x:int in 4:
			var index:int=n+y*5+x;indices.append_array(PackedInt32Array([index,index+1,index+6,index,index+6,index+5]))
static func anatomical_neck(part:Dictionary,head_root:Vector2,shoulder:Vector2,facing:String,tint:Color)->void:
	var top:=Vector2(.14,.07) if facing=="left" else Vector2(.86,.07) if facing=="right" else Vector2(.5,.04)
	var base:=Vector2(.53,.94)
	var source:Vector2=(base-top)*part.rect.size;var target:Vector2=shoulder-head_root
	var scale:float=target.length()/maxf(1,source.length())
	append_piece(part,head_root,part.rect.size*scale,target.angle()-source.angle(),top,tint)
static func limb(part:Dictionary,a:Vector2,z:Vector2,width:float,tint:Color,crop:Rect2)->void:
	var delta:Vector2=z-a;var overlap:float=minf(width*.5,1.8)
	var start:Vector2=a-delta.normalized()*overlap
	append_piece(part,start,Vector2(width,delta.length()+overlap*2),delta.angle()-PI/2,Vector2(.5,0),tint,crop)
static func draw_component_trial(c:CanvasItem,a:Dictionary,v:Dictionary,at:Vector2,clock:float)->bool:
	var s:Node=(Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var type_id:String=str(a.get("type",""));var entry:Dictionary=data().get(type_id,{})
	if entry.is_empty():return false
	var profile:Dictionary=preload("res://scripts/animal_species.gd").profile(type_id)
	if profile.is_empty():return false
	var id:String=str(a.get("id","pet"));var sample:Dictionary=s.animal_behavior.samples.get(id,{})
	var facing:String=str(sample.get("direction",v.get("direction","down")));var direction:int=["down","left","right","up"].find(facing)
	if direction<0:direction=0
	var young:bool=bool(v.get("young",false));var row:int=int(entry.get("directionRows",[0,1,2,3])[direction])+(4 if young else 0)
	var torso:Dictionary=named(type_id,row,"body");var head_part:Dictionary=named(type_id,row,"head")
	if torso.is_empty() or head_part.is_empty():return false
	if alpha_material==null:alpha_material=ShaderMaterial.new();alpha_material.shader=load("res://art/shaders/animal_component.gdshader")
	c.material=alpha_material
	var adult:float=float(s.system_catalog.ranch.species.get(type_id,{}).get("adult",1));var growth:float=clampf(float(a.get("age",adult))/adult,0,1)
	growth=growth*growth*(3.0-2.0*growth)
	var h:float=float(profile.height)*lerpf(float(profile.youngHeight),1.0,growth) if young else float(profile.height)
	var side:bool=facing in ["left","right"];var sign_x:float=-1.0 if facing=="left" else 1.0
	var bird:bool=str(profile.family)=="bird";var phase:float=float(sample.get("phase",0))*TAU
	var weight:float=float(sample.get("weight",0));var state:String=str(sample.get("action","idle"))
	var reduced:bool=str(s.visual_fx.get("motion","full"))=="reduced"
	var visual_clock:float=float(sample.get("clock",clock));var t:float=visual_clock+float(sample.get("seed",posmod(id.hash(),10007)))*.013
	var sleep:float=float(sample.get("sleep",1 if bool(v.get("sleepy",false)) else 0))
	if state=="sit":sleep=maxf(sleep,.66)
	var swim:float=float(sample.get("water_blend",1 if str(sample.get("motion_mode","ground"))=="swim" else 0))
	var coat:String=str(a.get("appearance",{}).get("coat",a.get("breed","local")))
	var shape:Array=profile.coatShapes.get(coat,[1,1]);var leg_h:float=h*float(profile.leg)*lerpf(float(profile.youngLeg),1,growth)
	var body_h:float=h*float(profile.body)*float(shape[1]);var ratio:float=float(torso.rect.size.x)/float(torso.rect.size.y)
	var body_w:float=body_h*clampf(ratio,.88 if not side else 1.25,1.7 if not side else 2.9)*float(shape[0])
	var head_h:float=h*float(profile.head)*lerpf(float(profile.youngHead),1,growth);var head_w:float=head_h*head_part.rect.size.x/head_part.rect.size.y
	var breath:float=0 if reduced else sin(t*2.0)*h*.0035
	var hop:float=maxf(0,sin(phase))*h*.06*weight if type_id=="rabbit" else 0.0
	var bob:float=sin(phase*2)*h*.007*weight if not reduced and not bird else 0.0
	var body:Vector2=at+Vector2(0,lerpf(-leg_h-body_h*.5,-body_h*.46,sleep)-hop+breath+bob+swim*leg_h*.65)
	var tint:Color=Color(.84,.80,.73) if bool(v.get("dirty",false)) else Color(.93,.95,.90) if bool(v.get("sick",false)) else Color.WHITE
	if coat=="hardy":tint=tint*Color(.80,.84,.86)
	elif coat=="productive":tint=tint*Color(1.0,.95,.83)
	preload("res://scripts/ground_style.gd").shadow(c,at+Vector2(0,1),body_w*.45,h*.045)
	var animating:bool=weight>.01 or state in ["feed","drink","pet","clean","play","wash","preen","stretch"] or sleep>.01 and sleep<.99
	var hz:int=24 if animating else 6
	var cache_id:String=id+"/"+type_id+str(young);var stamp:String=str([floori(visual_clock*hz),row,state,tint,roundi(sleep*24),roundi(weight*16),roundi(swim*12),roundi(growth*32),coat,at])
	if str(meshes.get(cache_id,{}).get("stamp",""))==stamp:c.draw_mesh(meshes[cache_id].mesh,textures[type_id].texture);return true
	vertices=PackedVector3Array();uvs=PackedVector2Array();colors=PackedColorArray();indices=PackedInt32Array()
	var mirrored:bool=entry.get("mirrorRows",[]).has(row)
	var head_pitch:float=float(sample.get("head_pitch",0));var turn:float=sin(float(sample.get("turn",1))*PI)
	var head:Vector2=body+Vector2(sign_x*(body_w*.53+float(profile.neck)*h*.45) if side else 0,-body_h*.20-float(profile.neck)*h-head_h*.40)
	var eating:bool=bool(v.get("eating",false)) or state in ["feed","graze","peck","root","browse","drink","sniff"]
	var nod:float=(.5+.5*sin(t*4.2))*h*.035 if eating else 0
	head+=Vector2(sign_x*h*.035 if side and eating else 0,h*head_pitch*.07+nod)
	if not reduced:head.x+=sign_x*turn*h*.018;head.y+=sin(t*1.5)*h*.002
	if state=="stretch" and not reduced:head.x+=sign_x*h*.06;body.x-=sign_x*h*.025
	var neck:Dictionary=named(type_id,row,"neck")
	var tail:Dictionary=named(type_id,row,"tail");var tail_at:Vector2=body+Vector2(-sign_x*body_w*.43 if side else 0,0)
	if facing!="up":append_piece(tail,tail_at,Vector2(h*.22,h*.30),0 if reduced else sin(t*2.2)*.09,Vector2(.5,.15),tint,Rect2(0,0,1,1),mirrored)
	var count:int=2 if bird else 4;var joints:Array=[];var phases:Array=profile.gait
	for i:int in count:
		var phase_i:float=phase+float(phases[i])*TAU
		var x:float=(i-.5)*body_w*.34 if bird else ([-.33,-.29,.28,.34][i]*body_w*sign_x if side else [-.17,.17,-.28,.28][i]*body_w)
		var root_limb:Vector2=body+Vector2(x,body_h*.48)
		var foot:Vector2=at+Vector2(x+cos(phase_i)*h*.045*weight,-maxf(0,sin(phase_i))*h*.045*weight-hop)
		if sample.get("foot_offsets",[]).size()>i:foot=at+Vector2(x,-hop)+Vector2(sample.foot_offsets[i])
		if not side and i<2 and not bird:foot.y-=h*.025
		if sleep>.1:foot=foot.lerp(body+Vector2(x,body_h*.35),sleep)
		var j:Dictionary=joint(root_limb,foot,leg_h*.52,leg_h*.53,(-sign_x if i<2 else sign_x) if not bird else sign_x,side)
		j.index=i;j.width=h*(.115 if not bird else .07);j.part=named(type_id,row,"front_leg" if bird or i>=2 else "hind_leg");j.tint=tint.darkened(.10 if i%2==0 else 0);joints.append(j)
	# Continuous skin strips share the knee vertices; the torso masks embedded limb roots.
	for j:Dictionary in joints:
		if swim>.6 or sleep>.90:continue
		var part:Dictionary=j.part
		if type_id=="goose":part=part.duplicate();part.rect=Rect2(part.rect.position,Vector2(part.rect.size.x,part.rect.size.y*.78))
		ribbon(part,j,float(j.width),j.tint)
	append_piece(torso,body,Vector2(body_w,body_h),0,Vector2(.5,.5),tint,Rect2(0,0,1,1),mirrored)
	var shoulder:Vector2=body+Vector2(sign_x*body_w*.32 if side else 0,-body_h*.18)
	var skull_root:Vector2=head+Vector2(-sign_x*head_w*.23 if side else 0,head_h*.24)
	neck_skin(torso,shoulder,skull_root,body_h*(.65 if not bird else .52),head_h*.55,tint,.72 if side and sign_x>0 else .28 if side else .5)
	if not neck.is_empty():
		var root_neck:Vector2=body+Vector2(sign_x*body_w*.30 if side else 0,-body_h*.15)
		var neck_top:Vector2=head+Vector2(-sign_x*head_w*.12 if side else 0,head_h*.34)
		anatomical_neck(neck,neck_top,root_neck,facing,tint)
		if bird:append_piece(neck,body+Vector2(sign_x*body_w*.28 if side else 0,-body_h*.43),Vector2(body_w*.38,body_h*.30),0,Vector2(.5,.5),tint,Rect2(0,.70,1,.30))
	for j:Dictionary in joints:
		if swim>.6:continue
		if sleep>.90 and int(j.index)%2==1:append_piece(j.part,at+Vector2(float(j.root.x-at.x),0),Vector2(float(j.width)*1.1,h*.065),0,Vector2(.5,1),j.tint,Rect2(0,.72,1,.28))
		if bird and swim<.6 and sleep<.9:
			var web:Dictionary=named(type_id,row,"foot")
			if not web.is_empty():append_piece(web,j.foot,Vector2(h*.16,h*.085),0,Vector2(.5,1),j.tint)
	if facing=="up":append_piece(tail,tail_at,Vector2(h*.22,h*.30),0 if reduced else sin(t*2.2)*.09,Vector2(.5,.15),tint)
	if bird:
		var wing:Dictionary=named(type_id,row,"wing")
		append_piece(wing,body+Vector2(sign_x*body_w*.08,body_h*.04),Vector2(body_w*.72,body_h*.70),sin(t*3)*.08 if state=="preen" and not reduced else 0,Vector2(.5,.5),tint)
	var head_angle:float=0 if reduced else sin(t*1.7)*.014+turn*sign_x*.025
	append_piece(head_part,head,Vector2(head_w,head_h),head_angle,Vector2(.5,.5),tint,Rect2(0,0,1,1),mirrored)
	var ear:Dictionary=named(type_id,row,"ear")
	if not ear.is_empty():
		for side_i:int in (1 if side else 2):
			var ear_x:float=sign_x*head_w*.12 if side else (-1 if side_i==0 else 1)*head_w*.27
			append_piece(ear,head+Vector2(ear_x,-head_h*.42),Vector2(head_w*.22,head_h*(.28 if type_id=="horse" else .45)),0 if reduced else sin(t*2.1+side_i)*.035,Vector2(.5,.88),tint)
	var jaw:Dictionary=named(type_id,row,"jaw")
	if not jaw.is_empty() and eating:
		append_piece(jaw,head+Vector2(sign_x*head_w*.14 if side else 0,head_h*.25+sin(t*6)*h*.008),Vector2(head_w*.58,head_h*.23),head_angle,Vector2(.5,.5),tint)
	var blink:bool=sleep>.65 or fposmod(t,4.3+int(sample.get("seed",0))%4)<.13
	if blink:
		var closed:Dictionary=named(type_id,row,"blink")
		for eye:Array in profile.eyes.get(facing,[]):
			var crop:=Rect2(float(eye[0])-.14,float(eye[1])-.10,.28,.20)
			var local:Vector2=(crop.get_center()-Vector2(.5,.5))*Vector2(head_w,head_h)
			append_piece(closed,head+local.rotated(head_angle),Vector2(head_w,head_h)*crop.size,head_angle,Vector2(.5,.5),tint,Rect2(1.0-crop.end.x,crop.position.y,crop.size.x,crop.size.y) if mirrored else crop,mirrored)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if meshes.size()>=256:meshes.erase(meshes.keys()[0])
	meshes[cache_id]={"stamp":stamp,"mesh":mesh};rig_samples[id]={"joints":joints,"body":body,"head":head,"height":h,"water":swim,"young":young}
	c.draw_mesh(mesh,textures[type_id].texture);return true

static func draw(c:CanvasItem,a:Dictionary,v:Dictionary,at:Vector2,clock:float)->bool:
	return load("res://scripts/animal_whole_model.gd").draw(c,a,v,at,clock)
