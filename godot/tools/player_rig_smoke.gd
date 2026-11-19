extends SceneTree
const RIG := preload("res://scripts/player_rig.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 12:printerr("FAIL ",label)
func run() -> void:
	await process_frame
	var state: Node = root.get_node("GameState");state.set_process(false)
	var saved: Dictionary = state._make_save_data().duplicate(true)
	var motion := RIG.new()
	motion.sample(Vector2(30,0),.15);check(motion.stride_phase>.20 and motion.stride_phase<=.33,"distance-owned adaptive stride stays within the 2.2 Hz cap")
	var phase: float = motion.stride_phase;motion.advance(1.0)
	check(is_equal_approx(motion.stride_phase,phase),"Render clock cannot advance gait")
	var second := RIG.new()
	for i in range(6):second.sample(Vector2(5,0),.025)
	check(is_equal_approx(second.stride_phase,motion.stride_phase),"Gait independent of sample frequency")
	motion.sample(Vector2.ZERO,.1);motion.advance(.06)
	check(motion.walk_weight>0 and motion.walk_weight<1,"Stop blends rather than snapping")
	motion.advance(.06);check(is_zero_approx(motion.walk_weight),"Stop settles in 0.12 seconds")
	motion.sample(Vector2(500,0),.016)
	check(is_zero_approx(motion.stride_phase) and is_zero_approx(motion.walk_weight),"Teleport resets pose without footsteps")
	var visual: Script = load("res://scripts/painted_wardrobe.gd")
	var profile := {"shirt":0,"skin":0,"hair":2,"hairColor":0,"hat":true,"bag":true,"outfit":"field"}
	var poses := 0;var folded := 0;var triangles := 0;var finite := true
	for direction: String in ["down","left","right","up"]:
		var frame: Dictionary = RIG.solve(profile,{},"field",direction,"idle",0,-1,{},true)
		var roles: Array = []
		for row: Dictionary in frame.commands:roles.append(row.get("role",""))
		check(roles.find("bag")>roles.find("torso") if direction=="up" else roles.find("bag")<roles.find("torso"),"Bag follows body depth "+direction)
		for clip: String in visual.CLIPS:
			var grounded := true;var hands := true
			for pack: String in ["field","apron","traveler","festival","rain","cold"]:
				for progress: float in [0.0,.1,.25,.5,.7,.9,1.0]:
					var solved: Dictionary = RIG.solve(profile,{},pack,direction,clip,progress*1.3,progress,{},true)
					poses += 1
					if clip not in ["bike","ride"]:
						for foot: Vector2 in solved.feet:grounded=grounded and foot.y<=.001
						grounded=grounded and absf(maxf(solved.feet[0].y,solved.feet[1].y))<.001
					for row: Dictionary in solved.commands:
						finite=finite and row.at.is_finite() and row.size.is_finite() and is_finite(float(row.angle))
						if row.get("role","")=="tool":hands=hands and row.at.distance_to(solved.sockets.hand)<.001
						if not row.has("joints"):continue
						var geometry: Dictionary=RIG.limb_mesh(row,Rect2(0,0,128,128),Vector2(128,128))
						for point: Vector2 in geometry.vertices:finite=finite and point.is_finite()
						for i in range(0,geometry.indices.size(),3):
							var a:Vector2=geometry.vertices[geometry.indices[i]];var c:Vector2=geometry.vertices[geometry.indices[i+1]];var d:Vector2=geometry.vertices[geometry.indices[i+2]]
							triangles += 1
							if (c-a).cross(d-a)>.0001:folded += 1
			check(grounded,"Supporting foot stays grounded "+direction+"/"+clip)
			check(hands,"Tool stays in hand "+direction+"/"+clip)
	var continuous := true
	for direction: String in ["down","left","right","up"]:
		for clip: String in ["hoe","dig","chop","water","seed","harvest","gather"]:
			var previous:Dictionary={}
			for step in range(101):
				var f:Dictionary=RIG.solve(profile,{},"field",direction,clip,float(step)/100,float(step)/100,{},true)
				if not previous.is_empty():
					continuous=continuous and f.sockets.hand.distance_to(previous.sockets.hand)<3.0 and f.sockets.head.distance_to(previous.sockets.head)<1.0
				previous=f
	check(continuous,"Fine-grained action samples remain continuous at every phase boundary")
	check(finite,"All hierarchy and skinning coordinates finite")
	check(folded==0,"Continuous limb meshes never invert: "+str(folded))
	var quiet_a: Dictionary = RIG.solve(profile,{},"field","right","idle",0,-1,{},false)
	var quiet_b: Dictionary = RIG.solve(profile,{},"field","right","idle",90,-1,{},false)
	check(quiet_a==quiet_b,"Reduced motion freezes decorative movement")
	check(state._make_save_data()==saved,"Rig solving never changes saved gameplay")
	print("PLAYER_RIG: %d passed, %d failed; %d poses; %d triangles; %d inverted"%[passed,failed,poses,triangles,folded])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
