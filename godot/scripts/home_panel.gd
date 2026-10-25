extends Control
class_name HomePanel

const ACTIVITIES := {"meal":"共餐，聊聊今天","visit":"探望家人与朋友","objects":"整理老屋物件","plan":"讨论来年安排"}
var title_label: Label
var spouse_label: Label
var spouse_section: VBoxContainer
var single_label: Label
var shared_dish: OptionButton
var shared_buttons: Dictionary = {}
var memories_label: Label
var story_button: Button
var separate_button: Button
var guest_option: OptionButton
var host_dish: OptionButton
var host_button: Button
var host_hint: Label
var pet_label: Label
var pet_name: LineEdit
var pet_type: OptionButton
var pet_save: Button
var pet_play: Button
var scroll: ScrollContainer
var close_button: Button

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 var backdrop := ColorRect.new()
 backdrop.color = Color(0.04,0.07,0.05,0.84)
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(backdrop)
 var panel := PanelContainer.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.offset_left=-430;panel.offset_right=430;panel.offset_top=-275;panel.offset_bottom=275
 var style := StyleBoxFlat.new()
 style.bg_color=Color("293b31");style.border_color=Color("c5ab76")
 style.set_border_width_all(3);style.set_corner_radius_all(8);style.set_content_margin_all(16)
 panel.add_theme_stylebox_override("panel",style)
 add_child(panel)
 var column := VBoxContainer.new()
 set_meta("notification_column",column);set_meta("notification_index",1)
 column.add_theme_constant_override("separation",10)
 panel.add_child(column)
 var header := HBoxContainer.new()
 column.add_child(header)
 title_label=_label(header,"家里的饭桌",24)
 title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 close_button=_button(header,"合上 Esc",close)
 _label(column,"可以独居、邀请朋友，也可以与伴侣共同生活。没有每日共餐义务。")
 scroll=ScrollContainer.new()
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 column.add_child(scroll)
 var body := VBoxContainer.new()
 body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",12)
 scroll.add_child(body)
 single_label=_label(body,"现在的小院由你安排。八位成年候选人的关系不限主角性别，友情也能走到长久的信任。")
 spouse_section=VBoxContainer.new()
 spouse_section.add_theme_constant_override("separation",10)
 body.add_child(spouse_section)
 spouse_label=_label(spouse_section,"",20)
 story_button=_button(spouse_section,"婚后故事",_open_story)
 _label(spouse_section,"每周的共同安排",20)
 shared_dish=OptionButton.new()
 spouse_section.add_child(shared_dish)
 var activities := GridContainer.new()
 activities.columns=2
 activities.add_theme_constant_override("h_separation",8)
 activities.add_theme_constant_override("v_separation",8)
 spouse_section.add_child(activities)
 for id in ACTIVITIES:
  shared_buttons[id]=_button(activities,str(ACTIVITIES[id]),_share.bind(str(id)))
 memories_label=_label(spouse_section,"")
 separate_button=_button(spouse_section,"平静地商量各自生活",_ask_separate)
 _label(body,"请一位邻居来吃饭",20)
 host_hint=_label(body,"")
 guest_option=OptionButton.new()
 for npc in GameState.npc_catalog:
  guest_option.add_item(str(npc.name))
  guest_option.set_item_metadata(guest_option.item_count-1,str(npc.id))
 guest_option.item_selected.connect(func(_index: int): refresh())
 body.add_child(guest_option)
 host_dish=OptionButton.new()
 body.add_child(host_dish)
 host_button=_button(body,"摆好饭桌",_host)
 _label(body,"院里的小伙伴",20)
 pet_label=_label(body,"")
 pet_name=LineEdit.new()
 pet_name.max_length=12;pet_name.placeholder_text="小伙伴的名字"
 body.add_child(pet_name)
 pet_type=OptionButton.new()
 pet_type.add_item("猫");pet_type.set_item_metadata(0,"cat")
 pet_type.add_item("狗");pet_type.set_item_metadata(1,"dog")
 body.add_child(pet_type)
 pet_save=_button(body,"记下名字",_save_pet)
 pet_play=_button(body,"陪它玩一会儿",_play_pet)
 _label(column,"Tab 切换焦点 · 滚轮浏览 · Esc 合上")
 _bind_focus(body)
 GameState.changed.connect(refresh)
 hide()

func _label(parent: Node,text: String,font_size: int=16) -> Label:
 var label := Label.new()
 label.text=text
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("eee2c4"))
 parent.add_child(label)
 return label

func _button(parent: Node,text: String,action: Callable) -> Button:
 var button := Button.new()
 button.text=text;button.custom_minimum_size.y=38
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func _bind_focus(node: Node) -> void:
 if node is Control and node.focus_mode!=Control.FOCUS_NONE:
  node.focus_entered.connect(_scroll_focus.bind(node))
 for child in node.get_children(): _bind_focus(child)

func _scroll_focus(control: Control) -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 if visible and is_instance_valid(control): scroll.ensure_control_visible(control)

func open_panel() -> void:
 if GameState.action_busy():return
 preload("res://scripts/modal_status.gd").clear_message(self)
 GameState._interrupt_navigation_for_ui()
 show()
 GameState.ui_open=true
 pet_name.text=str(GameState.pet_state.get("name","小团"))
 pet_type.select(1 if str(GameState.pet_state.get("type","cat"))=="dog" else 0)
 refresh()
 close_button.grab_focus()

func close() -> void:
 hide()
 GameState.ui_open=false

func is_open() -> bool: return visible

func _dish_id(option: OptionButton) -> String:
 return str(option.get_item_metadata(option.selected)) if option.selected>=0 and not option.disabled else ""

func _fill_dishes(option: OptionButton) -> void:
 var selected := _dish_id(option)
 option.clear()
 for id in GameState.inventory:
  if int(GameState.inventory[id])<=0 or str(GameState.item_catalog.get(str(id),{}).get("kind",""))!="料理": continue
  option.add_item("%s ×%d"%[str(GameState.item_catalog[id].name),int(GameState.inventory[id])])
  option.set_item_metadata(option.item_count-1,str(id))
 var has_dish := option.item_count>0
 if not has_dish: option.add_item("没有备好的料理")
 option.disabled=not has_dish
 for index in range(option.item_count):
  if str(option.get_item_metadata(index))==selected: option.select(index);break

func refresh() -> void:
 if not visible: return
 var spouse := str(GameState.marriage.get("spouse",""))
 spouse_section.visible=spouse!=""
 single_label.visible=spouse==""
 if spouse!="":
  var role := ""
  var home_region := "farm"
  for npc in GameState.npc_catalog:
   if str(npc.id)==spouse: role=str(npc.get("role",""));home_region=str(npc.get("home","farm"));break
  var region := GameState.npc_scene_region(spouse)
  if region=="": region=home_region
  if region=="pasture": region="farm"
  var places := {"farm":"小院","town":"集镇","river":"河埠","bamboo":"竹林","mountain":"深山"}
  spouse_label.text="与你共同生活的 %s\n此刻在%s · 仍继续%s的工作。"%[GameState.npc_name(spouse),str(places.get(region,region)),role]
 _fill_dishes(shared_dish)
 _fill_dishes(host_dish)
 var weekly: Dictionary = GameState.marriage.get("weekly",{})
 for id in shared_buttons:
  var done := bool(weekly.get("%d-%s"%[int(GameState.day/7),id],false))
  shared_buttons[id].text=str(ACTIVITIES[id])+(" · 本周已安排" if done else "")
  shared_buttons[id].disabled=spouse=="" or done or id=="meal" and shared_dish.disabled
 memories_label.text="已留下 %d 次共同生活的记忆。"%GameState.marriage.get("memories",[]).size()
 var guest := str(guest_option.get_item_metadata(guest_option.selected)) if guest_option.selected>=0 else ""
 var invited := bool(GameState.season_events.get("meal-%d-%s"%[int(GameState.day/7),guest],false))
 var room := bool(GameState.upgrades.get("room",false))
 var at_home := GameState.host_meal_location_allowed()
 host_hint.text="需要整理厢房、在小院备好一道菜。每位邻居每周可邀请一次。"
 if not room: host_hint.text+="\n先整理厢房，摆好共餐桌。"
 elif not at_home: host_hint.text+="\n先回到小院，再安排家宴。"
 host_button.disabled=not room or not at_home or invited or host_dish.disabled or guest==""
 host_button.text="本周已经邀过这位邻居" if invited else "摆好饭桌"
 pet_label.text="%s · %s · 亲近 %d / 100"%[str(GameState.pet_state.get("name","小团")),"猫" if str(GameState.pet_state.get("type","cat"))=="cat" else "狗",int(GameState.pet_state.get("bond",0))]
 pet_play.disabled=int(GameState.pet_state.get("patted",-1))==GameState.day
 pet_play.text="今天已经陪它玩过了" if pet_play.disabled else "陪它玩一会儿"

func _share(activity: String) -> void:
 _begin_household_action("e-shared", activity, _dish_id(shared_dish) if activity=="meal" else "")

func _host() -> void:
 if guest_option.selected<0: return
 _begin_household_action("e-host", str(guest_option.get_item_metadata(guest_option.selected)), _dish_id(host_dish))

func _select_option_id(option: OptionButton, item_id: String) -> void:
 for index in range(option.item_count):
  if str(option.get_item_metadata(index))==item_id:
   option.select(index)
   return
 option.select(-1)

func _begin_household_action(action_id: String, item_id: String, dish_id: String) -> void:
 if GameState.action_busy(): return
 var starting_day := GameState.day
 var starting_room := GameState.current_interior
 var position := GameState.player_position if starting_room=="" else GameState.interior_position
 var shared_id := _dish_id(shared_dish)
 var host_id := _dish_id(host_dish)
 var guest_id := str(guest_option.get_item_metadata(guest_option.selected)) if guest_option.selected>=0 else ""
 var scroll_value := scroll.scroll_vertical
 var saved_pet_name := pet_name.text
 var saved_pet_type := str(pet_type.get_item_metadata(pet_type.selected))
 var button: Button
 match action_id:
  "e-host": button=host_button
  "e-pet": button=pet_play
  "e-pet-name": button=pet_save
  _: button=shared_buttons.get(item_id)
 if not is_instance_valid(button): return
 var restore := func():
  if not is_instance_valid(self) or GameState.day!=starting_day or GameState.current_interior!=starting_room: return
  visible=true
  GameState.ui_open=true
  _select_option_id(guest_option,guest_id)
  refresh()
  _select_option_id(shared_dish,shared_id)
  _select_option_id(host_dish,host_id)
  pet_name.text=saved_pet_name
  _select_option_id(pet_type,saved_pet_type)
  _restore_household_focus.call_deferred(button,scroll_value,starting_day,starting_room)
 var commit := func():
  if GameState.day!=starting_day or GameState.current_interior!=starting_room: return
  match action_id:
   "e-host": GameState.confirm_operation(GameState.host_meal(item_id,dish_id))
   "e-shared": GameState.confirm_operation(GameState.share_life(item_id,dish_id))
   "e-pet": GameState.confirm_operation(GameState.pat_companion())
   "e-pet-name":
    if GameState.rename_companion(saved_pet_name,saved_pet_type): GameState.save_game(GameState.SAVE_PATH,true)
  restore.call()
 var action := GameState.ACTION_RULES.ui(action_id,button.text)
 if action_id=="e-shared": action.item=item_id
 close()
 GameState.cancel_farm_queue()
 GameState.cancel_ranch_queue()
 GameState.kitchen_task.clear()
 GameState.building_task.clear()
 GameState.museum_task.clear()
 GameState.npc_task.clear()
 GameState.walking_target.clear()
 if not GameState.begin_action(action,{"kind":"ui","x":position.x,"y":position.y},commit,restore): restore.call()

func _restore_household_focus(button: Button, scroll_value: int, starting_day: int, starting_room: String) -> void:
 if not visible or GameState.day!=starting_day or GameState.current_interior!=starting_room: return
 if button.disabled or not button.is_visible_in_tree(): close_button.grab_focus()
 else: button.grab_focus()
 scroll.scroll_vertical=scroll_value

func _save_pet() -> void:
 _begin_household_action("e-pet-name","","")

func _play_pet() -> void:
 _begin_household_action("e-pet","","")

func _open_story() -> void:
 var spouse := str(GameState.marriage.get("spouse",""))
 if spouse=="": return
 get_parent().show_npc_story(spouse)

func _ask_separate() -> void:
 if GameState.action_busy() or str(GameState.marriage.get("spouse",""))=="":return
 get_parent().show_separation()

func _input(event: InputEvent) -> void:
 if not visible: return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
  close()
  get_viewport().set_input_as_handled()
