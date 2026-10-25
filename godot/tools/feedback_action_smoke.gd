extends SceneTree
var passed := 0
var failed := 0
var notices: Array = []
var order: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else: failed += 1; push_error(label)
func finish(state: Node) -> void:
    for i in 50: state._process_action(0.1)
func reset(state: Node) -> void:
    state.cancel_action(false)
    state.feedback = {"version":1,"next":1,"rows":[],"days":[],"seen":[],"prefs":{"pace":"normal","motion":"full","floating":"normal","seconds":5,"quiet":false}}
    state.feedback_action_runtime={"floats":[],"clock":0.0,"serial":0}
    notices.clear(); order.clear()
func run() -> void:
    create_timer(60).timeout.connect(func():quit(1))
    await process_frame
    var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
    if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1); return
    var state := root.get_node("GameState"); state.set_process(false)
    change_scene_to_file("res://scenes/main.tscn")
    await process_frame; await process_frame
    var hud=current_scene.hud
    if hud.onboarding_open():hud.toggle_onboarding()
    current_scene.player.set_physics_process(false); current_scene.set_process(false)
    state.feedback_toast_requested.connect(func(text:String,priority:int):notices.append([text,priority]);order.append("toast"))
    reset(state)
    state.money+=1;state.changed.emit()
    check(state.feedback.rows.is_empty() and state.feedback.days.is_empty(),"changed does not create phantom action record")
    check(state.begin_action({"kind":"read","label":"读手记","duration":0.1},{"kind":"ui"},func():pass),"start noop")
    finish(state)
    check(state.feedback.rows.is_empty(),"no changes no settlement")
    var old_money:int=state.money
    state.begin_action({"kind":"trade","label":"卖出菜篮","duration":0.2},{"kind":"ui","x":0,"y":80},func():state.money+=7;state.changed.emit();order.append("commit"))
    check(state.feedback.rows.is_empty(),"start does not settle")
    finish(state)
    check(state.money==old_money+7 and state.feedback.rows.size()==1,"exactly one settlement after commit")
    check(state.feedback.rows[0].title=="卖出菜篮" and state.feedback.rows[0].text=="+7 元" and state.feedback.rows[0].key=="action/trade/ui/1","source title text and action key")
    check(state.feedback.days[0].income==7 and state.feedback.days[0].actions==1,"day accounting")
    check(notices.is_empty(),"ordinary finish no important toast")
    check(state.feedback_action_runtime.floats[0].text=="+7 元" and state.feedback_action_runtime.floats[0].x==0,"money float and zero target coordinate")
    var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(state.SAVE_PATH))
    check(saved.feedback.rows.size()==1 and saved.feedback.rows[0].text=="+7 元","settlement in actual saved file")
    state._process_action(0.1)
    check(state.feedback.rows.size()==1,"completed action not replayed")
    reset(state)
    state.begin_action({"kind":"trade","label":"取消","duration":1.0},{"kind":"ui"},func():state.money+=20)
    state.cancel_action()
    finish(state)
    check(state.feedback.rows.is_empty() and state.feedback_action_runtime.floats.is_empty(),"cancel does not settle")
    reset(state)
    state.begin_action({"kind":"care","label":"这块田","duration":0.1},{"kind":"farm-task","index":0},func():state.plots[1].moisture-=10;state.changed.emit())
    finish(state)
    check(state.feedback.rows.is_empty(),"unrelated plot excluded")
    reset(state)
    state.begin_action({"kind":"care","label":"浇水","duration":0.1},{"kind":"farm-task","index":0},func():state.plots[0].moisture+=10;state.changed.emit())
    finish(state)
    check(state.feedback.rows.size()==1 and state.feedback.rows[0].text.begins_with("水分 ") and state.feedback.rows[0].key=="action/care/farm/1","targeted field source record")
    reset(state)
    state.begin_action({"kind":"build","label":"改良农具","duration":0.1},{"kind":"tools"},func():
        state.toolkit.tools.hoe.level+=1
        state.changed.emit()
        check(state.feedback.rows.is_empty(),"domain changed before page switch does not settle")
        hud.show_feedback()
        order.append("page")
    )
    finish(state)
    check(order==["page","toast"],"important toast follows resulting page")
    check(state.feedback.rows.size()==1 and state.feedback.rows[0].priority==1 and state.feedback.rows[0].link=="tools","tool upgrade important result")
    check(notices.size()==1,"important result emitted once")
    var status:Node=hud.feedback_panel.get_meta("notification_column").get_node_or_null("ModalStatus")
    check(status!=null and status.get_node("Message").text==state.feedback.rows[0].text,"important settlement appears inside resulting page")
    hud.close_top_panel()
    reset(state)
    var saved_state:Dictionary=state._make_save_data()
    state.begin_action({"kind":"read","label":"载入","duration":0.1},{"kind":"ui"},func():state.load_game_data(saved_state))
    finish(state)
    check(state.feedback.rows.is_empty(),"state replacement inside commit rejects obsolete settlement")
    reset(state)
    state.begin_action({"kind":"read","label":"换房","duration":0.1},{"kind":"ui"},func():state.money+=10)
    state.current_interior="home-granny"
    finish(state)
    check(state.feedback.rows.is_empty(),"room change rejects old action")
    state.current_interior=""
    reset(state)
    state.feedback_action_runtime.floats=[{"key":"a","text":"a","at":0.0,"x":10,"y":20}]
    state.tick_feedback_floats(10)
    check(is_equal_approx(state.feedback_action_runtime.clock,0.1),"float clock clamps delta")
    state.tick_feedback_floats(0)
    check(is_equal_approx(state.feedback_action_runtime.clock,0.1),"paused float clock")
    for i in 44:state.tick_feedback_floats(0.1)
    check(state.feedback_action_runtime.floats.is_empty(),"float expiration at 4.5")
    state.feedback_action_runtime.floats=[{"key":"a","text":"a","at":4.5,"x":10,"y":20}]
    state.current_interior="home-granny";state.tick_feedback_floats(0)
    check(state.feedback_action_runtime.floats.is_empty(),"room transition clears floats")
    state.current_interior=""
    reset(state)
    var effects:Node=current_scene.get_node("WorldEffects")
    effects.set_process(false)
    var at:Dictionary=state.player_navigation_position()
    state.begin_action({"kind":"harvest","label":"收获菜篮","duration":0.1},{"kind":"farm-task","x":at.x,"y":at.y},func():state._grant_quality("cabbage",2,0);state.changed.emit())
    finish(state)
    state.begin_action({"kind":"harvest","label":"再收一篮","duration":0.1},{"kind":"farm-task","x":at.x,"y":at.y},func():state._grant_quality("cabbage",1,0);state.changed.emit())
    finish(state)
    effects._process(0.1)
    check(effects.float_rows.size()==1 and effects.float_rows[0].text=="+3 普通小青菜","actual world renderer uses merged item float")
    var clock:float=state.feedback_action_runtime.clock
    state.ui_open=true
    effects._process(0.1)
    check(state.feedback_action_runtime.clock==clock,"open page pauses actual world float clock")
    state.ui_open=false
    state.feedback.prefs.floating="compact"
    state.feedback_action_runtime.floats.append({"key":"result","text":"摆摊货款 +27 元","at":clock,"x":at.x,"y":at.y})
    effects._process(0)
    check(effects.float_rows.size()==1 and effects.float_rows[0].text=="摆摊货款 +27 元","compact renders last float while retaining runtime history")
    check(state.feedback_action_runtime.floats.size()==2,"compact does not discard merge history")
    state.feedback.prefs.floating="normal"
    effects._process(0)
    if OS.get_environment("FEEDBACK_ACTION_SCREENSHOT")!="":
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(OS.get_environment("FEEDBACK_ACTION_SCREENSHOT"))
    print("Feedback action integration: %d passed, %d failed"%[passed,failed])
    await root.get_node("AudioService").prepare_exit()
    quit(1 if failed else 0)

