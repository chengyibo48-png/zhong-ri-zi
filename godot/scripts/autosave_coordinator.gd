extends Node
## One writer; autosaves merge, durable operations are prioritized without joining live work.
var state:Node
var pending:bool=false
var use_threads:bool=not OS.has_feature("web")
var inline_for_tests:bool=false
var generation:int=0
var thread:Thread
var ready_at:int=0
var job_generation:int=0
var commits:Array=[]
var active:Dictionary={}
signal idle
var metrics:Dictionary={"requested":0,"merged":0,"started":0,"completed":0,"failed":0,"snapshot_max_ms":0.0,"encode_max_ms":0.0,"io_max_ms":0.0,"events":[]}
func request()->void:
	metrics.requested+=1
	if pending:metrics.merged+=1
	pending=true;ready_at=Time.get_ticks_msec()+80
func commit(snapshot:Dictionary,done:Callable,path:String="")->void:
	pending=false
	if inline_for_tests:
		active={"done":done,"generation":generation};_consume(_write(state._save_path_absolute(state.SAVE_PATH if path=="" else path),snapshot,false),generation);return
	commits.append({"snapshot":snapshot,"done":done,"path":state._save_path_absolute(state.SAVE_PATH) if path=="" else state._save_path_absolute(path),"generation":generation})
func _process(_delta:float)->void:
	if thread!=null:
		if not thread.is_alive():_finish()
		else:return
	if not active.is_empty():return
	if not commits.is_empty():
		active=commits.pop_front();_start(active.snapshot,active.path);return
	if not pending or Time.get_ticks_msec()<ready_at or not is_instance_valid(state) or bool(state._writing_save) or state.transactions!=null and state.transactions.busy():return
	pending=false;var begin:int=Time.get_ticks_usec();var snapshot:Dictionary=state._make_save_data().duplicate(true)
	metrics.snapshot_max_ms=maxf(float(metrics.snapshot_max_ms),(Time.get_ticks_usec()-begin)/1000.0)
	active={"done":Callable(),"generation":generation};_start(snapshot,state._save_path_absolute(state.SAVE_PATH))
func _start(snapshot:Dictionary,path:String)->void:
	job_generation=int(active.generation);metrics.started+=1
	var preserve:bool=path==state._recovered_save_path
	if not use_threads:call_deferred("_deferred_write",path,snapshot,preserve);return
	thread=Thread.new()
	if thread.start(_write.bind(path,snapshot,preserve))!=OK:thread=null;call_deferred("_deferred_write",path,snapshot,preserve)
func _deferred_write(path:String,snapshot:Dictionary,preserve:bool)->void:_consume(_write(path,snapshot,preserve),job_generation)
static func _write(path:String,snapshot:Dictionary,preserve:bool)->Dictionary:
	var begin:int=Time.get_ticks_usec()
	if not preload("res://scripts/native_save_schema.gd").safe_tree(snapshot):return {"ok":false,"encode_ms":0.0,"io_ms":0.0}
	var encoded:String=preload("res://scripts/save_json.gd").encode(snapshot);var encode:float=(Time.get_ticks_usec()-begin)/1000.0;begin=Time.get_ticks_usec()
	var ok:bool=preload("res://scripts/save_repository.gd").write_encoded(path,encoded,preserve)
	return {"ok":ok,"encode_ms":encode,"io_ms":(Time.get_ticks_usec()-begin)/1000.0,"recovered":preserve}
func _consume(result:Dictionary,job:int)->void:
	metrics.encode_max_ms=maxf(float(metrics.encode_max_ms),float(result.encode_ms));metrics.io_max_ms=maxf(float(metrics.io_max_ms),float(result.io_ms));metrics["completed" if result.ok else "failed"]+=1
	metrics.events.append({"at_ms":Time.get_ticks_msec(),"ok":result.ok,"generation":job,"encode_ms":result.encode_ms,"io_ms":result.io_ms,"commit":active.get("done",Callable()).is_valid()})
	if metrics.events.size()>64:metrics.events.pop_front()
	var callback:Callable=active.get("done",Callable());active={}
	if job==generation and is_instance_valid(state):
		if result.ok and result.get("recovered",false):state._recovered_save_path=""
		if callback.is_valid():callback.call(bool(result.ok))
		elif not result.ok:state.message="自动存档写入失败，原有存档和备份仍保留。";state.message_requested.emit(state.message)
	if commits.is_empty() and not pending:idle.emit()
func _finish()->void:
	var result:Dictionary=thread.wait_to_finish();thread=null;_consume(result,job_generation)
func busy()->bool:return thread!=null or not active.is_empty() or not commits.is_empty()
func barrier(invalidate:bool=false)->void:
	# Synchronous compatibility path, only for legacy direct calls and teardown.
	if thread!=null:_finish()
	if invalidate:
		for queued:Dictionary in commits:
			var cb:Callable=queued.get("done",Callable())
			if cb.is_valid():cb.call(false)
		commits.clear();pending=false;generation+=1
func _exit_tree()->void:barrier(true)
