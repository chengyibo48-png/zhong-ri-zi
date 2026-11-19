extends Node
## Deferred mutation owner. UI snapshots only read cached views.
var state:Node
var dirty:Dictionary={"all":true}
var cache:Dictionary={}
var queue:Array[String]=[]
var pending:=true
var completed_notes:Array[String]=[]
var blocked_auto:Dictionary={}
var command_signature:=-1
var clock_signature:=-1
var metrics:Dictionary={"syncs":0,"recomputed":0,"hits":0,"max_update_ms":0.0,"auto_completed":0}
func _ready()->void:
	state.domain_changed.connect(mark)
	state.clock_changed.connect(_clock_tick)
func _clock_tick()->void:
	var signature:=hash([state.day,state.minutes>=480 and state.minutes<1200])
	if signature==clock_signature:return
	clock_signature=signature;mark("clock")
func mark(domain:String)->void:
	if domain in ["inventory","economy","world"]:blocked_auto.clear()
	dirty[domain]=true;pending=true
func reset(clear_blocked:bool=true)->void:
	if clear_blocked:blocked_auto.clear();completed_notes.clear()
	cache.clear();queue.clear();dirty={"all":true};pending=true;command_signature=-1;clock_signature=-1
func commands_changed()->void:
	var signature:=hash([state.quests.entries,state.quests.pins,state.quests.collapsed,state.quests.get("journey",{}),state.quests.get("memorials",{})])
	if command_signature==signature:return
	command_signature=signature;mark("quest")
func view(d:Dictionary)->Dictionary:
	var id:=str(d.id);var stale:=not cache.has(id) or dirty.has("all") or dirty.has("quest")
	if not stale:
		for dependency:String in preload("res://scripts/quest_model.gd").dependencies(d):
			if dirty.has(dependency):stale=true;break
	if not stale:metrics.hits+=1;return cache[id].duplicate(true)
	var result:Dictionary=preload("res://scripts/quest_service.gd").snapshot(state,d)
	cache[id]=result;metrics.recomputed+=1;return result.duplicate(true)
func enqueue(id:String)->void:
	if not queue.has(id) and not blocked_auto.has(id):queue.append(id)
func _process(_delta:float)->void:
	if state.incompatible_save:return
	if state.transactions!=null and state.transactions.busy():return
	if not pending and queue.is_empty():return
	var started:=Time.get_ticks_usec()
	if pending:
		pending=false;metrics.syncs+=1
		preload("res://scripts/quest_service.gd").sync(state);dirty.clear()
	if not completed_notes.is_empty() and queue.is_empty():
		state.message_requested.emit("已记入手记："+"、".join(completed_notes.slice(0,2))+(" 等 %d 项"%completed_notes.size() if completed_notes.size()>2 else ""));completed_notes.clear()
	# Never grant from sync(), a getter, or a notification callback.
	if not state.action_busy():
		var notes:Array[String]=[]
		for i:int in mini(queue.size(),1):
			var id:String=queue.pop_front()
			var definition:Dictionary=preload("res://scripts/quest_service.gd").definition(state,id)
			var accepted:bool=state.transactions.submit("quest-auto:"+id,func()->bool:return preload("res://scripts/quest_service.gd").claim(state,id),func(ok:bool):
				if ok:metrics.auto_completed+=1;completed_notes.append(str(definition.get("title","目标")))
				else:blocked_auto[id]=true)
			if not accepted:blocked_auto[id]=true
		if not notes.is_empty():state.message_requested.emit("已记入手记："+"、".join(notes.slice(0,2))+(" 等 %d 项"%notes.size() if notes.size()>2 else ""))
	metrics.max_update_ms=maxf(float(metrics.max_update_ms),(Time.get_ticks_usec()-started)/1000.0)
