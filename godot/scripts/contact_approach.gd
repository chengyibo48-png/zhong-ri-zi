extends RefCounted
## A cancellable pre-action walk. Original action duration starts after arrival.
var pending:Dictionary={}
var retry_at:=0.0
func cancel(invoke:=true)->bool:
	if pending.is_empty():return false
	var callback:Callable=pending.get("cancel",Callable())
	var target:Dictionary=pending.get("target",{})
	var actor:Node2D=pending.actor.get_ref()
	var state:Node=pending.state.get_ref()
	pending.clear()
	if is_instance_valid(state) and bool(state.walking_target.get("contact_approach",false)):
		state.walking_target.clear()
		if is_instance_valid(actor):actor.walk_path.clear();actor.walk_source_path.clear()
	if invoke and is_instance_valid(state):
		if str(target.get("kind",""))=="farm-task":state.cancel_farm_queue()
		elif str(target.get("kind",""))=="ranch-task":state.cancel_ranch_queue()
	if invoke and callback.is_valid():callback.call()
	return true
func prepare(state:Node,spec:Dictionary,target:Dictionary,commit:Callable,callback:Callable)->int:
	if target.get("_contact_aligned",false):return 0
	if not pending.is_empty():return 2
	if not preload("res://scripts/action_contact.gd").supports(str(spec.get("kind",""))):return 0
	var players:=state.get_tree().get_nodes_in_group("player")
	if players.is_empty():return 0
	var actor:Node2D=players[0];var at:=Vector2(float(target.get("x",actor.global_position.x)),float(target.get("y",actor.global_position.y)))
	var required:float=preload("res://scripts/action_contact.gd").stand_distance(str(spec.get("kind","")))
	if actor.global_position.distance_to(at)<=required+.5:return 0
	if state.atlas_source_navigation==null:state.atlas_source_navigation=load("res://scripts/npc_navigation.gd").new()
	var nav:RefCounted=state.atlas_source_navigation;nav.refresh(state)
	var origin:Dictionary=state.player_navigation_position();var path:Array=[];var stand:=Vector2.ZERO
	var angle:float=(actor.global_position-at).angle()
	for radius:float in [required,maxf(10,required-4),required+4]:
		for offset in [0.0,.45,-.45,.9,-.9,PI]:
			var candidate:Vector2=at+Vector2.from_angle(angle+offset)*radius
			if nav.blocked(state,state.current_interior,candidate.x,candidate.y):continue
			var route:Array=nav.route(state,state.current_interior,origin,{"x":candidate.x,"y":candidate.y})
			if route.is_empty():continue
			path=route;stand=candidate;break
		if not path.is_empty():break
	if path.is_empty():state.message="需要在目标旁留出可以站立的位置。";state.changed.emit();return 2
	pending={"spec":spec.duplicate(true),"target":target.duplicate(true),"commit":commit,"cancel":callback,"room":state.current_interior,"generation":state._feedback_state_generation,"stand":stand,"actor":weakref(actor),"state":weakref(state),"plot":{}}
	if str(target.get("kind",""))=="farm-task":
		var index:=int(target.get("index",-1))
		if index<0 or index>=state.plots.size():pending.clear();return 2
		var plot:Dictionary=state.plots[index]
		pending.plot={"crop":plot.get("crop",""),"tilled":plot.get("tilled",false),"removed":plot.get("removed",false)}
	state.walking_target={"kind":"walk","name":target.get("name","手边物件"),"x":stand.x,"y":stand.y,"contact_approach":true}
	actor.walk_source=true;actor.walk_is_exit=false;actor.walk_source_path=path.duplicate(true);actor.walk_path.clear();actor.walk_index=0
	for point:Dictionary in path:actor.walk_path.append(Vector2(float(point.x),float(point.y)))
	state.source_keyboard.clear();state.changed.emit()
	return 1
func advance(state:Node)->void:
	if pending.is_empty():return
	if state.current_interior!=pending.room or state._feedback_state_generation!=pending.generation:cancel();return
	var actor:Node2D=pending.actor.get_ref()
	if not is_instance_valid(actor):cancel();return
	if not state.source_keyboard.direction(state.player_settings.get("bindings",{})).is_zero_approx() or state.touch_direction.length_squared()>.01 or Vector2(float(state.source_gamepad.motion.x),float(state.source_gamepad.motion.y)).length_squared()>.01:
		cancel();state.walking_target.clear();actor.walk_source_path.clear();actor.walk_path.clear();return
	var target:Dictionary=pending.target
	if str(target.get("kind",""))=="gather":
		var identity:=str(target.get("id",""))
		if state.gathered_today(identity):cancel();return
		var nodes:Variant=actor.get_parent().get("gather_nodes")
		if nodes is Array:
			var found:=false
			for candidate:Variant in nodes:
				if not is_instance_valid(candidate):continue
				var node:Node2D=candidate
				if node.is_queued_for_deletion() or str(node.node_id)!=identity:continue
				found=true
				if not state.forage_status(identity,str(node.item_id),str(node.event)).ready:cancel();return
				var actual:Vector2=node.global_position
				if actual.distance_to(Vector2(float(target.x),float(target.y)))>2:
					var saved:=pending.duplicate();cancel(false)
					var moved:Dictionary=target.duplicate(true);moved.x=actual.x;moved.y=actual.y
					_replan(state,saved,moved)
					return
				break
			if not found:cancel();return
	if not pending.plot.is_empty():
		var index:=int(target.get("index",-1))
		if index<0 or index>=state.plots.size():cancel();return
		for key in pending.plot:
			if state.plots[index].get(key)!=pending.plot[key]:cancel();return
	if target.has("nodeId") and state.gathered_today(str(target.nodeId)):cancel();return
	var current:Dictionary=state.atlas_resolve(target) if target.has("id") and str(target.get("kind",""))!="farm-task" else {}
	if not current.is_empty() and Vector2(float(current.get("x",target.x)),float(current.get("y",target.y))).distance_to(Vector2(float(target.x),float(target.y)))>2.0:
		var saved:=pending.duplicate();cancel(false)
		_replan(state,saved,current);return
	if target.has("animalId"):
		var index:int=state.ranch_animal_index(str(target.animalId))
		if index<0:cancel();state.walking_target.clear();return
	if actor.global_position.distance_to(Vector2(pending.stand))>1.5:
		if state.walking_target.is_empty():cancel()
		return
	var saved:=pending.duplicate();pending.clear();state.walking_target.clear();actor.walk_path.clear();actor.walk_source_path.clear()
	target=target.duplicate(true);target._contact_aligned=true
	state.begin_action(saved.spec,target,saved.commit,saved.cancel)

func _replan(state:Node,saved:Dictionary,target:Dictionary)->void:
	# begin_action handles both "already close" and a newly required route.
	if state.begin_action(saved.spec,target,saved.commit,saved.cancel):return
	if str(target.get("kind",""))=="farm-task":state.cancel_farm_queue()
	elif str(target.get("kind",""))=="ranch-task":state.cancel_ranch_queue()
	var callback:Callable=saved.get("cancel",Callable())
	if callback.is_valid():callback.call()
