extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		printerr("Five-stage checks require isolated TEMP and APPDATA");quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false)
	var art:Script=load("res://scripts/character_art.gd");var model:Script=load("res://scripts/canonical_character.gd")
	var count:=0;var poses:=0;var inverted:=0
	for id:String in art.data().actors:
		if id=="player":continue
		var identity:Dictionary=model.profile(id);check(not identity.is_empty(),"identity profile "+id);count+=1
		var actor:Dictionary=art.data().actors[id];var spec:Dictionary=actor.clips.idle
		for clip:String in actor.clips:
			for direction:String in ["down","up","left","right"]:
				for phase in range(9):
					var frame:Dictionary=model.geometry(spec,clip,direction,phase*.1,phase/8.0,true,identity)
					var vertices:PackedVector2Array=frame.vertices;var indices:PackedInt32Array=frame.indices
					for i in range(0,indices.size(),3):
						var a:=vertices[indices[i]];var b:=vertices[indices[i+1]];var c:=vertices[indices[i+2]]
						if not is_finite(a.x) or (b-a).cross(c-a)>=0:inverted+=1
					poses+=1
	check(count==24,"exactly 24 original resident identities")
	check(inverted==0,"no inverted or degenerate resident triangles")
	var target:=Node2D.new();root.add_child(target)
	var light:Script=load("res://scripts/actor_lighting.gd")
	target.position=Vector2(2793,1698);state.current_interior="";state.minutes=720
	var noon:Dictionary=light.sample(target);check(float(noon.warm)==0,"lamps inactive at noon")
	state.minutes=1260;var night:Dictionary=light.sample(target);check(float(night.warm)>.9,"night lamp warms nearby actor")
	target.position=Vector2(3800,3800);var far:Dictionary=light.sample(target);check(float(far.warm)<.01,"lamp distance filtering")
	check(float(far.ambient.r)>.85 and float(far.ambient.b)>=1,"night uses color balance without duplicate exposure darkening")
	for i in range(700):target.position=Vector2(i*13,3000);light.sample(target)
	check(light.samples.size()<=512,"bounded lighting sample cache")
	state.current_interior="review-room";var indoor:Dictionary=light.sample(target)
	check(float(indoor.ambient.r)>.98 and float(indoor.ambient.g)>.98,"interior avoids duplicate night darkening")
	print("RESIDENT_LIGHT: %d passed, %d failed; identities=%d poses=%d inverted=%d"%[passed,failed,count,poses,inverted])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
