extends RefCounted
## A coherent painted surface, continuously skinned. Drawing never advances simulation.
static var catalog:Dictionary={}
static var textures:Dictionary={}
static var meshes:Dictionary={}
static var actors:Dictionary={}
static var metrics:Dictionary={"mesh_builds":0,"material_builds":0,"draws":0}
static func data()->Dictionary:
	if catalog.is_empty() and FileAccess.file_exists("res://data/animal_whole_models.json"):catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/animal_whole_models.json"))
	return catalog
static var outlines:Dictionary={}
static func _outline(entry:Dictionary,frame:Dictionary)->PackedVector2Array:
	var key:String=str(entry.path)+str(frame.rect)
	if outlines.has(key):return outlines[key]
	# Native silhouette geometry isolates this connected animal from nearby atlas figures.
	# The source image remains intact; no sprite pixels are rewritten.
	var source:Image=Image.load_from_file(str(entry.path))
	var crop:Image=source.get_region(Rect2i(int(frame.rect[0]),int(frame.rect[1]),int(frame.rect[2]),int(frame.rect[3])))
	var bitmap:=BitMap.new();bitmap.create_from_image_alpha(crop,.80)
	var candidates:Array[PackedVector2Array]=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,crop.get_size()),.75)
	var best:=PackedVector2Array();var area:float=0
	for polygon:PackedVector2Array in candidates:
		var candidate_area:float=0
		for i:int in polygon.size():candidate_area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(candidate_area)>area:area=absf(candidate_area);best=polygon
	outlines[key]=best;return best
static func _mesh(entry:Dictionary,frame:Dictionary,ratio:float,key:String)->ArrayMesh:
	if meshes.has(key):return meshes[key]
	var baked:String="res://data/animal_meshes/"+key.replace("/","-")+".res"
	if ResourceLoader.exists(baked):
		var ready:ArrayMesh=load(baked) as ArrayMesh
		if ready!=null:
			if meshes.size()>=256:meshes.erase(meshes.keys()[0])
			meshes[key]=ready;return ready
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var rect:=Rect2(float(frame.rect[0]),float(frame.rect[1]),float(frame.rect[2]),float(frame.rect[3]));var anchor:=Vector2(float(frame.anchor[0]),float(frame.anchor[1]))
	var polygon:PackedVector2Array=_outline(entry,frame)
	# Uniform cell boundaries keep neighbouring deformed triangles watertight.
	var cell:float=maxf(5,float(frame.rect[3])*.075)
	for y:int in ceili(rect.size.y/cell):
		for x:int in ceili(rect.size.x/cell):
			var p0:=Vector2(x*cell,y*cell);var p1:=Vector2(minf(rect.size.x,(x+1)*cell),minf(rect.size.y,(y+1)*cell))
			var tile:=PackedVector2Array([p0,Vector2(p1.x,p0.y),p1,Vector2(p0.x,p1.y)])
			for clipped:PackedVector2Array in Geometry2D.intersect_polygons(tile,polygon):
				var local_triangles:PackedInt32Array=Geometry2D.triangulate_polygon(clipped)
				for i:int in local_triangles:
					var point:Vector2=clipped[i];var at:Vector2=(point-anchor)*ratio;vertices.append(Vector3(at.x,at.y,0));uv.append((rect.position+point)/Vector2(float(entry.size[0]),float(entry.size[1])))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if meshes.size()>=256:meshes.erase(meshes.keys()[0])
	meshes[key]=mesh;metrics.mesh_builds+=1;return mesh
static func _v(point:Array,anchor:Vector2,ratio:float)->Vector2:return (Vector2(float(point[0]),float(point[1]))-anchor)*ratio
static func draw(c:CanvasItem,animal:Dictionary,appearance:Dictionary,at:Vector2,clock:float)->bool:
	var type_id:String=str(animal.get("type",""));var entry:Dictionary=data().get(type_id,{})
	if entry.is_empty():return false
	var animal_texture:Texture2D=preload("res://scripts/character_art.gd").texture(str(entry.path))
	if animal_texture==null:return false
	var state:Node=(Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var profile:Dictionary=preload("res://scripts/animal_species.gd").profile(type_id);var id:String=str(animal.get("id","pet"));var sample:Dictionary=state.animal_behavior.samples.get(id,{})
	var facing:String=str(sample.get("direction",appearance.get("direction","down")));var direction:int=["down","left","right","up"].find(facing)
	if direction<0:direction=0
	var young:bool=bool(appearance.get("young",false));var row:int=direction+(4 if young else 0)
	var action:String=str(sample.get("action","sleep" if bool(appearance.get("sleepy",false)) else "feed" if bool(appearance.get("eating",false)) else "idle"))
	var sleep:float=float(sample.get("sleep",1 if action=="sleep" else 0));var pose:int=5 if sleep>.80 else 4 if sleep>.22 else 3 if action in ["feed","graze","peck","root","browse","drink","sniff"] and float(sample.get("elapsed",1))>.25 else 4 if action in ["sit","stretch","wash"] else 0
	# Keep the rear silhouette facing away; generated feeding art can expose a face.
	if facing=="up" and pose==3:pose=0
	if float(sample.get("weight",0))>.05:pose=0
	var frame:Dictionary=entry.frames.get(str(row)+":"+str(pose),{})
	if frame.is_empty():return false
	var reference:Dictionary=entry.frames[str(row)+":0"]
	var adult:float=float(state.system_catalog.ranch.species.get(type_id,{}).get("adult",1));var growth:float=clampf(float(animal.get("age",adult))/adult,0,1);growth=growth*growth*(3-2*growth)
	var height:float=float(profile.height)*(lerpf(.62,1,growth) if young else 1.0);var ratio:float=height/float(reference.rect[3]);var anchor:=Vector2(float(frame.anchor[0]),float(frame.anchor[1]))
	var actor_key:int=c.get_instance_id();var cached:Dictionary=actors.get(actor_key,{})
	if cached.is_empty():
		var material:=ShaderMaterial.new();material.shader=load("res://data/village_media/animal_whole_skin.gdshader");cached={"material":material,"stamp":""};actors[actor_key]=cached;metrics.material_builds+=1
		c.tree_exited.connect(release_actor.bind(actor_key),CONNECT_ONE_SHOT)
	var material:ShaderMaterial=cached.material;c.material=material
	var visual_clock:float=float(sample.get("clock",clock));var weight:float=float(sample.get("weight",0));var coat:String=str(animal.get("appearance",{}).get("coat",animal.get("breed","local")))
	var stamp:String=str([id,roundi(float(sample.get("turn",1))*24),roundi(float(sample.get("water_blend",0))*24),floori(visual_clock*(24 if weight>.01 or action!="idle" else 6)),type_id,row,pose,roundi(growth*64),coat,appearance.get("dirty",false),appearance.get("sick",false)])
	var key:String=type_id+"/"+str(row)+"/"+str(pose)
	var mesh:ArrayMesh=_mesh(entry,frame,1.0,key)
	if str(cached.stamp)!=stamp:
		cached.stamp=stamp
		material.set_shader_parameter("model_scale",ratio)
		var roots:=PackedVector2Array();var tips:=PackedVector2Array();var offsets:=PackedVector2Array();var knees:=PackedVector2Array()
		var count:int=mini(4,frame.get("legs",[]).size()) if pose==0 else 0
		for i:int in 4:
			var root_point:=Vector2.ZERO;var foot:=Vector2.ZERO;var offset:=Vector2.ZERO;var knee:=Vector2.ZERO
			if i<count:
				root_point=_v(frame.legs[i].root,anchor,ratio);foot=_v(frame.legs[i].tip,anchor,ratio)
				var phase_index:int=i if count>=4 else i*2 if profile.gait.size()==4 else i
				if sample.get("foot_offsets",[]).size()>phase_index:offset=Vector2(sample.foot_offsets[phase_index])
				else:var phase:float=float(sample.get("phase",0))*TAU+float(profile.gait[mini(phase_index,profile.gait.size()-1)])*TAU;offset=Vector2(cos(phase)*height*.035,-maxf(0,sin(phase))*height*.04)*weight
				var length:float=root_point.distance_to(foot)
				var rest:Dictionary=load("res://scripts/animal_layers.gd").joint(root_point,foot,length*.53,length*.53,-1 if i<2 else 1,facing in ["left","right"])
				var moved:Dictionary=load("res://scripts/animal_layers.gd").joint(root_point,foot+offset,length*.53,length*.53,-1 if i<2 else 1,facing in ["left","right"])
				offset=Vector2(moved.foot)-foot;offset=offset.limit_length(height*.065);knee=(Vector2(moved.joint)-Vector2(rest.joint)).limit_length(height*.035)
			roots.append(root_point);tips.append(foot);offsets.append(offset);knees.append(knee)
		material.set_shader_parameter("roots",roots);material.set_shader_parameter("tips",tips);material.set_shader_parameter("foot_offsets",offsets);material.set_shader_parameter("knee_offsets",knees);material.set_shader_parameter("leg_count",count)
		var center:Vector2=_v(frame.core,anchor,ratio);material.set_shader_parameter("body_center",center);material.set_shader_parameter("body_radius",Vector2(height*.28,height*.19));material.set_shader_parameter("head_center",_v(frame.head,anchor,ratio));material.set_shader_parameter("head_radius",height*.20)
		c.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		var reduced:bool=str(state.visual_fx.get("motion","full"))=="reduced";var breath:float=0 if reduced else sin(visual_clock*2+posmod(id.hash(),17))*.006
		material.set_shader_parameter("breath",breath);material.set_shader_parameter("head_angle",0 if reduced else sin(visual_clock*1.5+posmod(id.hash(),11))*.012)
		material.set_shader_parameter("torso_width",(1.025 if coat=="hardy" else 1.0)*(1.0-.025*sin(float(sample.get("turn",1))*PI)))
		material.set_shader_parameter("water",float(sample.get("water_blend",0)));material.set_shader_parameter("height",height);material.set_shader_parameter("visual_clock",visual_clock)
		var tint:=Color(.86,.83,.77) if bool(appearance.get("dirty",false)) else Color(.92,.96,.91) if bool(appearance.get("sick",false)) else Color.WHITE
		if coat=="hardy":tint*=Color(.87,.90,.92)
		elif coat=="productive":tint*=Color(1.0,.98,.89)
		material.set_shader_parameter("coat",tint)
	preload("res://scripts/ground_style.gd").shadow(c,at+Vector2(0,1),float(frame.rect[2])*ratio*.35,height*.045)
	c.draw_mesh(mesh,animal_texture,Transform2D(0,at));metrics.draws+=1
	if actors.size()>256:actors.erase(actors.keys()[0])
	return true

static func release_actor(id:int)->void:
	actors.erase(id)
