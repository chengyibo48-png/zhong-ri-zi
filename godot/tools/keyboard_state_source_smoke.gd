extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:
		failed+=1
		if failed<=20:push_error(label)
func code(key:String)->int:
	match key:
		"ArrowUp":return KEY_UP
		"ArrowDown":return KEY_DOWN
		"ArrowLeft":return KEY_LEFT
		"ArrowRight":return KEY_RIGHT
		"Shift":return KEY_SHIFT
		"Escape":return KEY_ESCAPE
		"!":return KEY_1
	return key.to_upper().unicode_at(0)
func event(key:String,pressed:bool=true,echo:bool=false)->InputEventKey:
	var value:=InputEventKey.new()
	value.keycode=code(key)
	value.pressed=pressed
	value.echo=echo
	value.unicode=key.unicode_at(0) if key.length()==1 else 0
	return value
func send(key:String,pressed:bool=true,echo:bool=false)->void:
	Input.parse_input_event(event(key,pressed,echo))
	Input.flush_buffered_events()
func run()->void:
	await process_frame
	var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
	create_timer(120).timeout.connect(func():push_error("Keyboard timeout");quit(1))
	var state=root.get_node("GameState")
	state.set_process(false)
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("KEYBOARD_STATE_FIXTURE")))
	var keyboard=load("res://scripts/source_keyboard.gd").new()
	for row in fixture.rows:
		keyboard.clear()
		for key in row.seed:keyboard.keys[key]=true
		for sample in row.samples:
			var interrupted:=false
			if sample.operation=="clear":keyboard.clear()
			else:
				var input:=event(str(sample.key),sample.operation!="up",sample.operation=="echo")
				input.unicode=int(sample.unicode)
				input.ctrl_pressed=bool(sample.ctrl)
				input.meta_pressed=bool(sample.meta)
				input.alt_pressed=bool(sample.alt)
				interrupted=keyboard.accept(input,row.bindings,row.mode in ["panel","action"],row.mode in ["input","textarea","select"])
			var direction:Vector2=keyboard.direction(row.bindings)
			check(keyboard.keys.keys()==sample.expected.keys,"original key set "+str(row.mode)+"/"+str(sample))
			check(direction==Vector2(float(sample.expected.x),float(sample.expected.y)),"original movement axes")
			check(keyboard.fast()==bool(sample.expected.fast),"original shift latch")
			check(interrupted==bool(sample.expected.interrupted),"original press/echo route interruption")
	check(fixture.rows.size()==960,"fixture coverage")
	# Actual Godot input reaches the logical set before GUI and world routing.
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var world=current_scene
	world.set_process(false)
	world.player.set_physics_process(false)
	if world.hud.onboarding_open():world.hud.toggle_onboarding()
	state.ui_open=false
	state.current_interior=""
	state.source_keyboard.clear()
	# Execute original capture outcomes against the actual settings control.
	for row in fixture.captures:
		state.player_settings.bindings=row.before.duplicate(true)
		world.hud.settings_panel.open_panel()
		world.hud.settings_panel.binding_buttons.right.pressed.emit()
		var capture_event:=event(str(row.key),true,bool(row.repeat))
		capture_event.ctrl_pressed=row.modifier=="ctrl"
		capture_event.meta_pressed=row.modifier=="meta"
		capture_event.alt_pressed=row.modifier=="alt"
		world.hud.settings_panel.capture_event_key(capture_event)
		check(state.player_settings.bindings==row.expected.bindings,"original capture binding swap")
		check(world.hud.settings_panel.capturing==("" if row.expected.capturing==null else str(row.expected.capturing)),"original capture acceptance")
	check(fixture.captures.size()==120,"capture coverage")
	world.hud.settings_panel.close()
	state.player_settings.bindings=fixture.rows[0].bindings.duplicate(true)
	state.set_player_navigation_position({"x":2831.0,"y":1652.0,"direction":"down"})
	world.player.global_position=Vector2(2831,1652)
	send("d")
	check(Input.is_key_pressed(KEY_D) and state.source_keyboard.keys.has("d"),"actual physical and logical key accepted")
	var before:Dictionary=state.player_navigation_position()
	world.player._physics_process(0.05)
	check(state.player_navigation_position().x>before.x,"real callback moves from logical key")
	world.hud.life_menu.open_panel()
	check(state.source_keyboard.keys.is_empty() and Input.is_key_pressed(KEY_D),"menu clears logical set without forging physical release")
	world.hud.life_menu.close()
	before=state.player_navigation_position()
	world.player._physics_process(0.05)
	check(state.player_navigation_position()==before,"menu close cannot resume held key")
	send("d",true,true)
	check(state.source_keyboard.keys.has("d"),"new repeat event may latch movement again")
	world.player._physics_process(0.05)
	check(state.player_navigation_position().x>before.x,"repeat movement follows original keydown prefix")
	state.begin_action({"kind":"read","duration":0.1},{"kind":"test"},func():pass)
	check(state.source_keyboard.keys.is_empty(),"action begin clears key set")
	state._process_action(0.1)
	before=state.player_navigation_position()
	world.player._physics_process(0.05)
	check(not state.action_busy() and state.player_navigation_position()==before,"action completion does not resume physical held key")
	send("d",false)
	var text:=LineEdit.new()
	world.add_child(text)
	text.grab_focus()
	send("d")
	check(state.source_keyboard.keys.is_empty(),"focused native text input blocks movement latch")
	send("d",false)
	text.release_focus()
	text.queue_free()
	send("d")
	state._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(state.source_keyboard.keys.is_empty(),"application focus loss clears keys")
	# An already held key and a mouse walk preserve the path until a fresh keydown.
	send("d",true,true)
	world.player.walk_source_path=[{"x":3000.0,"y":1652.0}]
	world.player.walk_path.clear()
	world.player.walk_path.append(Vector2(3000,1652))
	world.player.walk_index=0
	state.walking_target={"kind":"walk","x":3000.0,"y":1652.0}
	world.player._physics_process(0.05)
	check(not world.player.walk_source_path.is_empty() and not state.walking_target.is_empty(),"held key does not invent a fresh route interruption")
	send("d",true,true)
	check(world.player.walk_source_path.is_empty() and state.walking_target.is_empty(),"repeat event cancels route synchronously")
	send("d",false)
	# queueFarm closes even an absent panel in the original app.
	send("d",true,true)
	check(state.queue_farm_tasks([{"index":0,"action":"inspect"}]),"direct farm queue starts without an open menu")
	check(state.source_keyboard.keys.is_empty() and not state.walking_target.is_empty(),"batch start clears a physical held movement key")
	state.stop_walking()
	send("d",false)
	# Swapping a movement key with a menu key must not fire the old alias.
	var old_bindings:Dictionary=state.player_settings.bindings.duplicate(true)
	state.player_settings.bindings.up="b"
	state.player_settings.bindings.bag="w"
	send("b")
	check(state.source_keyboard.direction(state.player_settings.bindings)==Vector2.UP and not state.ui_open,"rebound bag letter now moves")
	send("b",false)
	send("w")
	check(world.hud.market_open() and state.source_keyboard.keys.is_empty(),"rebound movement letter now opens bag")
	send("w",false)
	world.hud.market_panel.close()
	state.player_settings.bindings=old_bindings
	# Actual remapping captures UI input without latching movement.
	world.hud.settings_panel.open_panel()
	world.hud.settings_panel.binding_buttons.right.pressed.emit()
	send("z")
	await process_frame
	check(state.player_settings.bindings.right=="z" and state.source_keyboard.keys.is_empty(),"native capture updates binding without movement")
	send("z",false)
	world.hud.settings_panel.binding_buttons.right.pressed.emit()
	send("Escape")
	check(world.hud.settings_panel.capturing=="" and world.hud.settings_panel.visible and state.ui_open,"capture Escape cancels capture before closing the menu")
	send("Escape",false)
	world.hud.settings_panel.binding_buttons.right.pressed.emit()
	var dotted:=event("İ")
	dotted.keycode=KEY_I
	Input.parse_input_event(dotted)
	Input.flush_buffered_events()
	check(state.player_settings.bindings.right=="z" and world.hud.settings_panel.capturing=="right","capture rejects full lowercase dotted I expansion")
	var dotted_release:=dotted.duplicate()
	dotted_release.pressed=false
	Input.parse_input_event(dotted_release)
	Input.flush_buffered_events()
	var kelvin:=event("K",true,true)
	kelvin.keycode=KEY_K
	kelvin.ctrl_pressed=true
	Input.parse_input_event(kelvin)
	Input.flush_buffered_events()
	check(state.player_settings.bindings.right=="k" and world.hud.settings_panel.capturing=="","capture uses normalized event key and accepts repeat before GUI")
	var kelvin_release:=kelvin.duplicate()
	kelvin_release.pressed=false
	Input.parse_input_event(kelvin_release)
	Input.flush_buffered_events()
	world.hud.settings_panel.binding_buttons.right.pressed.emit()
	send("z")
	send("z",false)
	world.hud.settings_panel.close()
	send("z")
	check(state.source_keyboard.direction(state.player_settings.bindings)==Vector2.RIGHT,"new bound key drives movement")
	send("z",false)
	send("d")
	check(state.source_keyboard.direction(state.player_settings.bindings)==Vector2.ZERO,"old binding no longer drives movement")
	send("d",false)
	send("z")
	check(not state._make_save_data().has("source_keyboard"),"logical keys are runtime only")
	check(state.save_game("user://keyboard-state.json",true) and state.load_game("user://keyboard-state.json"),"real keyboard save roundtrip")
	check(state.source_keyboard.keys.is_empty(),"loading clears old held input")
	send("z",false)
	send("Shift",false)
	world.queue_free()
	current_scene=null
	await process_frame
	print("KEYBOARD_STATE_SOURCE_SMOKE: %d passed, %d failed; %d cases"%[passed,failed,fixture.rows.size()])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
