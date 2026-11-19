extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var state:Node=root.get_node("GameState");state.set_process(false)
	for i:int in 12:await process_frame
	var count:int=state.quest_snapshot().size()
	var ok:bool=count>0 and int(state._make_save_data().version)==34 and load("res://scripts/quest_service.gd").validate(state.quests,state.day)
	print("QUEST_PHASE_BOOT: ","PASS" if ok else "FAIL"," visible_tasks=",count)
	await root.get_node("AudioService").prepare_exit();quit(0 if ok else 1)
