extends SceneTree
var passed:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failures.append(label);print("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false);s.autosave_coordinator.pending=false
	var audio:Node=root.get_node("AudioService");audio.prewarm_queue.clear()
	var rules:Script=preload("res://scripts/source_audio_rules.gd");var pcm:Script=preload("res://scripts/audio_pcm.gd")
	for kind:String in ["water","chop","music","soft"]:
		var voices:Array=rules.sound(kind,s.player_settings).voices
		var expected:AudioStreamWAV=audio._make_stream(voices);var candidate:RefCounted=pcm.new(voices,17)
		while not candidate.step(1500):await process_frame
		check(expected.data==candidate.bytes,"identical PCM "+kind)
	var plan:Dictionary=rules.ambient(1,0,true,false,false,s.player_settings,0,true,false,false,false)
	audio.rng.seed=17;var expected_noise:AudioStreamWAV=audio._make_stream(plan.ambient);var noise:RefCounted=pcm.new(plan.ambient,17)
	while not noise.step(1500):await process_frame
	check(expected_noise.data==noise.bytes,"identical filtered ambience")
	var frame_count:int=0;var box:Array=[false]
	audio.synthesis.request("test-melody",plan.music,func(_stream:AudioStreamWAV):box[0]=true)
	while not box[0] and frame_count<1000:frame_count+=1;await process_frame
	check(box[0] and frame_count>1,"render loop continues during synthesis")
	check(float(audio.synthesis.metrics.main_max_ms)<15,"main thread synthesis consumption bounded")
	var desired:Dictionary=s._make_save_data().duplicate(true);desired.money=377
	check(preload("res://scripts/save_repository.gd").write("user://saves/v38/test-load.json",desired),"prepare fixture save")
	s.money=199
	var restored:Dictionary=await preload("res://scripts/save_session.gd").restore_async(s,"user://saves/v38/test-load.json")
	check(restored.ok and s.money==377,"async load publishes durable target")
	var disk:Dictionary=preload("res://scripts/save_repository.gd").read(s._save_path_absolute(s.SAVE_PATH))
	check(disk.money==377,"loaded target confirmed on disk")
	var previous:Dictionary=s._make_save_data().duplicate(true)
	DirAccess.make_dir_recursive_absolute(s._save_path_absolute(s.SAVE_PATH)+".tmp")
	desired.money=499;preload("res://scripts/save_repository.gd").write("user://saves/v38/test-load.json",desired)
	var rejected:Dictionary=await preload("res://scripts/save_session.gd").restore_async(s,"user://saves/v38/test-load.json")
	check(not rejected.ok and s.money==int(previous.money),"load write failure leaves active state unchanged")
	DirAccess.remove_absolute(s._save_path_absolute(s.SAVE_PATH)+".tmp")
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")
	var report:=FileAccess.open(out+"/village-audio-save-check.json",FileAccess.WRITE);report.store_string(JSON.stringify({"passed":passed,"failed":failures,"framesDuringSynthesis":frame_count,"audio":audio.synthesis.metrics},"\t"));report.close()
	print("AUDIO_SAVE ",passed," / ",failures)
	if not failures.is_empty():await audio.prepare_exit();quit(1);return
	s.money=12345
	var exit_file:=FileAccess.open(out+"/exit-verification-path.txt",FileAccess.WRITE);exit_file.store_string(s._save_path_absolute(s.SAVE_PATH));exit_file.close()
	audio.request_quit()
