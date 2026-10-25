extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("_run")
func _check(ok: bool,label: String):
 if ok: passed+=1
 else: failed+=1;push_error(label)
func _json(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func _stock(actual: Dictionary,expected: Dictionary) -> bool:
 for id in actual:
  if int(actual[id])!=int(expected.get(id,0)): return false
 for id in expected:
  if int(expected[id])!=int(actual.get(id,0)): return false
 return true
func _quality(actual: Dictionary,expected: Dictionary) -> bool:
 var ids: Array=actual.keys()
 for id in expected:
  if not ids.has(id): ids.append(id)
 for id in ids:
  if _json(actual.get(id,[0,0,0]))!=_json(expected.get(id,[0,0,0])):return false
 return true
func _finish_household(state):
 for step in range(20):state._process_action(0.1)
func _settle():
 await process_frame
 await process_frame
func _run():
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(90).timeout.connect(func():quit(1))
 root.size=Vector2i(960,600)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOME_PANEL_FIXTURE")))
 var script=load("res://scripts/game_state.gd")
 var model=script.new()
 model._load_content();model._load_initial_state()
 for row in fixture.rows:
  var label:=str(row.op)+"/"+str(row.variant)
  _check(model.load_game_data(model.convert_external_save(row.before)),"全模块家庭输入 "+label)
  model.current_interior=""
  var region:Dictionary=model.world_village.offsets["town" if str(row.variant)=="town" else "pasture" if str(row.variant)=="pasture" else "farm"]
  model.player_position=Vector2(float(region.x)+500,float(region.y)+500)
  var ok:bool
  if str(row.op)=="host":ok=model.host_meal("granny","greens")
  elif str(row.op)=="pet":
   var before_day:int=model.pet_state.patted
   model.pat_companion();ok=before_day!=model.day
  else:ok=model.share_life(str(row.op),"greens")
  var e:Dictionary=row.expected
  _check(ok==bool(row.ok),"全模块家庭结果 "+label)
  _check(_stock(model.inventory,e.bag) and _quality(model.quality,e.quality),"料理数量品质 "+label)
  _check(_json(model.kitchen.lots)==_json(e.lots),"家庭食材新鲜度 "+label)
  var expected_marriage:Dictionary=e.marriage.duplicate(true)
  if expected_marriage.spouse==null:expected_marriage.spouse=""
  _check(_json(model.marriage)==_json(expected_marriage),"每周共同安排与八十记忆 "+label)
  _check(_json(model.relations)==_json(e.relations) and _json(model.season_events)==_json(e.seasonEvents),"信任与家宴周记录 "+label)
  _check(_json(model.skills)==_json(e.skills) and _json(model.known_recipes)==_json(e.recipes),"社交经验和学习菜谱 "+label)
  _check(_json(model.pet_state)==_json(e.pet) and _json(model.ranch.pet)==_json(e.ranchPet),"陪玩每日上限和伙伴精力 "+label)
 model.free()
 var state=root.get_node("GameState")
 state.load_game_data(state.convert_external_save(fixture.source))
 state.current_interior=""
 var offset:Dictionary=state.world_village.offsets.farm
 state.player_position=Vector2(float(offset.x)+500,float(offset.y)+500)
 change_scene_to_file("res://scenes/main.tscn")
 await _settle()
 if current_scene.hud.onboarding_open():current_scene.hud.toggle_onboarding()
 var hud=current_scene.hud
 hud.show_life_menu();hud.life_menu.home_button.pressed.emit()
 var panel=hud.home_panel
 _check(hud.home_open() and state.ui_open and not hud.life_menu.visible,"生活菜单打开独立家庭页")
 _check(panel.guest_option.item_count==state.npc_catalog.size(),"所有二十四位邻居可邀请")
 _check(panel.spouse_section.visible and not panel.single_label.visible and panel.spouse_label.text.contains(state.npc_name("qiao")),"已婚状态姓名工作地点")
 _check(panel.shared_dish.item_count==1 and not panel.shared_dish.disabled,"料理从随身库存加载")
 var minutes_before:int=state.minutes
 current_scene._process(3.0)
 _check(state.minutes==minutes_before,"家庭页暂停世界时钟")
 var modal_key:=InputEventKey.new()
 modal_key.keycode=KEY_K;modal_key.pressed=true
 current_scene._unhandled_key_input(modal_key)
 modal_key.keycode=KEY_E;current_scene._unhandled_key_input(modal_key)
 _check(panel.visible and not hud.kitchen_open(),"户外家庭页阻止世界快捷键与交互穿透")
 panel._share("meal")
 _finish_household(state)
 _check(int(state.inventory.greens)==2 and panel.shared_buttons.meal.disabled and state.marriage.memories.size()==1,"点击共餐消费一道料理并禁用本周重复")
 for activity in ["visit","objects","plan"]:
  panel._share(activity)
  _finish_household(state)
 _check(state.marriage.memories.size()==4,"四类共同安排分别记录")
 panel._share("meal")
 _finish_household(state)
 _check(int(state.inventory.greens)==2 and state.marriage.memories.size()==4,"程序重复点击也拒绝")
 panel.guest_option.select(0)
 for index in range(panel.guest_option.item_count):
  if str(panel.guest_option.get_item_metadata(index))=="granny":panel.guest_option.select(index);break
 panel._host()
 _finish_household(state)
 _check(int(state.inventory.greens)==1 and panel.host_button.disabled,"指定邻居家宴消费和周上限")
 for row in fixture.rename:
  panel.pet_name.text=str(row.name);panel.pet_type.select(1);panel._save_pet()
  _finish_household(state)
  _check(str(state.pet_state.name)==str(row.expected) and str(state.pet_state.type)=="dog","原版命名规则 "+str(row.name))
 panel.pet_name.text="尚未保存"
 state.changed.emit()
 _check(panel.pet_name.text=="尚未保存","状态刷新保留未保存输入")
 panel._play_pet()
 _finish_household(state)
 _check(int(state.pet_state.bond)==3 and panel.pet_play.disabled,"陪玩后每日上限")
 panel._play_pet()
 _finish_household(state)
 _check(int(state.pet_state.bond)==3,"重复陪玩不加亲近")
 var relationship_before:Dictionary=state.relations.duplicate(true)
 var story_before:Dictionary=state.npc_stories.duplicate(true)
 var separation=hud.separation_panel
 panel._ask_separate()
 _check(separation.visible and str(state.marriage.spouse)=="qiao","分开生活必须二次确认")
 separation.cancel_button.pressed.emit()
 _check(not separation.visible and panel.visible and state.ui_open and str(state.marriage.spouse)=="qiao","关闭确认返回家庭页并继续暂停")
 panel._ask_separate();separation.confirm_button.pressed.emit()
 _finish_household(state)
 _check(str(state.marriage.spouse)=="" and state.relations==relationship_before and state.npc_stories==story_before,"分开保留关系和故事")
 _check(panel.single_label.visible and not panel.spouse_section.visible and panel.guest_option.item_count==24,"独居仍可邀请和陪玩")
 state.marriage.spouse="qiao";panel.refresh();panel._ask_separate();state.marriage.spouse="lin"
 separation.confirm_button.pressed.emit()
 _finish_household(state)
 _check(str(state.marriage.spouse)=="","按原版无参数确认处理当前伴侣")
 separation.cancel_button.pressed.emit()
 state.marriage.spouse="qiao";panel.refresh();panel._open_story()
 _check(not panel.visible and hud.npc_story_panel.visible and state.ui_open,"婚后故事打开当前伴侣故事")
 hud.npc_story_panel.close();hud.show_home()
 panel.pet_save.grab_focus()
 for frame in range(5):await process_frame
 _check(panel.scroll.scroll_vertical>0,"键盘焦点自动滚到宠物操作")
 state.player_settings.textScale=1.4
 hud._apply_text_scale()
 panel.pet_play.grab_focus()
 for frame in range(5):await process_frame
 var viewport_rect:Rect2=root.get_visible_rect()
 var outer:Control=panel.get_child(1)
 _check(viewport_rect.encloses(outer.get_global_rect()),"大字体家庭面板位于窗口内 "+str(outer.get_global_rect())+"/"+str(viewport_rect))
 var clip:Rect2=panel.scroll.get_global_rect()
 _check(clip.encloses(panel.pet_play.get_global_rect()),"大字体焦点操作完整可见")
 panel._ask_separate()
 var key:=InputEventKey.new()
 key.keycode=KEY_ESCAPE;key.pressed=true
 Input.parse_input_event(key);Input.flush_buffered_events()
 await _settle()
 _check(not separation.visible and not panel.visible and str(state.marriage.spouse)=="qiao" and not state.ui_open,"原版 Esc 关闭确认并保留关系")
 key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=false
 Input.parse_input_event(key);Input.flush_buffered_events()
 panel._ask_separate()
 var pad:=InputEventJoypadButton.new()
 pad.button_index=JOY_BUTTON_B;pad.pressed=true
 Input.parse_input_event(pad);Input.flush_buffered_events()
 _check(separation.visible,"原始手柄事件不在采样之前关闭确认")
 state.poll_source_gamepad(1000.0,current_scene.player,{"connected":true,"buttons":[],"axes":[0.0,0.0]})
 state.poll_source_gamepad(1001.0,current_scene.player,{"connected":true,"buttons":[false,true],"axes":[0.0,0.0]})
 await _settle()
 _check(not separation.visible and not panel.visible and not state.ui_open,"原版手柄 B 关闭确认并恢复世界")
 hud.close_top_panel()
 _check(not hud.home_open() and not state.ui_open,"统一关闭恢复输入")
 hud.show_life_menu()
 hud.life_menu.home_button.grab_focus()
 await _settle()
 await _settle()
 var menu_outer:Control=hud.life_menu.get_child(1)
 _check(viewport_rect.encloses(menu_outer.get_global_rect()) and viewport_rect.encloses(hud.life_menu.home_button.get_global_rect()),"大字体生活菜单和家庭入口位于窗口内 "+str(menu_outer.get_global_rect())+"/"+str(viewport_rect)+" 家庭="+str(hud.life_menu.home_button.get_global_rect()))
 var menu_focus:Control=hud.life_menu.buttons.close
 var reaches_home:=false
 for step in range(29):
  menu_focus=menu_focus.get_node(menu_focus.focus_next)
  if menu_focus==hud.life_menu.home_button:reaches_home=true;break
 _check(reaches_home,"Tab 焦点循环可达扩展区家庭入口")
 hud.life_menu.close()
 hud.show_home()
 state.day+=7;state.inventory.greens=2;state.changed.emit()
 _check(not panel.shared_buttons.meal.disabled and not panel.host_button.disabled,"新一周开放共同安排和指定邻居家宴")
 state.economy.locked.append("greens")
 var protected:int=state.inventory.greens
 panel._share("meal")
 _finish_household(state);panel._host()
 _check(int(state.inventory.greens)==protected,"界面操作也保护锁定料理")
 state.economy.locked.clear()
 state.pet_state.name="保存后的名字";state.pet_state.type="dog"
 var snapshot:Dictionary=state._make_save_data()
 hud.close_home()
 _check(state.load_game_data(snapshot) and str(state.pet_state.name)=="保存后的名字" and str(state.pet_state.type)=="dog","家庭宠物名字类型保存读回")
 hud.show_home()
 _check(panel.pet_name.text=="保存后的名字" and panel.pet_type.selected==1,"重新打开显示读档后的宠物")
 hud.close_home()
 for house in state.world_village.houses:
  if str(house.name)=="爷爷的老屋":state.current_interior=str(house.id);break
 state.interior_position=Vector2(480,555)
 change_scene_to_file("res://scenes/interior.tscn")
 await _settle()
 hud=current_scene.hud
 hud.show_life_menu();hud.life_menu.home_button.pressed.emit()
 panel=hud.home_panel
 _check(panel.visible and state.ui_open,"屋内生活菜单打开家庭页")
 modal_key.keycode=KEY_K;current_scene._unhandled_key_input(modal_key)
 modal_key.keycode=KEY_E;current_scene._unhandled_key_input(modal_key)
 _check(panel.visible and not hud.kitchen_open(),"屋内家庭页阻止世界快捷键与交互穿透")
 var close_pad:=InputEventJoypadButton.new()
 close_pad.button_index=JOY_BUTTON_B;close_pad.pressed=true
 state.poll_source_gamepad(1000.0,current_scene.player,{"connected":true,"buttons":[],"axes":[0.0,0.0]})
 state.poll_source_gamepad(1001.0,current_scene.player,{"connected":true,"buttons":[false,true],"axes":[0.0,0.0]})
 _check(not panel.visible and not state.ui_open,"屋内手柄返回恢复输入")
 print("Home panel smoke: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
