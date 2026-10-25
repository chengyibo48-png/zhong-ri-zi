extends Control
const PORTRAIT=preload("res://scripts/character_portrait.gd")
var tab:="people"
var column:VBoxContainer
var tabs:Dictionary={}
var resident_cards:Dictionary={}
var content_scroll:ScrollContainer
var panel:PanelContainer
var people:OptionButton
var categories:OptionButton
var search:LineEdit
var records:VBoxContainer
var summary:Label
var close_button:Button
var selected_person:="all"
var selected_category:="all"
var keyword:=""
func _ready()->void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop:=ColorRect.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.color=Color("08100bde");add_child(backdrop)
 panel=PanelContainer.new()
 var style:=StyleBoxFlat.new();style.bg_color=Color("304232f5");style.border_color=Color("beaa75");style.set_border_width_all(2);style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);add_child(panel)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
 panel.add_child(margin)
 column=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
 var title:=Label.new();title.text="禾溪邻里簿";column.add_child(title)
 var subtitle:=Label.new();subtitle.text="每个人都有正在忙的事。看看行踪、记下约定，也翻翻真正聊过的话。";subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(subtitle)
 var tab_row:=HBoxContainer.new();column.add_child(tab_row)
 for key in ["people","history"]:
  var button:=Button.new();button.pressed.connect(set_tab.bind(key));tab_row.add_child(button);tabs[key]=button
 close_button=Button.new();close_button.text="关闭 Esc";close_button.pressed.connect(close);column.add_child(close_button)
 people=OptionButton.new();people.add_item("全部邻居");people.set_item_metadata(0,"all")
 for person in GameState.npc_catalog:
  people.add_item(str(person.name));people.set_item_metadata(people.item_count-1,str(person.id))
 column.add_child(people)
 search=LineEdit.new();search.max_length=40;search.placeholder_text="姓名、职业、对话或线索";column.add_child(search)
 categories=OptionButton.new()
 for kind in ["all","故事","邻里小事","线索","回忆","节庆","日常"]:
  categories.add_item("全部内容" if kind=="all" else kind);categories.set_item_metadata(categories.item_count-1,kind)
 column.add_child(categories)
 var filters:=HBoxContainer.new();column.add_child(filters)
 var find:=Button.new();find.text="查找";find.pressed.connect(apply_filters);filters.add_child(find)
 var clear:=Button.new();clear.text="清除筛选";clear.pressed.connect(clear_filters);filters.add_child(clear)
 search.text_submitted.connect(func(_value:String):apply_filters())
 summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(summary)
 content_scroll=ScrollContainer.new();content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content_scroll.follow_focus=true;column.add_child(content_scroll)
 records=VBoxContainer.new();records.size_flags_horizontal=Control.SIZE_EXPAND_FILL;records.add_theme_constant_override("separation",18);content_scroll.add_child(records)
 tab=str(GameState.neighbor_book_ui.tab);selected_person=str(GameState.neighbor_book_ui.person)
 selected_category=str(GameState.neighbor_book_ui.kind);keyword=str(GameState.neighbor_book_ui.search)
 _fit_panel();hide()
func _notification(what:int)->void:
 if what==NOTIFICATION_RESIZED and is_instance_valid(panel):_fit_panel()
func _fit_panel()->void:
 var half:=Vector2(minf(360,maxf(1,(get_viewport_rect().size.x-24)/2)),minf(300,maxf(1,(get_viewport_rect().size.y-24)/2)))
 panel.offset_left=-half.x;panel.offset_right=half.x;panel.offset_top=-half.y;panel.offset_bottom=half.y
func open_panel(id:String="")->void:
 if GameState.action_busy():return
 if id!="":focus_person(id,"history")
 else:refresh()
 GameState._interrupt_navigation_for_ui()
 show();GameState.ui_open=true;close_button.grab_focus()
func focus_person(id:String,next_tab:String="people")->void:
 tab=next_tab;selected_person=id;selected_category="all";keyword="";refresh()
func set_tab(value:String)->void:
 tab=value;refresh()
func close()->void:hide();GameState.ui_open=false
func is_open()->bool:return visible
func apply_filters()->void:
 selected_person=str(people.get_item_metadata(people.selected));selected_category=str(categories.get_item_metadata(categories.selected)) if tab=="history" else "all";keyword=search.text.strip_edges().left(40);search.text=keyword;refresh()
func clear_filters()->void:
 selected_person="all";selected_category="all";keyword="";refresh()
func filtered_rows()->Array:
 var result:Array=[]
 for row in GameState.neighbors.get("history",[]):
  if selected_person!="all" and str(row.get("id",""))!=selected_person:continue
  if selected_category!="all" and str(row.get("category",""))!=selected_category:continue
  if keyword!="" and not (str(row.get("text",""))+str(row.get("choice",""))+GameState.npc_name(str(row.get("id","")))).contains(keyword):continue
  result.append(row)
 result.reverse();return result
func people_rows()->Array:
 var rows:Array=[]
 for person in GameState.npc_catalog:
  var id:=str(person.id)
  var profile:Dictionary=GameState.system_catalog.get("npc",{}).get("profiles",{}).get(id,{})
  if selected_person!="all" and selected_person!=id:continue
  if keyword!="" and not (" ".join([str(person.name),str(person.role),str(profile.get("trait","")),str(profile.get("goal",""))])).contains(keyword):continue
  var location:Dictionary=GameState.npc_location(id)
  var event:Dictionary=GameState.neighbors.get("people",{}).get(id,{}).get("event",{})
  rows.append({
   "id":id,"name":str(person.name),
   "role":str(person.role)+" · "+GameState._relationship_stage(int(GameState.relations.get(id,{}).get("points",0))),
   "profile":str(profile.get("trait",""))+" · "+str(profile.get("goal","")),
   "location":str(location.get("place",""))+" · "+str(location.get("activity","")),
   "reason":str(location.get("reason","")),
   "schedule":"早间整理手边东西；白天"+str(profile.get("work",""))+"；午饭回屋；傍晚走访或散步；夜间回家。风雨天转为室内，节庆和赶集会调整去处。",
   "promise":"" if event.is_empty() else str(profile.get("request",""))+" · "+str({"offered":"想找人搭把手","accepted":"已约好 · 随时可做","postponed":"改天再说 · 可以重新答应","done":"已一起完成"}.get(str(event.get("status","")),""))
  })
 return rows
func refresh()->void:
 GameState.neighbor_book_ui={"tab":tab,"person":selected_person,"kind":selected_category,"search":keyword}
 categories.visible=tab=="history";summary.visible=tab=="history"
 tabs.people.text=("✓ " if tab=="people" else "")+"行踪与近况"
 tabs.history.text=("✓ " if tab=="history" else "")+"对话记录"
 search.text=keyword
 for i in people.item_count:
  if str(people.get_item_metadata(i))==selected_person:people.select(i);break
 for i in categories.item_count:
  if str(categories.get_item_metadata(i))==selected_category:categories.select(i);break
 resident_cards.clear()
 for child in records.get_children():records.remove_child(child);child.queue_free()
 content_scroll.scroll_vertical=0
 if tab=="people":
  for row in people_rows():_resident(row)
  return
 var history:Array=GameState.neighbors.get("history",[])
 summary.text="最近 "+str(history.size())+" 条已发生的交流 · 同日同一内容只收一条，最多保留 160 条。完整个人故事仍在故事页永久回看。"
 var rows:=filtered_rows()
 if rows.is_empty():_label("还没有符合条件的对话。先沿路拜访一位邻居吧。");return
 for row in rows:
  var minute:=int(row.get("minute",0))
  _label(GameState.npc_name(str(row.get("id","")))+" · "+str(row.get("category",""))+" · 第 "+str(int(row.get("day",0))+1)+" 天 "+str(minute/60)+":"+("%02d"%(minute%60)))
  _label(str(row.get("text","")))
  if str(row.get("choice",""))!="":_label("你的选择："+str(row.choice))
func _label(text:String,parent:Node=records)->Label:
 var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label
func _resident(data:Dictionary)->void:
 var card:=VBoxContainer.new();card.add_theme_constant_override("separation",8);records.add_child(card)
 var head:=HBoxContainer.new();card.add_child(head)
 var portrait:=PORTRAIT.new();portrait.custom_minimum_size=Vector2(64,80);portrait.configure(str(data.id));head.add_child(portrait)
 var identity:=VBoxContainer.new();identity.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(identity)
 _label(str(data.name),identity);_label(str(data.role),identity)
 for field in ["profile","location","reason"]:_label(str(data[field]),card)
 var details:=Button.new();details.text="今天的作息线索";details.toggle_mode=true;card.add_child(details)
 var schedule:=_label(str(data.schedule),card);schedule.hide();details.toggled.connect(func(open:bool):schedule.visible=open)
 if str(data.promise)!="":_label(str(data.promise),card)
 var find:=Button.new();find.text="沿路去找对方";find.pressed.connect(_find.bind(str(data.id)));card.add_child(find)
 var history:=Button.new();history.text="回看对话";history.pressed.connect(focus_person.bind(str(data.id),"history"));card.add_child(history)
 resident_cards[data.id]={"find":find,"history":history,"details":details,"schedule":schedule}
func _find(id:String)->void:
 close();GameState.find_npc(id)
func show_status_message(text:String,error:bool=false)->void:
 preload("res://scripts/modal_status.gd").show_message(column,text,error)
