extends SceneTree
const CODEC=preload("res://scripts/save_json.gd")
var passed:=0
var failed:=0
var state:Node
var world:Node
var now:=2000.0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=20:push_error(label)
func commands_match(actual:Array,expected:Array)->bool:
	if actual.size()!=expected.size():return false
	for i in range(actual.size()):
		if actual[i].size()!=expected[i].size() or str(actual[i].kind)!=str(expected[i].kind):return false
		if expected[i].has("value") and float(actual[i].get("value",0))!=float(expected[i].value):return false
	return true
func sample(indices:Array=[],axes:Array=[0.0,0.0])->Dictionary:
	var buttons:Array=[]
	buttons.resize(17)
	buttons.fill(false)
	for i in indices:buttons[i]=true
	return {"connected":true,"buttons":buttons,"axes":axes}
func poll(indices:Array=[],axes:Array=[0.0,0.0],at:float=-1.0)->void:
	now=now+200.0 if at<0.0 else at
	state.poll_source_gamepad(now,world.player,sample(indices,axes))
func tap(indices:Array)->void:
	poll([])
	poll(indices)
func run()->void:
	await process_frame
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	create_timer(180).timeout.connect(func():push_error("Gamepad timeout");quit(1))
	state=root.get_node("GameState")
	state.set_process(false)
	var file:=FileAccess.open(OS.get_environment("GAMEPAD_POLL_FIXTURE"),FileAccess.READ)
	if file==null:quit(1);return
	var cases:=0
	var frames:=0
	while not file.eof_reached():
		var line:=file.get_line()
		if line=="":continue
		var row:Dictionary=CODEC.decode(JSON.parse_string(line))
		var pad=load("res://scripts/source_gamepad.gd").new()
		pad.previous=row.seed.duplicate()
		for tick in row.samples:
			var commands=pad.poll(tick.sample,row.mode!="disabled",row.mode=="hidden",row.mode=="action",row.mode=="panel",float(tick.now),str(row.kind))
			check(commands_match(commands,tick.expected.commands),"source commands "+str(row.mode)+"/"+str(row.kind)+" got "+str(commands)+" expected "+str(tick.expected.commands))
			check(pad.motion==tick.expected.motion,"source exact motion")
			check(pad.previous==tick.expected.previous,"source previous latch")
			check(pad.menu_at==float(tick.expected.menu_at),"source exact repeat deadline")
			check(pad.used==bool(tick.expected.used),"source input mode branch")
			frames+=1
		cases+=1
	check(cases==1560 and frames==17160,"source coverage")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	world=current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	var hud=world.hud
	if hud.onboarding_open():hud.toggle_onboarding()
	state.ui_open=false
	state.source_keyboard.clear()
	root.gui_release_focus()
	tap([2])
	check(hud.market_open(),"poll X opens bag")
	poll([2])
	check(hud.market_open(),"held X does not close bag")
	tap([1])
	check(not state.ui_open,"edge B closes bag")
	poll([1])
	check(not state.ui_open,"held B does not reopen menu")
	tap([9])
	check(hud.life_menu.visible,"edge Start menu")
	poll([],[],3000.0)
	poll([13],[],3001.0)
	check(root.gui_get_focus_owner()==hud.life_menu.buttons.map,"menu down next source entry")
	poll([13],[],3191.0)
	check(root.gui_get_focus_owner()==hud.life_menu.buttons.map,"menu repeat excludes equal deadline")
	poll([13],[],3191.000001)
	check(root.gui_get_focus_owner()==hud.life_menu.buttons.calendar,"menu repeat after deadline")
	tap([0])
	check(hud.weather_open(),"A activates focused menu entry")
	poll([0])
	check(hud.weather_open(),"held A cannot activate next panel")
	tap([1])
	hud.settings_panel.open_panel()
	var settings=hud.settings_panel
	settings.speed_option.grab_focus()
	var prior:int=settings.speed_option.selected
	tap([15])
	check(settings.speed_option.selected==(prior+1)%settings.speed_option.item_count,"Option right wraps selection")
	poll([15])
	check(settings.speed_option.selected==(prior+1)%settings.speed_option.item_count,"held horizontal is edge only")
	settings.volume_slider.grab_focus()
	var old_volume:float=settings.volume_slider.value
	tap([14])
	check(is_equal_approx(settings.volume_slider.value,maxf(settings.volume_slider.min_value,old_volume-settings.volume_slider.step)),"range left uses step and clamp")
	settings.toggles.hints.grab_focus()
	var old_toggle:bool=settings.toggles.hints.button_pressed
	tap([0])
	check(settings.toggles.hints.button_pressed!=old_toggle,"A toggles actual checkbox")
	tap([1])
	tap([2])
	var quantity:SpinBox=hud.market_panel.quantity_box
	quantity.get_line_edit().grab_focus()
	var old_quantity:float=quantity.value
	tap([15])
	check(quantity.value==minf(quantity.max_value,old_quantity+quantity.step),"SpinBox child focus changes number")
	var list:ItemList=hud.market_panel.item_list
	list.grab_focus()
	list.select(0)
	var prior_item:String=hud.market_panel.selected_id
	tap([13])
	check(list.item_count>1 and list.get_selected_items()==PackedInt32Array([1]),"native list rows are navigable source entries")
	check(hud.market_panel.selected_id==prior_item,"list focus movement does not activate an item")
	tap([0])
	check(hud.market_panel.selected_id==hud.market_panel.item_ids[1],"A activates focused native item row")
	tap([1])
	state.walking_target={"x":200.0,"y":200.0,"kind":"map"}
	state.building_task={"probe":true}
	state.kitchen_task={"probe":true}
	poll([], [0.200000001,0.0])
	check(state.walking_target.is_empty() and state.building_task.is_empty() and state.kitchen_task.is_empty(),"pad motion clears all pending routes before frame")
	check(state.source_gamepad.motion.x==0.200000001,"double precision axis preserved")
	poll([])
	state.selected_tool="hoe"
	tap([4])
	check(state.selected_tool=="build" and hud.building_open(),"left shoulder cycles tool and opens layout")
	tap([1])
	tap([5])
	check(state.selected_tool=="hoe","right shoulder returns hoe")
	state.begin_action({"kind":"read","duration":0.3},{"kind":"probe"},func():pass)
	tap([0])
	check(state.action_busy(),"action lock ignores pad A")
	tap([1])
	check(not state.action_busy() and not state.ui_open,"action lock edge B cancels without menu")
	var probe=load("res://tools/gamepad_sample_probe.gd").new()
	var original_pad=state.source_gamepad
	state.source_gamepad=probe
	probe.next=sample([1])
	var before_minutes:float=state.minutes
	var before_clock:float=state.ranch_actor_clock
	state.advance_simulation_frame(0.05,world.player,10.0)
	check(hud.life_menu.visible and state.minutes==before_minutes and state.ranch_actor_clock==before_clock,"formal frame polls menu before world and time")
	state.advance_simulation_frame(0.05,world.player,10.05)
	check(hud.life_menu.visible,"formal frame keeps held edge latch")
	probe.next=sample([])
	state.advance_simulation_frame(0.05,world.player,10.1)
	probe.next=sample([1])
	state.advance_simulation_frame(0.05,world.player,10.15)
	check(not state.ui_open and state.minutes>before_minutes and state.ranch_actor_clock>before_clock,"formal frame closes menu before world resumes")
	state.source_gamepad=original_pad
	var old_position:Vector2=world.player.global_position
	world.player.global_position=Vector2(-5000,-5000)
	state.walking_target={"kind":"map","x":200.0,"y":200.0}
	state.message="没有近距目标时保持原样。"
	tap([0])
	check(not state.action_busy() and state.message=="没有近距目标时保持原样。" and not state.walking_target.is_empty(),"pad A with no nearest target does not toast or cancel route")
	world.player.global_position=old_position
	state.walking_target.clear()
	hud.show_life_menu()
	var button:=Button.new()
	var clicks:=[0]
	button.pressed.connect(func():clicks[0]+=1)
	hud.life_menu.add_child(button)
	button.grab_focus()
	var raw:=InputEventJoypadButton.new()
	raw.button_index=JOY_BUTTON_A
	raw.pressed=true
	Input.parse_input_event(raw)
	Input.flush_buffered_events()
	check(clicks[0]==0,"raw joy event cannot double dispatch GUI activation")
	tap([0])
	check(clicks[0]==1,"polled edge activates GUI exactly once")
	poll([0])
	check(clicks[0]==1,"held A does not repeat GUI click")
	button.queue_free()
	tap([1])
	hud.show_wedding("qiao")
	var confirmation=hud.wedding_panel
	poll([1]);check(confirmation.visible and state.ui_open,"held B does not close a newly opened wedding")
	poll([])
	var raw_b:=InputEventJoypadButton.new()
	raw_b.button_index=JOY_BUTTON_B
	raw_b.pressed=true
	Input.parse_input_event(raw_b);Input.flush_buffered_events()
	check(confirmation.visible,"raw B cannot close wedding before frame sample")
	poll([1]);check(not confirmation.visible and not state.ui_open,"polled B closes wedding to world")
	poll([1]);check(not state.ui_open,"held B does not reopen UI")
	poll([])
	hud.show_separation()
	var separate=hud.separation_panel
	check(hud._gamepad_panel()==separate,"separation has independent focus scope")
	poll([1]);check(not separate.visible and not state.ui_open,"polled B closes separation to world")
	poll([])
	hud.show_separation()
	separate.cancel_button.grab_focus();tap([0])
	check(hud.home_open() and not separate.visible and state.ui_open,"polled A on decline opens home")
	tap([1]);check(not state.ui_open,"new B edge closes home")
	world.queue_free()
	current_scene=null
	await process_frame
	print("GAMEPAD_POLL_SOURCE_SMOKE: %d passed, %d failed; %d cases, %d frames"%[passed,failed,cases,frames])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
