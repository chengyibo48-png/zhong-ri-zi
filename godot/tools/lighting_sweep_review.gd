extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false)
	state.current_interior="";state.minutes=1260;state.world_village.houses=[];state.building.layout=[]
	var light:Script=load("res://scripts/actor_lighting.gd")
	var actor:=Node2D.new();root.add_child(actor)
	var lamp:=Vector2(2793,1698);var worst_jump:=0.0;var worst_error:=0.0;var previous:=-1.0
	for i in range(481):
		actor.position=lamp+Vector2(i*.25,0)
		var value:float=light.sample(actor).warm
		if previous>=0:worst_jump=maxf(worst_jump,absf(value-previous))
		previous=value;worst_error=maxf(worst_error,absf(value-(1.0-smoothstep(18,112,i*.25))))
	var rig:Script=load("res://scripts/player_rig.gd");var mirrored:=0
	for i in range(120):
		var motion:Dictionary={"sampled":true,"weight":1.0,"phase":i/120.0}
		var left:Dictionary=rig.solve(state.appearance,{},"field","left","walk",0,-1,motion)
		var right:Dictionary=rig.solve(state.appearance,{},"field","right","walk",0,-1,motion)
		var la:Vector2=left.sockets.hand-left.sockets.shoulder_near;var ra:Vector2=right.sockets.hand-right.sockets.shoulder_near
		if absf(la.x+ra.x)<.001 and absf(la.y-ra.y)<.001:mirrored+=1
	print("LIGHTING_SWEEP max_step=%.6f max_error=%.6f mirrored_stride_samples=%d/120"%[worst_jump,worst_error,mirrored])
	await root.get_node("AudioService").prepare_exit();quit()
