extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=20:push_error(label)
func event(key:String,echo:bool=false)->InputEventKey:
	var value:=InputEventKey.new()
	value.pressed=true
	value.echo=echo
	match key:
		"Escape":value.keycode=KEY_ESCAPE
		"Tab":value.keycode=KEY_TAB
		"Enter":value.keycode=KEY_ENTER
		"Backspace":value.keycode=KEY_BACKSPACE
		"ArrowUp":value.keycode=KEY_UP
		"F1":value.keycode=KEY_F1
		"F5":value.keycode=KEY_F5
		"F7":value.keycode=KEY_F7
		"F9":value.keycode=KEY_F9
		"F10":value.keycode=KEY_F10
		_:value.keycode=key.to_upper().unicode_at(0)
	if key.length()==1:value.unicode=key.unicode_at(0)
	return value
func send(key:String,echo:bool=false,ctrl:bool=false)->void:
	var value:=event(key,echo)
	value.ctrl_pressed=ctrl
	Input.parse_input_event(value)
	Input.flush_buffered_events()
	var release:=value.duplicate()
	release.pressed=false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
func run()->void:
	await process_frame
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	create_timer(120).timeout.connect(func():quit(1))
	var state=root.get_node("GameState")
	state.set_process(false)
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOTKEY_DISPATCH_FIXTURE")))
	for row in fixture.rows:
		var value:=event(str(row.key),bool(row.repeat))
		value.ctrl_pressed=row.mode=="ctrl"
		value.meta_pressed=row.mode=="meta"
		value.alt_pressed=row.mode=="alt"
		var got:Array[String]=state.source_keyboard.commands(value,row.bindings,row.mode in ["panel","panel_action"],row.mode in ["action","panel_action"],row.mode in ["input","textarea","select"],row.mode=="button")
		check(got==row.expected,"source dispatch "+str(row.mode)+"/"+str(row.key)+"/"+str(row.repeat))
	check(fixture.rows.size()==2574,"coverage")
	for index in range(fixture.tools.size()):check(state.TOOLBAR_IDS[index]==fixture.tools[index].id,"source tool order")
	for room in ["","home-granny"]:
		state.current_interior=room
		change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
		await process_frame
		await process_frame
		var world=current_scene
		world.set_process(false)
		world.player.set_physics_process(false)
		var hud=world.hud
		if hud.onboarding_open():hud.toggle_onboarding()
		state.ui_open=false
		root.gui_release_focus()
		state.player_settings.bindings=fixture.rows[0].bindings.duplicate(true)
		for key in ["F1","F5","F7","F9","9"]:
			send(key)
			check(not state.ui_open,"source has no function-key alias "+key+"/"+room)
		send("b",true)
		check(not state.ui_open,"repeated shortcut ignored")
		send("b",false,true)
		check(not state.ui_open,"Ctrl shortcut ignored")
		send("b")
		check(hud.market_open(),"actual bag")
		send("b")
		check(hud.market_open(),"same key does not close bag")
		send("Escape",true,true)
		check(not state.ui_open,"Escape precedes repeat and modifiers")
		send("m")
		check(hud.map_open(),"actual map")
		send("j")
		check(hud.map_open() and not hud.community_open(),"panel blocks another shortcut")
		send("Escape")
		state.walking_target={"x":200.0,"y":200.0,"kind":"map"}
		send("Escape")
		check(hud.life_menu.visible and state.walking_target.is_empty(),"Escape opens menu and clears route")
		send("Escape")
		check(not state.ui_open,"Escape closes life menu")
		send("j")
		check(hud.community_open() and hud.community_panel.active_tab=="journal","actual journal")
		send("Escape")
		send("c")
		check(hud.weather_open() and hud.weather_panel.notebook.current_tab==1,"actual calendar")
		send("Escape")
		send("q")
		check(hud.seed_picker.visible,"actual seeds")
		send("Escape")
		send("8")
		check(state.selected_tool=="build" and hud.building_open(),"source build tool opens layout")
		send("Escape")
		root.gui_release_focus()
		send("6")
		check(state.selected_tool=="axe" and not state.ui_open,"source number tool")
		send("3",true)
		check(state.selected_tool=="axe","tool repeat ignored")
		var input:=LineEdit.new()
		hud.add_child(input)
		input.grab_focus()
		send("b")
		check(not state.ui_open,"typing cannot invoke bag")
		send("Escape")
		check(hud.life_menu.visible,"Escape precedes typing focus")
		send("Escape")
		input.queue_free()
		await process_frame
		var button:=Button.new()
		var clicks:=[0]
		button.pressed.connect(func():clicks[0]+=1)
		hud.add_child(button)
		button.grab_focus()
		send("ArrowUp")
		check(root.gui_get_focus_owner()==button,"world direction prevents native button focus movement")
		send(" ")
		check(clicks[0]==1 and not state.action_busy(),"Space activates focused button")
		button.queue_free()
		await process_frame
		root.gui_release_focus()
		state.begin_action({"kind":"read","duration":0.3},{"kind":"test"},func():pass)
		send("b")
		check(state.action_busy() and not state.ui_open,"action blocks shortcuts")
		send("Escape",true)
		check(not state.action_busy() and not state.ui_open,"Escape repeat cancels action without menu")
		hud.show_feedback()
		send("F10")
		check(hud.feedback_open(),"removed panel alias cannot close feedback")
		send("Escape")
		root.gui_release_focus()
		state.player_settings.bindings.bag="i"
		send("İ")
		check(not state.ui_open,"hotkey rejects dotted I full lowercase")
		send("I")
		check(hud.market_open(),"hotkey uses actual uppercase ASCII character")
		send("Escape")
		state.player_settings.bindings=fixture.rows[0].bindings.duplicate(true)
		check(not hud.help_label.text.contains("F1") and not hud.help_label.tooltip_text.contains("F7"),"HUD hints omit removed aliases")
		check(not str(hud.quick_buttons.save.tooltip_text).contains("F6"),"save hint follows button access")
		send("Tab")
		check(hud.life_menu.visible,"actual Tab menu")
		var entries:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/menu_expansion.json"))
		check(entries==fixture.menu and entries.size()==17 and hud.life_menu.expansion_buttons.size()==17,"all source expansion entries reachable")
		var backward:=event("Tab")
		backward.shift_pressed=true
		Input.parse_input_event(backward)
		Input.flush_buffered_events()
		var backward_release:=backward.duplicate()
		backward_release.pressed=false
		Input.parse_input_event(backward_release)
		Input.flush_buffered_events()
		check(root.gui_get_focus_owner()==hud.life_menu.buttons.neighbors,"Shift Tab wraps to final neighbor journal entry")
		send("Tab")
		check(root.gui_get_focus_owner()==hud.life_menu.buttons.bag,"Tab returns to first menu entry")
		var all_controls:Array=[]
		for entry in hud.life_menu.ENTRIES:all_controls.append(hud.life_menu.buttons[entry[0]])
		for entry in fixture.menu:all_controls.append(hud.life_menu.expansion_buttons[entry[0]])
		all_controls.append(hud.life_menu.buttons.neighbors)
		for index in range(all_controls.size()):
			check(root.gui_get_focus_owner()==all_controls[index],"Tab reaches full current menu entry "+str(index))
			send("Tab")
		check(root.gui_get_focus_owner()==hud.life_menu.buttons.bag,"full current menu wraps to first")
		check(hud.life_menu.content_scroll.follow_focus,"scroll follows full menu focus")
		send("Escape")
		var routes={"stories":"community","mail":"mail","processing":"kitchen","farmcare":"farm_planner","animals":"ranch","storage":"market","home":"home","projects":"community","tools":"tools","decor":"building","skills":"skills","catalog":"museum","archive":"community","gatherings":"community","appearance":"settings","economy":"market","item-icons":"item_catalog"}
		for entry in fixture.menu:
			check(hud.life_menu.expansion_buttons[entry[0]].text==str(entry[1])+("\n"+str(entry[2]) if str(entry[2])!="" else ""),"source menu label "+str(entry[0]))
			hud.show_life_menu()
			hud.life_menu.expansion_buttons[entry[0]].pressed.emit()
			check(not hud.life_menu.visible and state.ui_open and bool(hud.call(routes[entry[0]]+"_open")),"source expansion route "+str(entry[0])+"/"+room)
			if entry[0]=="processing":check(hud.kitchen_panel.mode=="process","processing page")
			if entry[0]=="skills":check(hud.skills_panel.visible,"skill selection remains reachable")
			if entry[0]=="archive":check(hud.community_panel.active_tab=="archives","archive page")
			if entry[0]=="gatherings":check(hud.community_panel.active_tab=="gatherings","gatherings page")
			if entry[0]=="storage":check(hud.market_panel.mode=="inventory" and hud.market_panel.inventory_side=="storage","storage page")
			if entry[0]=="economy":check(hud.market_panel.mode=="business","economy page")
			send("Escape")
			check(not state.ui_open,"source expansion closes "+str(entry[0]))
			await process_frame
		send("b")
		check(hud.market_open() and hud.market_panel.inventory_side=="bag","bag resets previous storage side")
		send("Escape")
		world.queue_free()
		current_scene=null
		await process_frame
	print("HOTKEY_DISPATCH_SOURCE_SMOKE: %d passed, %d failed; %d cases"%[passed,failed,fixture.rows.size()])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
