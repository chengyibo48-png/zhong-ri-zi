extends Control
const PORTRAIT=preload("res://scripts/character_portrait.gd")
var npc_id:=""
var panel:PanelContainer
var column:VBoxContainer
var scroll:ScrollContainer
var close_button:Button
var quote:Label
var reveal:=0.0
var reveal_pause:=0.0
var buttons:Dictionary={}
func _ready()->void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop:=ColorRect.new()
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.color=Color("08100bde")
 add_child(backdrop)
 panel=PanelContainer.new()
 var style:=StyleBoxFlat.new();style.bg_color=Color("304232f5");style.border_color=Color("beaa75");style.set_border_width_all(2);style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 add_child(panel)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
 panel.add_child(margin)
 var layout:=VBoxContainer.new();margin.add_child(layout)
 close_button=Button.new();close_button.text="关闭 Esc";close_button.pressed.connect(close);layout.add_child(close_button)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(scroll)
 column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",12);scroll.add_child(column)
 _fit_panel();hide()
func _notification(what:int)->void:
 if what==NOTIFICATION_RESIZED and is_instance_valid(panel):_fit_panel()
func _fit_panel()->void:
 var half:=Vector2(minf(360,maxf(1,(get_viewport_rect().size.x-24)/2)),minf(300,maxf(1,(get_viewport_rect().size.y-24)/2)))
 panel.offset_left=-half.x;panel.offset_right=half.x;panel.offset_top=-half.y;panel.offset_bottom=half.y
func _text(value:String,parent:Node=column)->Label:
 var label:=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(label);return label
func _button(key:String,text:String,callback:Callable)->void:
 var button:=Button.new();button.text=text;button.pressed.connect(callback);column.add_child(button);buttons[key]=button
func open_panel(id:String)->void:
 if GameState.action_busy():return
 npc_id=id;show();GameState.ui_open=true;refresh();close_button.grab_focus()
func close()->void:hide();GameState.ui_open=false
func is_open()->bool:return visible
func refresh()->void:
 buttons.clear()
 for child in column.get_children():column.remove_child(child);child.queue_free()
 var person:Dictionary={}
 for row in GameState.npc_catalog:
  if str(row.id)==npc_id:person=row;break
 if person.is_empty():_text("这位邻居还没来");return
 var profile:Dictionary=GameState.system_catalog.get("npc",{}).get("profiles",{}).get(npc_id,{})
 var resident:Dictionary=GameState.neighbors.get("people",{}).get(npc_id,{})
 var last:Dictionary=resident.get("last",{})
 var emotion:=str(last.get("emotion","calm"))
 _text(str(person.name)+" · 坐下慢慢聊")
 _text(str(person.get("role",""))+" · "+GameState._relationship_stage(int(GameState.relations.get(npc_id,{}).get("points",0)))+" · "+str(profile.get("trait","")))
 var row:=HBoxContainer.new();column.add_child(row)
 var portrait:=PORTRAIT.new();portrait.custom_minimum_size=Vector2(128,160);portrait.configure(npc_id,person,emotion);row.add_child(portrait)
 var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words)
 _text(str({"calm":"平静","happy":"笑着说","focus":"认真说","thought":"想了想","surprised":"惊讶地说","tired":"疲倦地说","worried":"担心地说"}.get(emotion,"平静"))+" · "+str(last.get("category","相遇")),words)
 quote=_text(str(last.get("text",person.get("greeting",""))),words)
 quote.visible_characters=-1 if str(GameState.player_settings.get("textSpeed","instant"))=="instant" else 0
 reveal=0;reveal_pause=0
 var where:Dictionary=GameState.npc_location(npc_id)
 _text(str(where.get("place",""))+" · "+str(where.get("activity","")),words)
 _text("任务交付 · 与普通赠礼分开")
 for task: Dictionary in GameState.quest_snapshot():
  if str(task.get("npc",""))!=npc_id or str(task.kind) not in ["wish","favor"] or str(task.status) in ["completed","expired","abandoned"]:continue
  var text: String=str(task.title)+" · "+("材料齐了" if str(task.status)=="ready" else "查看所需物品")
  _button("quest:"+str(task.id),text,_quest.bind(str(task.id)))
 for topic in [["auto","聊聊此刻"],["daily","说点家常"],["advice","请教生活窍门"],["memory","说起一起经历的事"]]:
  _button(str(topic[0]),str(topic[1]),_talk.bind(str(topic[0])))
 var event:Dictionary=resident.get("event",{})
 if not event.is_empty():
  var status:=str(event.get("status","offered"))
  _text(str(profile.get("request",""))+"\n"+str({"offered":"想找人搭把手","accepted":"已约好 · 随时可做","postponed":"改天再说 · 可以重新答应","done":"已一起完成"}.get(status,"")))
  if status=="done":
   _text("记得你"+("留下来一起动手" if event.get("method","")=="join" else "送来了材料")+"的那一天。")
  else:
   var item:Dictionary=GameState.item_catalog.get(str(profile.get("item","")),{})
   _text(str(profile.get("materialUse",""))+"\n送来 "+str(item.get("name",""))+" ×2，或一起动手：20 分钟、3 体力。完成关系 +6；没有期限，改天再说不会扣关系。")
   if status=="accepted":
    _button("join","一起动手",_event.bind("join",int(event.get("day",-1))))
    _button("supply","送来两份材料",_event.bind("supply",int(event.get("day",-1))))
    _button("later","约好改天再说",_event.bind("later",int(event.get("day",-1))))
   else:
    _button("accept","我愿意搭把手",_event.bind("accept",int(event.get("day",-1))))
    _button("later","先说好，改天再来",_event.bind("later",int(event.get("day",-1))))
 _text("对方惦记着\n"+str(profile.get("goal",""))+"\n"+str(GameState.npc_story_readiness(npc_id).get("message","")))
 _button("story","聊聊个人故事",_journal.bind(true))
 _button("gift","送一道菜",_gift)
 _button("home","邀请来吃饭",_home)
 _button("person","查看行踪与约定",_journal.bind(false))
 _button("history","回看我们的对话",_history)
 if str(person.get("tier",""))=="romance" and int(GameState.npc_stories.get(npc_id,{}).get("step",0))>=4:
  var spouse:=str(GameState.marriage.get("spouse",""))==npc_id
  var dating:=str(GameState.partners.get(npc_id,""))=="dating"
  _button("relationship","我们的共同生活" if spouse else "商量婚礼" if dating else "认真表达心意",_relationship.bind(spouse,dating))
func _process(delta:float)->void:
 if visible and is_instance_valid(quote) and quote.visible_characters>=0:
  if quote.visible_characters==0 and reveal==0.0:reveal_pause=0.0
  if reveal_pause>0.0:
   reveal_pause=maxf(0.0,reveal_pause-delta);return
  var rate:=18.0 if str(GameState.player_settings.get("textSpeed","normal"))=="slow" else 35.0
  reveal+=minf(delta,0.2)*rate
  while quote.visible_characters<int(reveal) and quote.visible_characters<quote.get_total_character_count():
   quote.visible_characters+=1
   var index:=quote.visible_characters-1
   var letter:=quote.text.substr(index,1)
   if letter in ["，","、","；",",",";"]:
    reveal_pause=0.06;reveal=float(quote.visible_characters);break
   if letter in ["。","！","？","…","\n","!","?"]:
    reveal_pause=0.14;reveal=float(quote.visible_characters);break
  if quote.visible_characters>=quote.get_total_character_count():quote.visible_characters=-1
func _unhandled_input(event:InputEvent)->void:
 if visible and is_instance_valid(quote) and quote.visible_characters>=0 and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
  quote.visible_characters=-1;get_viewport().set_input_as_handled()
func _talk(topic:String)->void:GameState.queue_npc_task(npc_id,"talk",{"topic":topic})
func _event(op:String,day:int)->void:GameState.queue_npc_task(npc_id,op,{"day":day})
func _gift()->void:get_parent().show_gifts(npc_id)
func _history()->void:get_parent().npc_history_panel.open_panel(npc_id)
func _home()->void:get_parent().show_home()
func _journal(story:bool)->void:
 if story:get_parent().show_npc_story(npc_id);return
 get_parent().show_neighbor_book(npc_id,"people")
func _relationship(spouse:bool,dating:bool)->void:
 if spouse:_home();return
 if dating:get_parent().show_wedding(npc_id)
 else:get_parent().begin_relationship_action("e-date",npc_id,self,buttons.relationship)

func show_status_message(text:String,error:bool=false)->void:
 preload("res://scripts/modal_status.gd").show_message(column,text,error)


func _quest(id: String) -> void:
 if not GameState.quests.entries.has(id):GameState.quest_accept(id)
 get_parent().life_plan_panel.open_panel(id,"active")
