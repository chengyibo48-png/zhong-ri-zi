extends "res://scripts/game_state.gd"
var starts:Array=[]
var fail_routes:=false
var hidden_probe:=false
var probe_actor:Node
func simulation_hidden()->bool:return hidden_probe
func _start_probe(kind:String)->bool:
	starts.append(kind)
	if not fail_routes:
		walking_target={"kind":kind}
	return not fail_routes
func advance_building_task()->bool:return _start_probe("build")
func advance_kitchen_task()->bool:return _start_probe("kitchen")
func advance_ranch_task()->bool:return _start_probe("ranch")
func advance_farm_task()->bool:return _start_probe("farm")

var perform_ok:=true
func _ready()->void:pass
func perform_farm_task(_task:Dictionary)->bool:return perform_ok
func perform_ranch_task(_task:Dictionary)->bool:return perform_ok
func ranch_task_destination(_task:Dictionary)->Dictionary:return {"x":0.0,"y":0.0,"ranch_stage":"action","house":""}
