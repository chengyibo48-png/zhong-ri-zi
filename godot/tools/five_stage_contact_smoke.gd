extends SceneTree
var state:Node
var passed:=0
var failed:=0
var commits:=0
var cancels:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func done()->void:commits+=1
func cancelled()->void:cancels+=1
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		printerr("Five-stage checks require isolated TEMP and APPDATA");quit(1);return
	state=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
	change_scene_to_file("res://scenes/main.tscn")
	for i in range(8):await process_frame
	var actor:Node2D=current_scene.player;actor.set_physics_process(false);state.ui_open=false
	var visual:Node=actor.character_visual
	var target:Dictionary={"kind":"farm-task","index":0,"x":state._farm_position(0).x,"y":state._farm_position(0).y}
	var at:=Vector2(float(target.x),float(target.y));var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(state)
	var safe:Dictionary=nav.safe(state,"",{"x":at.x+42,"y":at.y+42})
	actor.global_position=Vector2(safe.x,safe.y);state.player_position=actor.global_position
	var spec:Dictionary=state.ACTION_RULES.spec("hoe","test","")
	var money:int=state.money;var energy:float=state.stamina;var inventory:Dictionary=state.inventory.duplicate(true)
	check(state.begin_action(spec,target,done,cancelled),"approach accepted")
	check(not state.action_busy() and not state.contact_approach.pending.is_empty(),"approach precedes action clock")
	check(state.cancel_action(),"cancel approach")
	check(commits==0 and cancels==1 and actor.walk_path.is_empty() and actor.walk_source_path.is_empty(),"cancel clears both navigation paths without commit")
	check(state.begin_action(spec,target,done,cancelled),"restart approach")
	var steps:=0
	while not state.action_busy() and not state.contact_approach.pending.is_empty() and steps<300:
		actor.advance_player_frame(1.0/60.0);state._process_action(1.0/60.0);steps+=1
	check(state.action_busy(),"reachable arrival starts original sequence")
	check(actor.global_position.distance_to(at)<=22,"no teleport and actual close stand")
	check(commits==0 and state.money==money and state.stamina==energy and state.inventory==inventory,"no costs during approach")
	var duration:float=state.action_snapshot().get("duration",0)
	check(is_equal_approx(duration,state.ACTION_RULES.duration(spec,str(state.feedback.get("prefs",{}).get("pace","normal")))),"original action duration")
	for i in range(ceili(duration*60)+5):state._process_action(1.0/60.0)
	check(commits==1,"exactly once settlement")
	actor.global_position=Vector2(safe.x,safe.y);state.player_position=actor.global_position
	state.begin_action(spec,target,done,cancelled)
	var crop:Variant=state.plots[0].crop;state.plots[0].crop="invalid-test-target"
	state._process_action(.016);state.plots[0].crop=crop
	check(state.contact_approach.pending.is_empty() and commits==1,"target mutation cancels before commit")
	actor.global_position=Vector2(safe.x,safe.y);state.player_position=actor.global_position
	state.begin_action(spec,target,done,cancelled)
	state.farm_active_task={"index":0,"action":"hoe"};state.farm_queue=[{"index":1,"action":"hoe"}]
	state.source_keyboard.keys={"arrowright":true};actor.advance_player_frame(1.0/60)
	check(state.contact_approach.pending.is_empty() and state.farm_active_task.is_empty() and state.farm_queue.is_empty(),"manual input cancels queued approach without restarting work")
	check(state.source_keyboard.keys.get("arrowright",false),"manual cancellation preserves held movement key")
	state.source_keyboard.clear()
	var resource:=Node2D.new();resource.set_script(load("res://scripts/gather_node.gd"));resource.node_id="v8-contact-resource";resource.item_id="wood"
	current_scene.add_child(resource);current_scene.gather_nodes.append(resource);resource.global_position=at
	actor.global_position=Vector2(safe.x,safe.y);state.player_position=actor.global_position
	var moving:Dictionary={"kind":"gather","id":resource.node_id,"item":"wood","x":resource.global_position.x,"y":resource.global_position.y}
	var chop:Dictionary=state.ACTION_RULES.spec("chop","test", "wood")
	check(state.begin_action(chop,moving,done,cancelled),"moving resource starts approach")
	resource.global_position=actor.global_position+Vector2(0,-10)
	state._process_action(.016)
	check(state.action_busy() and state.contact_approach.pending.is_empty(),"moving target already within reach starts action after revalidation")
	state.cancel_action()
	resource.global_position=at;moving.x=at.x;moving.y=at.y
	check(state.begin_action(chop,moving,done,cancelled),"resource disappearance fixture starts approach")
	resource.free();state._process_action(.016);current_scene.gather_nodes.pop_back()
	check(state.contact_approach.pending.is_empty() and not state.action_busy() and commits==1,"removed target cancels without duplicate settlement")
	for direction:String in ["down","up","left","right"]:
		for kind:String in ["hoe","dig","chop","cut","water","seed","harvest","gather"]:
			var vector:=Vector2.DOWN if direction=="down" else Vector2.UP if direction=="up" else Vector2.LEFT if direction=="left" else Vector2.RIGHT
			var reach:float=load("res://scripts/action_contact.gd").stand_distance(kind)
			visual.wardrobe.contact_description=load("res://scripts/action_contact.gd").describe({"kind":kind,"progress":.55,"x":vector.x*reach,"y":vector.y*reach})
			check(visual.wardrobe.present(state.appearance,visual.appearance,kind,direction,0,.55),"contact renderer "+kind+direction)
			var frame:Dictionary=visual.wardrobe.rig_frame
			check(frame.has("contact") and is_finite(float(frame.contact.error)),"finite coordinated contact "+kind+direction)
			if kind in ["hoe","dig","chop","cut","harvest","gather"]:check(float(frame.contact.error)<1.5,"actual surface contact "+kind+direction+" error="+str(frame.contact.error))
	print("CONTACT: %d passed, %d failed; approach_steps=%d"%[passed,failed,steps])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
