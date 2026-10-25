extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func _run() -> void:
	var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp + "/"):
		quit(1)
		return
	create_timer(55).timeout.connect(func(): quit(1))
	root.size = Vector2i(960,600)
	var state = root.get_node("GameState")
	state.current_interior = ""
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var hud = current_scene.hud
	hud.refresh()
	await process_frame
	_check(hud.date_card.get_global_rect().size.y < 170,"日期卡高度不包含全套按键说明")
	_check(hud.player_card.get_global_rect().position.y >= 400 and hud.player_card.get_global_rect().end.y <= 600,"角色状态卡位于底部可见区域")
	var center := Rect2(360,180,280,220)
	_check(not hud.date_card.get_global_rect().intersects(center) and not hud.player_card.get_global_rect().intersects(center),"常驻状态卡避开中心活动区")
	_check(hud.help_label.text == "按键 · ?" and hud.help_label.tooltip_text.contains("Q 选种") and hud.help_label.tooltip_text.contains("点击指南查看完整帮助"),"紧凑操作提示保留详细快捷键说明")
	state.stamina = 42
	state.money = 321
	state.player_name = "小满"
	hud.refresh()
	_check(hud.energy_bar.value == 42 and hud.player_label.text.contains("321") and hud.player_label.text.contains("42"),"体力条、金币和名字同步")
	_check(hud.forecast_button.text.contains(state.weather_for(state.day + 1)),"明日预报同步")
	hud.date_button.pressed.emit()
	_check(hud.weather_open() and hud.weather_panel.notebook.current_tab == 1,"日期按钮进入节气页")
	hud.close_top_panel()
	hud.forecast_button.pressed.emit()
	_check(hud.weather_open(),"预报按钮打开天气")
	hud.close_top_panel()
	for entry in [["map","map_open"],["save","saves_open"],["menu","life_menu_open"]]:
		hud.quick_buttons[entry[0]].pressed.emit()
		_check(hud.life_menu.visible if entry[0] == "menu" else hud.call(entry[1]),"常驻入口打开 " + str(entry[0]))
		if hud.life_menu.visible: hud.life_menu.close()
		else: hud.close_top_panel()
	hud.bag_button.pressed.emit()
	_check(hud.market_open() and hud.market_panel.mode == "inventory","背包按钮进入随身背包")
	hud.close_top_panel()
	hud.seed_button.pressed.emit()
	_check(hud.seed_picker.visible,"种子按钮打开选种页")
	hud.close_top_panel()
	hud.toggle_hud()
	_check(not hud.ambient_hud.visible and hud.restore_hud_button.visible,"收起后仅显示恢复按钮")
	hud.toggle_hud()
	state.player_settings.hints = false
	hud.refresh()
	_check(not hud.help_label.visible and hud.date_card.visible and hud.player_card.visible,"关闭提示保留日期与状态")
	state.player_settings.textScale = 1.4
	hud.onboarding_panel.open_panel()
	hud.refresh()
	await process_frame
	await process_frame
	_check(hud.player_card.get_global_rect().end.y <= 600,"放大字体保持状态卡在屏幕内")
	var hint = hud.onboarding_panel.get_child(0)
	_check(not hint.get_global_rect().intersects(hud.player_card.get_global_rect()),"放大字体时新手卡与状态卡不重叠")
	if hint.get_global_rect().intersects(hud.date_card.get_global_rect()): print("Hint/date rectangles: ",hint.get_global_rect()," / ",hud.date_card.get_global_rect())
	_check(not hint.get_global_rect().intersects(hud.date_card.get_global_rect()),"放大字体时新手卡与日期卡不重叠")
	state.notification_queue.rows.clear();hud.notification_stack.refresh()
	state.feedback.prefs.seconds = 0.15
	state.message = "同样的操作提示"
	_check(state.notification_queue.rows.size()==1 and state.notification_queue.rows[0].text==state.message,"新消息即时进入原版队列")
	var deadline:float=Time.get_ticks_msec()/1000.0+0.2
	while Time.get_ticks_msec()/1000.0<=deadline:await process_frame
	await process_frame
	_check(state.notification_queue.rows.is_empty(),"通知按真实时钟设定时长消失")
	hud.refresh()
	_check(state.notification_queue.rows.is_empty(),"常规刷新不复活过期通知")
	state.message = "同样的操作提示"
	_check(state.notification_queue.rows.size()==1,"再次执行同样操作仍然显示通知")
	state.message = ""
	_check(state.notification_queue.rows.size()==1,"空操作文字不删除已有独立通知")
	state.notification_queue.rows.clear();hud.notification_stack.refresh()
	state.feedback.prefs.seconds = 8
	state.message = "完整通知文字"
	_check(float(state.notification_queue.rows[0].expires)-Time.get_ticks_msec()/1000.0>7.5 and state.notification_queue.rows[0].text==state.message,"通知时长偏好与完整文本保留")
	state.message = "操作完成，保留此通知"
	var saved: bool = state.save_game(state.SAVE_PATH,true)
	_check(saved and state.message == "操作完成，保留此通知","静默自动保存保留操作通知")
	state._flush_autosave()
	_check(state.message == "操作完成，保留此通知","自动保存入口不覆盖消息")
	_check(state.save_game() and state.message.contains("已保存"),"手动保存显示确认")
	print("HUD layout smoke: %d passed, %d failed" % [passed,failed])
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed else 0)
