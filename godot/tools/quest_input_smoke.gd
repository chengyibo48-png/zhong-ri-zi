extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func settle()->void:
	for i:int in 12:await process_frame
func run()->void:
	var state:Node=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_open=false;state.player_position=Vector2(2500,1800)
	for id:String in state.relations:state.relations[id].talked=0
	root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
	var hud:Node=current_scene.hud;var panel:Control=hud.life_plan_panel
	hud.apply_source_gamepad({"kind":"journal"});await settle()
	check(panel.visible and panel.active_tab=="main","journal button opens current mainline")
	var pad:RefCounted=load("res://scripts/source_gamepad.gd").new();var now:float=1000
	for expected:String in ["people","life","done","today","main"]:
		var buttons:Array=[];buttons.resize(17);buttons.fill(false)
		pad.poll({"connected":true,"buttons":buttons,"axes":[0,0]},true,false,false,true,now)
		buttons[5]=true
		for command:Dictionary in pad.poll({"connected":true,"buttons":buttons,"axes":[0,0]},true,false,false,true,now+200):hud.apply_source_gamepad(command)
		await settle();check(panel.active_tab==expected,"right shoulder selects "+expected);now+=400
	hud.apply_source_gamepad({"kind":"tab","value":-1});await settle();check(panel.active_tab=="today","left shoulder wraps to recommendations")
	panel.open_panel("", "main");await settle()
	var button:Button=panel.action_dock.get_child(0);button.grab_focus()
	hud.apply_source_gamepad({"kind":"activate"});await settle()
	check(int(state.quests.journey.stage)==1,"confirm button activates focused chapter action")
	hud.apply_source_gamepad({"kind":"close"});await settle();check(not panel.visible,"cancel returns from the task journal")
	print("QUEST_INPUT: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
