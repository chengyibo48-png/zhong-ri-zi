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
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("NEIGHBOR_BOOK_FIXTURE")))
 for room in ["","home-granny"]:
  state.cancel_action();state.current_interior=room
  change_scene_to_file("res://scenes/main.tscn" if room=="" else "res://scenes/interior.tscn")
  await settle()
  var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
  var hud=world.hud
  if hud.onboarding_open():hud.toggle_onboarding()
  var book=hud.npc_history_panel
  if room!="":check(book.tab=="history" and book.selected_person=="granny" and book.keyword=="留下" and book.selected_category=="故事","scene replacement retains source UI closure filters")
  state.day=10;state.minutes=600
  for row in fixture.rows:
   var id:=str(row.id)
   if row.resident!=null:state.npc_residents[id]=row.resident.duplicate(true)
   state.neighbors.people[id].event={} if row.status=="none" else {"status":row.status,"day":10}
   hud.show_neighbor_book(id,"people")
   var before:Dictionary=state._make_save_data().duplicate(true)
   var data:Array=book.people_rows()
   check(data.size()==1,"focused person "+id)
   for field in row.expected:check(data[0][field]==row.expected[field],"source "+id+"/"+str(row.status)+"/"+str(field))
   book.refresh()
   check(state._make_save_data()==before,"reading has no domain changes "+id)
   check(book.resident_cards.has(id),"rendered card "+id)
   var card:Dictionary=book.resident_cards[id]
   card.details.pressed.emit()
   card.details.button_pressed=true;card.details.toggled.emit(true)
   check(card.schedule.visible,"expanded schedule "+id)
   card.history.pressed.emit()
   check(book.tab=="history" and book.selected_person==id and book.keyword=="" and book.selected_category=="all","focused history resets filters "+id)
   hud.close_top_panel()
  state.neighbors.history=[
   {"id":"granny","category":"日常","text":"第一条","choice":"","day":0,"minute":601},
   {"id":"granny","category":"故事","text":"第二条\n线索","choice":"留下来","day":1,"minute":602},
   {"id":str(state.npc_catalog[1].id),"category":"故事","text":"第三条","choice":"","day":2,"minute":603}]
  hud.show_neighbor_book("granny","history")
  book.search.text=" 留下 ";book.categories.select(1);book.apply_filters()
  check(book.keyword=="留下" and book.selected_category=="故事" and book.filtered_rows().size()==1,"trim and choice keyword")
  book.search.text="未提交";book.set_tab("people")
  check(book.keyword=="留下" and book.search.text=="留下" and book.selected_category=="故事" and not book.categories.visible,"tab preserves applied filters discards drafts")
  book.set_tab("history");check(book.categories.selected==1 and book.filtered_rows().size()==1,"tab restores hidden category")
  hud.close_top_panel();hud.show_neighbor_book()
  check(book.tab=="history" and book.keyword=="留下" and book.selected_person=="granny" and book.selected_category=="故事","ordinary reopening keeps filters")
  book.set_tab("people");book.search.text="";book.apply_filters()
  check(book.selected_category=="all","people submit resets hidden category")
  book.clear_filters();check(book.people_rows().size()==state.npc_catalog.size(),"all residents")
  book.search.text="不存在的职业";book.apply_filters();check(book.people_rows().is_empty() and book.records.get_child_count()==0,"people empty has no extra invented text")
  book.set_tab("history");check(book.records.get_child_count()==1,"history empty message")
  book.clear_filters();check(book.filtered_rows().size()==3 and book.filtered_rows()[0].text=="第三条","newest first")
  check(book.summary.text=="最近 3 条已发生的交流 · 同日同一内容只收一条，最多保留 160 条。完整个人故事仍在故事页永久回看。","source summary")
  for size in [Vector2i(1280,800),Vector2i(640,360)]:
   root.size=size;await settle();hud.show_neighbor_book("granny","people");await settle()
   var bounds:Rect2=book.panel.get_global_rect()
   check(bounds.position.x>=0 and bounds.position.y>=0 and bounds.end.x<=book.get_viewport_rect().size.x and bounds.end.y<=book.get_viewport_rect().size.y,"viewport bounds")
   check(root.gui_get_focus_owner()==book.close_button and hud._gamepad_panel()==book,"book focus")
   hud.close_top_panel()
  hud.show_npc_dialogue("granny");hud.npc_dialogue.buttons.person.pressed.emit()
  check(book.visible and book.tab=="people" and book.selected_person=="granny" and not hud.neighbor_journal.visible,"source person route")
  hud.close_top_panel()
  hud.life_menu.open_panel();hud.life_menu.buttons.neighbors.pressed.emit()
  check(book.visible and not hud.life_menu.visible,"menu book entry")
  hud.close_top_panel()
  state.npc_residents.granny={"x":2831,"y":1652,"room":null}
  hud.show_neighbor_book("granny","people");book.resident_cards.granny.find.pressed.emit()
  check(not book.visible and not state.ui_open and not state.walking_target.is_empty(),"find starts route and closes UI "+room)
  if room!="":check(bool(state.walking_target.get("leave_before_find",false)) or state.current_interior=="","interior find leaves before route")
  state._interrupt_navigation_for_ui()
  hud.show_neighbor_book("granny","history");book.search.text="留下";book.categories.select(1);book.apply_filters();hud.close_top_panel()
 if OS.get_environment("NEIGHBOR_BOOK_SCREENSHOT")!="":
  root.size=Vector2i(960,600);await settle();current_scene.hud.show_neighbor_book("granny","people");await settle()
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("NEIGHBOR_BOOK_SCREENSHOT"))
 print("Neighbor book UI: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
