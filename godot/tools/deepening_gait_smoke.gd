extends SceneTree
const RIG:=preload("res://scripts/player_rig.gd")
const GAIT:=preload("res://scripts/character_gait.gd")
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
	var grounded:=true;var continuous:=true;var previous:Dictionary={}
	for i in range(1001):
		var gait:=GAIT.sample(float(i)/1000)
		grounded=grounded and (gait.near.support or gait.far.support) and minf(gait.near.lift,gait.far.lift)<.00001
		if not previous.is_empty():
			for key:String in ["near","far"]:continuous=continuous and absf(gait[key].travel-previous[key].travel)<.03 and absf(gait[key].lift-previous[key].lift)<.04
		previous=gait
	check(grounded,"one supporting foot throughout the complete walking cycle")
	check(continuous,"contact, toe-off and swing boundaries are continuous")
	var a:=GAIT.sample(0);var z:=GAIT.sample(1)
	check(a==z,"loop seam has no phase discontinuity")
	for direction:String in ["left","right","up","down"]:
		var motion:=RIG.new();var idle:=RIG.solve(state.appearance,{},"field",direction,"idle",0,-1,motion.snapshot())
		motion.sample(Vector2(195.0/60,0),1.0/60)
		var first:=RIG.solve(state.appearance,{},"field",direction,"walk",1.0/60,-1,motion.snapshot())
		check(first.feet[0].distance_to(idle.feet[0])<.8 and first.feet[1].distance_to(idle.feet[1])<.8,"first step grows from standing "+direction)
		check(is_equal_approx(motion.stride_phase,195.0/60/float(motion.effective_stride)),"visual easing does not change distance phase")
		motion.sample(Vector2.ZERO,.016);motion.advance(.12)
		check(is_zero_approx(motion.walk_weight),"short tap returns completely to stance")
		var half:=RIG.new();half.sample(Vector2(12,0),.10);half.sample(Vector2.ZERO,.016);half.advance(.06)
		var weight:float=half.walk_weight;half.sample(Vector2(195.0/60,0),1.0/60)
		check(half.walk_weight>weight and half.walk_weight<1,"resumption blends from current load rather than snapping")
	print("DEEPENING_GAIT: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
