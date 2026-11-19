extends SceneTree
const RIG:=preload("res://scripts/player_rig.gd")
const LIGHT:=preload("res://scripts/actor_lighting.gd")
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false)
	var mirrors:=true;var left_counter:=0;var right_counter:=0
	for step in range(120):
		var motion:Dictionary={"sampled":true,"weight":1.0,"phase":step/120.0}
		var left:=RIG.solve(state.appearance,{},"field","left","walk",0,-1,motion)
		var right:=RIG.solve(state.appearance,{},"field","right","walk",0,-1,motion)
		var la:Vector2=left.sockets.hand-left.sockets.shoulder_near
		var ra:Vector2=right.sockets.hand-right.sockets.shoulder_near
		mirrors=mirrors and absf(la.x+ra.x)<.001 and absf(la.y-ra.y)<.001
		var lf:Vector2=left.feet[1];var rf:Vector2=right.feet[1]
		if la.x*(lf.x+1.4)<0:left_counter+=1
		if ra.x*(rf.x-1.4)<0:right_counter+=1
	check(mirrors,"left and right shoulder-to-hand arcs mirror throughout a stride")
	check(left_counter>=95 and right_counter>=95,"arms oppose the corresponding leg in both side views")
	state.current_interior="";state.minutes=1260;state.world_village.houses=[];state.building.layout=[]
	var actor:=Node2D.new();root.add_child(actor)
	var lamp:=Vector2(2793,1698);var worst_jump:=0.0;var worst_error:=0.0;var previous:=-1.0
	for i in range(481):
		actor.position=lamp+Vector2(i*.25,0)
		var value:float=LIGHT.sample(actor).warm
		if previous>=0:worst_jump=maxf(worst_jump,absf(value-previous))
		previous=value
		worst_error=maxf(worst_error,absf(value-(1.0-smoothstep(18,112,i*.25))))
	check(worst_jump<.005,"no visible spatial cache edge jump on a 0.25-unit sweep")
	check(worst_error<.015,"interpolation remains close to physical lamp attenuation")
	LIGHT.samples.clear();actor.position=lamp+Vector2(45,0);var first:float=LIGHT.sample(actor).warm
	actor.position=lamp+Vector2(48,0);var second:float=LIGHT.sample(actor).warm
	LIGHT.samples.clear();var reversed_second:float=LIGHT.sample(actor).warm
	actor.position=lamp+Vector2(45,0);var reversed_first:float=LIGHT.sample(actor).warm
	check(is_equal_approx(first,reversed_first) and is_equal_approx(second,reversed_second),"actor draw order cannot change another actor's light")
	check(absf(first-second)>.01,"nearby actors within a cache cell receive distinct lighting")
	var lamp_stamp:String=LIGHT.lamp_stamp;var cached:int=LIGHT.samples.size()
	state.minutes=1259;LIGHT.sample(actor)
	check(LIGHT.lamp_stamp==lamp_stamp and LIGHT.samples.size()==cached,"clock changes retain the static lamp spatial cache")
	state.minutes=720;check(is_zero_approx(float(LIGHT.sample(actor).warm)),"outdoor lamps inactive in daylight")
	state.current_interior="review-room";var indoor:=LIGHT.sample(actor)
	check(float(indoor.warm)==0 and float(indoor.ambient.r)>.98,"outdoor lamps do not leak into another room")
	state.current_interior="";state.minutes=1260
	for i in range(700):actor.position=Vector2(i*13,3000);LIGHT.sample(actor)
	check(LIGHT.samples.size()<=512,"spatial cache bounded over a long traversal")
	var zones:Dictionary=state.system_catalog.building.zones
	for zone_id:String in zones:
		if zone_id=="home":continue
		var zone:Dictionary=zones[zone_id]
		var at:=Vector2(float(zone.x)+float(zone.size)*.5,float(zone.y)+float(zone.size)*.5)
		if at.distance_to(lamp)<250:continue
		actor.position=at;var dark:float=LIGHT.sample(actor).warm
		var same_revision:Dictionary=state.building.duplicate(true)
		same_revision.layout=[{"type":"lantern","zone":zone_id,"cell":0}];state.building=same_revision
		check(dark<.01 and float(LIGHT.sample(actor).warm)>.98,"loading different lamp layout at the same revision invalidates stale cache")
		state.building.layout=[];state.building.revision=int(state.building.revision)+1
		check(float(LIGHT.sample(actor).warm)<.01,"removing a lamp invalidates its spatial influence")
		break
	print("COORDINATION_LIGHT: %d passed, %d failed; opposed_left=%d opposed_right=%d max_step=%.6f max_error=%.6f"%[passed,failed,left_counter,right_counter,worst_jump,worst_error])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
