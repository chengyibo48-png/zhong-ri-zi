extends Node
## Audio resources and players remain on the main thread; workers only return bytes.
const PCM=preload("res://scripts/audio_pcm.gd")
var jobs:Array[Dictionary]=[]
var active:Dictionary={}
var cancelled:bool=false
var use_threads:bool=not OS.has_feature("web")
var metrics:Dictionary={"generated":0,"worker_max_ms":0.0,"main_max_ms":0.0}
func request(key:String,voices:Array,done:Callable,lane:String="ambient")->void:
	if cancelled:return
	for job:Dictionary in jobs:
		if str(job.key)==key:job.callbacks.append(done);return
	for job:Dictionary in active.values():
		if str(job.key)==key:job.callbacks.append(done);return
	jobs.append({"key":key,"voices":voices.duplicate(true),"callbacks":[done],"lane":lane,"seed":hash(key)})
static func render(voices:Array,seed_value:int)->Dictionary:
	var begin:int=Time.get_ticks_usec();var generator:=PCM.new(voices,seed_value)
	while not generator.step(1000000):pass
	return {"bytes":generator.bytes,"ms":(Time.get_ticks_usec()-begin)/1000.0}
func _process(_delta:float)->void:
	var begin:int=Time.get_ticks_usec()
	for lane:String in active.keys():
		var job:Dictionary=active[lane];var result:Dictionary={}
		if job.has("thread"):
			if job.thread.is_alive():continue
			result=job.thread.wait_to_finish()
		elif job.generator.step(1500):result={"bytes":job.generator.bytes,"ms":(Time.get_ticks_usec()-int(job.started))/1000.0}
		else:continue
		active.erase(lane);metrics.generated+=1;metrics.worker_max_ms=maxf(float(metrics.worker_max_ms),float(result.ms))
		if cancelled:continue
		var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=PCM.RATE;stream.stereo=false;stream.data=result.bytes
		for callback:Callable in job.callbacks:
			if callback.is_valid():callback.call(stream)
	if not cancelled:
		for lane:String in ["sfx","ambient"]:
			if active.has(lane):continue
			for i:int in jobs.size():
				if str(jobs[i].lane)!=lane:continue
				var job:Dictionary=jobs.pop_at(i)
				if use_threads:
					var worker:=Thread.new()
					if worker.start(render.bind(job.voices,job.seed))==OK:job.thread=worker
				if not job.has("thread"):job.generator=PCM.new(job.voices,job.seed);job.started=Time.get_ticks_usec()
				active[lane]=job;break
	metrics.main_max_ms=maxf(float(metrics.main_max_ms),(Time.get_ticks_usec()-begin)/1000.0)
func cancel()->void:cancelled=true;jobs.clear()
func busy()->bool:return not active.is_empty()
func _exit_tree()->void:
	for job:Dictionary in active.values():
		if job.has("thread"):job.thread.wait_to_finish()
	active.clear()
