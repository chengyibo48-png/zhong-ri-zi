extends SceneTree
var passed := 0
var failed := 0
var captures: Array[String] = []
var folder := "res://artifacts/quality-20261014/screenshots"
var qa_root := "res://artifacts/quality-20261014"
class BuildingProbe extends Node2D:
	var spec: Dictionary
	var season: int
	var painted := false
	func _draw() -> void:
		painted = load("res://scripts/world_art.gd").draw_prop(self,spec,season,1260)
func _initialize() -> void:
	if not OS.get_environment("QUALITY_ARTIFACT_ROOT").is_empty(): qa_root = OS.get_environment("QUALITY_ARTIFACT_ROOT")
	folder = qa_root + "/screenshots"
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else: failed += 1;push_error(text)
func settle(frames: int = 5) -> void:
	for i in range(frames): await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> Image:
	await settle()
	var image := root.get_texture().get_image()
	var path := folder+"/"+name+".png"
	check(image != null and image.save_png(path) == OK,"Saved native screenshot "+name)
	captures.append(path)
	return image
func luma(image: Image) -> float:
	var sum := 0.0
	var count := 0
	for y in range(205,590,8):
		for x in range(370,1150,8):
			var color := image.get_pixel(x,y)
			sum += color.r*0.2126+color.g*0.7152+color.b*0.0722
			count += 1
	return sum/float(count)
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("Quality GPU timeout");quit(1))
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var state := root.get_node("GameState")
	state.set_process(false);state.flags.introDone=true;state.ui_open=false
	root.size=Vector2i(1280,800)
	var luminance: Array[Dictionary] = []
	for house: String in ["home-an","home-qiao","building-town-1","building-farm-12"]:
		state.current_interior=house;state.interior_position=Vector2(480,550)
		change_scene_to_file("res://scenes/interior.tscn")
		await settle(12)
		var scene := current_scene
		state.minutes=720;state.changed.emit();scene.queue_redraw()
		var day := await capture(house+"-day")
		state.minutes=1260;state.changed.emit();scene.queue_redraw()
		var night := await capture(house+"-night")
		var ratio := luma(night)/maxf(0.001,luma(day))
		luminance.append({"house":house,"day_luma":luma(day),"night_luma":luma(night),"ratio":ratio})
		check(ratio > 0.60,"Night room remains readable "+house+" ratio "+str(ratio))
		var scheduler: Node = scene.hud.get_node("InteractionUIRefresh")
		var before: int = scheduler.refresh_count
		await settle(120)
		check(scheduler.refresh_count-before <= 3,"Idle world hints are event driven "+house)
		state.set_source_input_mode("pad")
		await settle()
		check(scheduler.refresh_count > before,"Controller mode immediately refreshes hints")
		state.set_source_input_mode("keyboard")
	current_scene.queue_free();await settle()
	current_scene=null
	root.content_scale_size=Vector2i(1280,900);root.size=Vector2i(1280,900)
	var entries: Dictionary = load("res://scripts/world_art.gd").entries()
	for pair: int in range(2):
		var board := Node2D.new();root.add_child(board)
		var index := 0
		for key: String in entries:
			if not key.begins_with("buildings/"):continue
			var row: Dictionary=entries[key]
			var bounds: Array=row.get("worldRect",[-48,-64,96,64])
			var factor:float=minf(100.0/float(bounds[2]),82.0/float(bounds[3]))
			for season: int in range(pair*2,pair*2+2):
				var probe := BuildingProbe.new()
				probe.spec={"kind":"house","id":key.get_slice("/",1),"_visual_rect":[-float(bounds[2])*factor/2.0,-float(bounds[3])*factor,float(bounds[2])*factor,float(bounds[3])*factor]}
				probe.season=season
				probe.position=Vector2(66+(index%12)*105,108+int(index/12)*105)
				board.add_child(probe);index+=1
		await capture("seasonal-buildings-night-"+str(pair))
		for probe: Node in board.get_children():
			check(probe.painted,"Actual four-season building renderer")
			check(probe.material is ShaderMaterial,"Seasonal night native material")
		board.queue_free();await settle()
	var poses := Node2D.new();root.add_child(poses)
	var rig: Script=load("res://scripts/painted_wardrobe.gd")
	for row: int in range(4):
		for frame: int in range(8):
			var character: Node2D=rig.new()
			character.position=Vector2(90+frame*155,195+row*210)
			character.scale=Vector2.ONE*3.0
			poses.add_child(character)
			var clip: String=["bike","dig","water","trade"][row]
			character.present(state.appearance,{},clip,"right",float(frame)/12.0,-1.0 if row==0 else float(frame)/7.0)
	await capture("interaction-and-cycling-poses")
	for character: Node in poses.get_children(): check(character.painted_active,"Live layered animation frame")
	poses.queue_free();await settle()
	var audio := root.get_node("AudioService")
	var voices: Array = []
	var at := 0.0
	for kind: String in ["water","hoe","chop","seed","feed","door","read","trade","greet","harvest","good","soft"]:
		for original: Dictionary in audio.RULES.sound(kind,{"sound":true,"volume":0.5,"effects":0.6}).voices:
			var voice := original.duplicate(true);voice.start=float(voice.start)+at;voice.end=float(voice.end)+at
			voices.append(voice)
		at+=0.6
	var stream: AudioStreamWAV=audio._make_stream(voices)
	check(stream.save_to_wav(qa_root+"/audio-preview.wav")==OK,"Saved sound calibration audition")
	var master := AudioServer.get_bus_index("Master")
	var recorder := AudioEffectCapture.new();AudioServer.add_bus_effect(master,recorder)
	state.player_settings.sound=true;state.player_settings.volume=1.0;state.player_settings.effects=1.0;audio.apply_settings()
	for i in range(6): audio.play_sfx("trade")
	await create_timer(0.5).timeout
	var frames := recorder.get_buffer(recorder.get_frames_available())
	var peak := 0.0
	for frame: Vector2 in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	check(not frames.is_empty() and peak > 0.01,"Actual mixed audio signal captured")
	check(peak <= db_to_linear(-1.0)+0.002,"Six voices retain limiter headroom")
	AudioServer.remove_bus_effect(master,1)
	var report := {"passed":passed,"failed":failed,"night_luminance":luminance,"screenshots":captures,"mixed_audio_peak":peak,"joypads":Input.get_connected_joypads(),"adapter":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(qa_root+"/visual-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("QUALITY_VISUAL: %d passed, %d failed"%[passed,failed])
	await audio.prepare_exit()
	quit(1 if failed else 0)
