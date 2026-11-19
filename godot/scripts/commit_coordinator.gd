extends RefCounted
## One frozen logical operation; render and the writer continue while it is pending.
var state:Node
var preparing:bool=false
var publishing:bool=false
var pending:Dictionary={}
var serial:int=0
var metrics:Dictionary={"prepared":0,"completed":0,"failed":0,"duplicates":0,"prepare_max_ms":0.0,"publish_max_ms":0.0}
const EXCLUDE=["content","initial_state","system_catalog","item_catalog","crop_catalog","npc_catalog","world_village","inventory_metadata","state_changes","quests_runtime","ui_art","_feedback_snapshot"]
func busy()->bool:return not preparing and not pending.is_empty()
func _copy(value:Variant)->Variant:return value.duplicate(true) if value is Dictionary or value is Array else value
func capture()->Dictionary:
	var result:Dictionary={}
	for p:Dictionary in state.get_script().get_script_property_list():
		var key:String=str(p.name)
		if key in EXCLUDE or (int(p.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0:continue
		var value:Variant=state.get(key)
		if value is Object or value is Callable or value is Signal:continue
		result[key]=_copy(value)
	result["__fishing_state"]={"game":state.fishing_session.game.duplicate(true),"accumulator":state.fishing_session.accumulator}
	return result
func apply(values:Dictionary)->void:
	for key:String in values:
		if key=="__fishing_state":state.fishing_session.game=values[key].game.duplicate(true);state.fishing_session.accumulator=float(values[key].accumulator)
		else:state.set(key,_copy(values[key]))
func submit(key:String,operation:Callable,completed:Callable=Callable())->bool:
	if state.incompatible_save:return false
	if preparing:
		var value:Variant=operation.call();return value if value is bool else true
	if busy():metrics.duplicates+=1;return str(pending.key)==key
	var start:int=Time.get_ticks_usec();var before:Dictionary=capture()
	var was_blocked:bool=state.is_blocking_signals();state.set_block_signals(true);preparing=true
	var result:Variant=operation.call();var ok:bool=result if result is bool else true
	var after:Dictionary=capture();var changes:Dictionary={};var restore:Dictionary={}
	for field:String in before:
		if before[field]!=after.get(field):changes[field]=after.get(field);restore[field]=before[field]
	var outcome:String=str(state.message)
	if not ok:
		apply(restore);preparing=false;state.set_block_signals(was_blocked)
		if state.quest_runtime!=null:state.quest_runtime.reset(false)
		state.message=outcome;state.changed.emit();return false
	var before_save:Dictionary=preload("res://scripts/native_save_snapshot.gd").capture(state).duplicate(true)
	# Check persisted changes, excluding the action/pointer/UI runtime fields.
	var persistent:bool=false
	for field:String in changes:
		if before_save.has(field) or field in ["pet_state","current_interior","player_source_position","interior_source_position"]:persistent=true;break
	if not persistent:
		preparing=false;state.set_block_signals(was_blocked);return true
	serial+=1
	var log:Dictionary=state.commit_log.duplicate(true);var id:int=int(log.next);log.next=id+1
	log.rows.append({"id":id,"op":key,"day":state.day})
	if log.rows.size()>256:log.rows=log.rows.slice(-256)
	state.commit_log=log;changes.commit_log=log;restore.commit_log=before.get("commit_log",{"next":1,"rows":[]})
	var candidate:Dictionary=state._make_save_data().duplicate(true)
	var error:String=preload("res://scripts/native_save_rules.gd").error(candidate,state.initial_state,state.world_village.get("offsets",{}))
	if error!="":
		apply(restore);preparing=false;state.set_block_signals(was_blocked)
		if state.quest_runtime!=null:state.quest_runtime.reset(false)
		state.message="这次安排未通过校验，钱物未结算："+error;state.changed.emit();return false
	apply(restore);preparing=false;state.set_block_signals(was_blocked)
	if state.quest_runtime!=null:state.quest_runtime.reset(false)
	pending={"key":key,"token":serial,"changes":changes,"message":outcome,"callback":completed}
	metrics.prepared+=1;metrics.prepare_max_ms=maxf(float(metrics.prepare_max_ms),(Time.get_ticks_usec()-start)/1000.0)
	state._autosave_queued=false
	if is_instance_valid(state._autosave_timer):state._autosave_timer.stop()
	if is_instance_valid(state._movement_autosave_timer):state._movement_autosave_timer.stop()
	state.message="正在记下这次安排……";state.changed.emit()
	state.autosave_coordinator.commit(candidate,_finish.bind(serial))
	return true
func _finish(ok:bool,token:int)->void:
	if pending.is_empty() or int(pending.token)!=token:return
	var publish_begin:int=Time.get_ticks_usec()
	var operation:Dictionary=pending;pending={};publishing=true
	if ok:
		apply(operation.changes);state.message=str(operation.message);metrics.completed+=1
		state.sound_requested.emit("soft")
		if state.quest_runtime!=null:state.quest_runtime.reset(false)
		state.clock_changed.emit();state.changed.emit()
	else:
		metrics.failed+=1;state.message="这次没有保存成功，钱物和进度未结算。";state.changed.emit()
	publishing=false
	var callback:Callable=operation.callback
	if callback.is_valid():callback.call(ok)
	metrics.publish_max_ms=maxf(float(metrics.publish_max_ms),(Time.get_ticks_usec()-publish_begin)/1000.0)
func reset()->void:
	pending.clear();serial+=1
