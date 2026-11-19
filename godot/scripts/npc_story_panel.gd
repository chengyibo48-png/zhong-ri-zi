extends Control
const VIEW=preload("res://scripts/npc_story_view.gd")
var npc_id:=""
var panel:PanelContainer
var column:VBoxContainer
var close_button:Button
var quote:Label
var reveal:=0.0
var last_view:Dictionary={}
var choice_buttons:Array[Button]=[]
var find_button:Button
var memory_buttons:Array[Button]=[]
var relationship_button:Button
var memory_expanded:Dictionary={}
func _ready()->void:
 set_meta("ui_managed_layout",true)
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop:=ColorRect.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.color=Color("08100bde");add_child(backdrop)
 panel=PanelContainer.new()
 var style:=StyleBoxFlat.new();style.bg_color=Color("304232f5");style.border_color=Color("beaa75");style.set_border_width_all(2);style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);add_child(panel)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
 panel.add_child(margin)
 var layout:=VBoxContainer.new();margin.add_child(layout)
 close_button=Button.new();close_button.text="关闭 Esc";close_button.pressed.connect(close);layout.add_child(close_button)
 close_button.set_meta("ui_role","quiet");close_button.size_flags_horizontal=Control.SIZE_SHRINK_END
 var scroll:=ScrollContainer.new();scroll.follow_focus=true;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
 column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",12);scroll.add_child(column)
 column.minimum_size_changed.connect(func():
  if visible and bool(get_meta("ui_shell",false)):get_parent().ui_stack.request_fit(self))
 _fit_panel();hide()
func _notification(what:int)->void:
 if what==NOTIFICATION_RESIZED and is_instance_valid(panel):_fit_panel()
func _fit_panel()->void:
 if bool(get_meta("ui_shell",false)):return
 var half:=Vector2(minf(360,maxf(1,(get_viewport_rect().size.x-24)/2)),minf(300,maxf(1,(get_viewport_rect().size.y-24)/2)))
 panel.offset_left=-half.x;panel.offset_right=half.x;panel.offset_top=-half.y;panel.offset_bottom=half.y
func _label(value:String,parent:Node)->Label:
 var label:=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(label);return label
func _button(value:String,callback:Callable)->Button:
 var button:=Button.new();button.text=value;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.pressed.connect(callback);column.add_child(button);return button
func open_panel(id:String)->void:
 if GameState.action_busy():return
 npc_id=id;show();GameState.ui_open=true;refresh();close_button.grab_focus.call_deferred()
func close()->void:hide();GameState.ui_open=false
func is_open()->bool:return visible
func refresh()->void:
 var focus:Control=get_viewport().gui_get_focus_owner()
 var focus_text:String=focus.text if focus is BaseButton else ""
 var old_text:String=quote.text if is_instance_valid(quote) else ""
 var old_visible:int=quote.visible_characters if is_instance_valid(quote) else 0
 var old_reveal:float=reveal
 var scrolls:Array[Node]=panel.find_children("*","ScrollContainer",true,false)
 var positions:Array=[]
 for node:Node in scrolls:positions.append(node.scroll_vertical)
 for child in column.get_children():column.remove_child(child);child.queue_free()
 choice_buttons.clear();memory_buttons.clear();find_button=null;quote=null;relationship_button=null
 last_view=VIEW.describe(GameState,npc_id)
 _label(last_view.title,column).set_meta("ui_role","title");_label(last_view.subtitle,column).set_meta("ui_role","caption")
 if last_view.text!="":
  quote=_label(last_view.text,column);quote.visible_characters=0;reveal=0
 for need in last_view.needs:
  var label:=_label(str(need.text),column)
  if need.missing:label.set_meta("ui_role","warning")
 if last_view.ready!="":_label(last_view.ready,column)
 if not last_view.needs.is_empty():_label("交接预览：扣除上列合格材料，按基础出售价值补偿；关系 +5。取消或条件变化不提交。",column)
 for index in last_view.choices.size():
  var choice:=_button(str(last_view.choices[index]),_choose.bind(index));choice_buttons.append(choice)
 if not last_view.get("activity",{}).is_empty() and not bool(last_view.activity.done) and GameState.npc_is_near(npc_id):_button(str(last_view.activity.label),_activity)
 if last_view.find:find_button=_button("去找"+GameState.npc_name(npc_id),_find);find_button.set_meta("ui_role","primary")
 if not last_view.memories.is_empty():
  column.add_child(HSeparator.new());_label("旧事回看",column).set_meta("ui_role","heading")
 for memory in last_view.memories:
  var content:=VBoxContainer.new();content.visible=bool(memory_expanded.get(npc_id+"/"+str(memory.title),false))
  var toggle:=_button(str(memory.title),func():content.visible=not content.visible;memory_expanded[npc_id+"/"+str(memory.title)]=content.visible)
  toggle.set_meta("ui_role","disclosure");memory_buttons.append(toggle);column.add_child(content)
  _label(str(memory.text),content);_label(str(memory.choice),content);_label(str(memory.reply),content)
 if last_view.relationship!="":relationship_button=_button(last_view.relationship,_relationship)
 if is_instance_valid(quote) and quote.text==old_text:
  quote.visible_characters=old_visible;reveal=old_reveal
 for i:int in mini(scrolls.size(),positions.size()):scrolls[i].set_deferred("scroll_vertical",positions[i])
 if focus_text!="":
  for button:Node in panel.find_children("*","BaseButton",true,false):
   if button.text==focus_text and not button.disabled:button.grab_focus.call_deferred();break

func _process(delta:float)->void:
 if visible and is_instance_valid(quote) and quote.visible_characters>=0:
  reveal+=delta*35;quote.visible_characters=int(reveal)
  if quote.visible_characters>=quote.get_total_character_count():quote.visible_characters=-1
func _unhandled_input(event:InputEvent)->void:
 if visible and is_instance_valid(quote) and quote.visible_characters>=0 and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
  quote.visible_characters=-1;get_viewport().set_input_as_handled()
func _choose(index:int)->void:GameState.queue_npc_task(npc_id,"story",{"choice":index})
func _find()->void:GameState.find_npc(npc_id)
func _relationship()->void:
 if GameState.partners.get(npc_id,"")=="dating":
  close();get_parent().show_wedding(npc_id)
 else:get_parent().begin_relationship_action("e-date",npc_id,self,relationship_button)

func show_status_message(text:String,error:bool=false)->void:
 preload("res://scripts/modal_status.gd").show_message(column,text,error)

func _activity()->void:
 if GameState.start_npc_story_activity(npc_id):get_parent().ui_stack.leave()
