extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle() -> void:
 for f in range(6):await process_frame
func capture(name:String) -> void:
 await settle();await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 check(im!=null and not im.is_empty(),"actual GPU image")
 if im!=null:check(im.save_png("res://artifacts/"+name+".png")==OK,"saved "+name)
func run() -> void:
 create_timer(90).timeout.connect(func():quit(1))
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_art.theme="paper"
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var hud=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 var art=load("res://scripts/item_art.gd")
 for entry in state.content.get("archives",[]):
  if not state.archives.has(str(entry.id)):state.archives.append(str(entry.id))
 for resolution in [Vector2i(1280,800),Vector2i(1920,1080)]:
  root.size=resolution;await settle()
  var panel=hud.community_panel
  panel.open_panel("archives");root.get_node("UIArtService").apply_all();await settle()
  check(root.get_visible_rect().encloses(panel.get_child(1).get_global_rect()),"archive panel stays inside viewport")
  var shown:=0
  for node in panel.find_children("*","TextureRect",true,false):
   var key:String=str(node.get_meta("item_art_key",""))
   if key=="":continue
   shown+=1
   check(node.texture==art.texture_for(key),"live card draws exact qualified illustration "+key)
   check(node.get_global_rect().size.x>0 and node.get_global_rect().size.y>0,"card icon has nonzero layout")
  check(shown>=9,"six archived objects and three reward icons appear")
  await capture("handpainted-archive-cards-"+str(resolution.x))
  panel.content_scroll.scroll_vertical=int(panel.content_scroll.get_v_scroll_bar().max_value)
  await capture("handpainted-achievement-cards-"+str(resolution.x))
  for node in panel.find_children("*","TextureRect",true,false):
   if str(node.get_meta("item_art_key",""))=="":continue
   var box:Rect2=node.get_global_rect()
   var area:Rect2=panel.content_scroll.get_global_rect()
   if area.intersects(box):check(box.position.x>=area.position.x and box.end.x<=area.end.x,"scrolled card icon remains inside horizontal content bounds")
  panel.close()
  state.collection.entries["archive:photo"]={"seen":true,"acquired":true}
  var museum=hud.museum_panel
  museum.search_text="河埠旧合照";museum.open_panel("catalog","archive:photo")
  root.get_node("UIArtService").apply_all();await settle()
  var photo_index:int=museum.item_keys.find("archive:photo")
  check(photo_index>=0,"archive photo remains reachable through original focused catalog")
  if photo_index>=0:
   check(museum.item_list.get_item_icon(photo_index)==art.texture_for("archives/photo"),"actual museum uses historical photograph not furniture photograph")
   check(museum.item_list.get_selected_items().has(photo_index),"focused entry remains selected for automatic scrolling")
   check(museum.item_list.get_v_scroll_bar().value>0,"deep focused entry automatically scrolls into view")
  await capture("handpainted-museum-archive-photo-"+str(resolution.x))
  museum.close()
 print("NAMESPACE_CARD_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
