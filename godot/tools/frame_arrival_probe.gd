extends Node2D
var mode:=""
var calls:=0
func _activate_walk_target(_target:Dictionary)->void:
	calls+=1
	if mode=="ui":GameState.ui_open=true
	else:GameState.begin_action({"kind":"read","duration":0.12},{"kind":"test"},func():pass)
