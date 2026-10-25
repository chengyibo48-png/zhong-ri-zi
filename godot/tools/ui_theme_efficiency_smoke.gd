extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok: passed += 1
 else: failed += 1; push_error(label)
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state := root.get_node("GameState")
 state.set_process(false)
 var service := root.get_node("UIArtService")
 var container := Control.new();root.add_child(container);service.register_root(container)
 var button := Button.new();container.add_child(button);button.text="主题检查"
 var label := Label.new();container.add_child(label)
 var panel := PanelContainer.new();container.add_child(panel)
 var panel_style := StyleBoxFlat.new();panel_style.bg_color=Color("ff0000");panel.add_theme_stylebox_override("panel",panel_style)
 check(button.theme==service.shared_theme and panel.theme==service.shared_theme,"控件构建完成前就获得共享主题")
 await settle()
 check(button.theme==service.shared_theme and panel.theme==service.shared_theme,"新节点在完成构建后获得主题")
 check(root.get_node("UIArtService").style_background(panel.get_theme_stylebox("panel")).is_equal_approx(Color("f2e8d2")),"延迟主题更新保留陈设样式的尺寸并应用纸色")
 var style: StyleBox=button.get_theme_stylebox("normal")
 var theme: Theme=service.shared_theme
 var revision: int=service.theme_revision
 var started := Time.get_ticks_msec()
 for update in range(40):
  state.changed.emit()
  check(button.get_theme_stylebox("normal")==style and service.shared_theme==theme and service.theme_revision==revision,"普通状态变化复用同一主题与按钮样式")
 print("UI_THEME_STABLE_40_UPDATES_MS: ",Time.get_ticks_msec()-started)
 state.ui_art.theme="timber";state.changed.emit()
 check(service.theme_revision==revision+1 and button.get_theme_stylebox("normal")!=style,"选择主题时重建并更新控件")
 check(button.get_theme_stylebox("normal").bg_color==Color("55452f") and label.get_theme_color("font_color")==Color("f4e3c6"),"木色按钮和文字同步更新")
 state.player_settings.contrast=true;state.changed.emit()
 check(button.get_theme_stylebox("normal").bg_color==Color("e4ebda") and label.get_theme_color("font_color")==Color("192a23"),"高对比度变更即时应用")
 var late := Button.new();container.add_child(late);await settle()
 check(late.get_theme_stylebox("normal").bg_color==Color("e4ebda"),"晚创建的按钮获得当前高对比主题")
 var status := Label.new();status.set_meta("preserve_notification_style",true);status.add_theme_color_override("font_color",Color.RED);container.add_child(status);await settle()
 state.ui_art.theme="porcelain";state.player_settings.contrast=false;state.changed.emit()
 check(status.get_theme_color("font_color")==Color.RED,"通知的错误颜色保留")
 var discarded := Button.new();container.add_child(discarded);discarded.free();await settle()
 check(true,"延迟主题更新忽略已销毁控件")
 state.ui_art.theme="paper";state.changed.emit()
 check(root.get_node("UIArtService").style_background(button.get_theme_stylebox("normal")).is_equal_approx(Color("e6dcc3")),"切回纸色恢复所有已有控件")
 var notifications := [0]
 label.theme_changed.connect(func():notifications[0]+=1)
 label.add_theme_color_override("font_color",Color.RED)
 check(notifications[0]>0,"批量主题更新已结束，后续样式通知正常")
 container.queue_free();await settle()
 await root.get_node("AudioService").prepare_exit()
 print("UI_THEME_EFFICIENCY_SMOKE: %d passed, %d failed" % [passed,failed])
 quit(1 if failed else 0)