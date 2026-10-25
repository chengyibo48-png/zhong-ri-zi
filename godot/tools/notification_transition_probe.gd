extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle()->void:
 await process_frame
 await process_frame
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state=root.get_node("GameState");state.set_process(false)
 state.feedback.prefs.quiet=false;state.feedback.prefs.motion="reduced";state.notification_queue.rows.clear()
 var transition_row:Dictionary={}
 for room in ["","home-granny"]:
  state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud
  if hud.onboarding_open():hud.toggle_onboarding()
  var queue:RefCounted=state.notification_queue
  if room!="":
   var arrived_at:float=Time.get_ticks_msec()/1000.0
   if float(transition_row.expires)>arrived_at:
    check(queue.rows.size()==1 and queue.rows[0].id==transition_row.id and queue.rows[0].message=="跨场景通知","scene preserves unexpired original-duration queue")
   else:
    check(queue.rows.is_empty(),"scene expires original-duration queue at wall-clock deadline")
   # Independently verify a still-live queue through real scene construction.
   queue.append("长有效期跨场景验证",false,false,300.0,arrived_at)
   var live_id:int=queue.rows.back().id
   change_scene_to_file("res://scenes/interior.tscn");await settle()
   world=current_scene;world.set_process(false);world.player.set_physics_process(false);hud=world.hud
   if hud.onboarding_open():hud.toggle_onboarding()
   print("TRANSITION_QUEUE_PROBE "+JSON.stringify(queue.rows))
   check(queue.rows.size()==1 and queue.rows[0].id==live_id and queue.rows[0].message=="长有效期跨场景验证","real scene preserves independently live model identity")
   check(hud.notification_stack.column.get_child_count()==1,"new scene renders live transition notification")
  queue.rows.clear();hud.notification_stack.refresh()
  hud.show_notification("一");hud.show_notification("二",false,true);hud.show_notification("三",true)
  check(queue.rows.size()==3 and queue.rows[0].text=="一" and queue.rows[1].text=="二 · 查看回响 →" and queue.rows[2].error,"actual payloads")
  await settle()
  var nodes:Array=hud.notification_stack.column.get_children()
  check(nodes.size()==3 and nodes[0] is PanelContainer and nodes[1] is Button and nodes[2] is PanelContainer,"only important is button")
  check(nodes[0].get_theme_stylebox("panel").bg_color==Color("fff5dcec") and nodes[2].get_child(0).get_theme_color("font_color")==Color("947047"),"source toast colors survive native theme application")
  var first:Node=nodes[0]
  var second:Node=nodes[1]
  hud.show_notification("四")
  check(queue.rows.size()==3 and queue.rows[0].message=="二" and queue.rows[2].message=="四","max three evicts oldest")
  check(hud.notification_stack.column.get_children()[0]==second,"existing toast nodes preserved on append")
  check(not first.is_inside_tree(),"evicted node removed")
  var old_id:int=queue.rows[0].id
  hud.show_notification("二",false,true)
  check(queue.rows[2].id!=old_id and queue.rows[2].message=="二" and queue.rows.size()==3,"duplicate replaced and moved last")
  state.feedback.prefs.quiet=true
  var quiet_before:Array=queue.rows.duplicate(true)
  hud.show_notification("静音普通")
  check(queue.rows==quiet_before,"quiet suppresses ordinary")
  hud.show_notification("静音错误",true)
  check(queue.rows.back().error,"quiet keeps errors")
  hud.show_notification("静音重要",false,true)
  check(queue.rows.back().important,"quiet keeps important")
  state.feedback.prefs.quiet=false
  queue.rows.clear();hud.notification_stack.refresh();hud.show_notification("页面背后的通知",false,true)
  var behind:Array=queue.rows.duplicate(true)
  var panels:Array=[hud.life_menu,hud.kitchen_heat_panel,hud.seed_picker,hud.map_panel,hud.community_panel,hud.skills_panel,hud.help_panel,hud.feedback_panel,hud.sleep_panel,hud.mail_panel,hud.item_catalog_panel,hud.settings_panel,hud.save_panel,hud.market_panel,hud.weather_panel,hud.forage_panel,hud.fishing_panel,hud.kitchen_panel,hud.tool_panel,hud.farm_facility_panel,hud.farm_planner_panel,hud.home_panel,hud.neighbor_journal,hud.museum_panel,hud.festival_panel,hud.building_panel,hud.ranch_panel,hud.gift_panel]
  for panel in panels:
   panel.show();state.ui_open=true
   hud.show_notification("页面提示 "+panel.get_script().resource_path,true)
   var column:VBoxContainer=panel.get_meta("notification_column")
   check(column.get_node("ModalStatus/Message").text=="页面提示 "+panel.get_script().resource_path,"inline delivery "+panel.get_script().resource_path)
   hud.show_notification("替换后的提示")
   check(column.find_children("ModalStatus","PanelContainer",false,false).size()==1 and column.get_node("ModalStatus/Message").text=="替换后的提示","inline replaces "+panel.get_script().resource_path)
   check(queue.rows==behind,"inline preserves world expiry "+panel.get_script().resource_path)
   check(panel.z_index==20 and hud.notification_stack.z_index==5,"source layers")
   preload("res://scripts/modal_status.gd").clear_message(panel)
   check(column.get_node_or_null("ModalStatus")==null,"render clears previous status")
   panel.hide();state.ui_open=false
  hud.life_menu.open_panel()
  hud.show_notification("旧页面提示")
  hud.life_menu.close();hud.life_menu.open_panel()
  check(hud.life_menu.get_meta("notification_column").get_node_or_null("ModalStatus")==null,"real open lifecycle clears status")
  hud.life_menu.close()
  var click:Button=hud.notification_stack.column.get_children()[0]
  click.pressed.emit()
  check(hud.feedback_panel.visible,"important click opens feedback")
  hud.close_top_panel()
  var deadline:float=Time.get_ticks_msec()/1000.0+0.03
  queue.rows[0].expires=deadline
  while Time.get_ticks_msec()/1000.0<=deadline+0.03:await process_frame
  await settle()
  check(queue.rows.is_empty() and hud.notification_stack.column.get_child_count()==0,"independent wall clock expiry while running "+room)
  hud.show_notification("不会被新消息重启动画");await settle()
  var original:Node=hud.notification_stack.column.get_children()[0]
  hud.show_notification("普通消息");await settle()
  check(hud.notification_stack.column.get_children()[0]==original and original.modulate.a==1.0,"reduced motion and retained node "+room)
  for size in [Vector2i(960,600),Vector2i(640,360)]:
   root.size=size;await settle()
   var rect:Rect2=hud.notification_stack.column.get_global_rect()
   check(rect.position.x>=0 and rect.end.x<=hud.notification_stack.get_viewport_rect().size.x,"responsive stack width")
  queue.rows.clear();hud.notification_stack.refresh();hud.show_notification("跨场景通知")
  transition_row=queue.rows[0].duplicate(true)
 if OS.get_environment("NOTIFICATION_SCREENSHOT")!="":
  root.size=Vector2i(960,600);await settle()
  current_scene.hud.show_notification("收下青菜 × 3")
  current_scene.hud.show_notification("灶台加工已完成",false,true)
  await settle();await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("NOTIFICATION_SCREENSHOT"))
 print("Notification UI: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
