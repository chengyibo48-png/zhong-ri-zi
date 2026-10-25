extends SceneTree
var passed:=0
var failed:=0
var art:Script
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle() -> void:
 for f in range(5):await process_frame
func capture(name:String) -> void:
 await settle();await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 check(im!=null and not im.is_empty(),"real GPU viewport")
 if im!=null:check(im.save_png("res://artifacts/"+name+".png")==OK,"saved "+name)
func check_icons(panel:Control) -> int:
 var found:=0
 for node in panel.find_children("*","Control",true,false):
  if node.get_script()==null or node.get_script().resource_path!="res://scripts/item_icon.gd" or not node.is_visible_in_tree():continue
  var id:String=str(node.get("item_id"))
  if id=="":continue
  found+=1
  check(art.texture_for(id)!=null and str(node.get("painted_key"))==art.key_for(id),"visible control actually drew correct bitmap "+id)
 return found
func run() -> void:
 create_timer(180).timeout.connect(func():quit(1))
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_art.theme="paper"
 art=load("res://scripts/item_art.gd")
 for key in art.manifest():check(art.manifest()[key].get("status","")=="ready" and art.texture_for(key)!=null,"all registered UI assets physically ready "+key)
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var hud=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 state.inventory["springBowl"]=2;state.inventory["winterMilk"]=2;state.storage["wintermelon"]=2
 for recipe in state.content.get("recipes",[]):
  if not state.known_recipes.has(str(recipe.id)):state.known_recipes.append(str(recipe.id))
 for resolution in [Vector2i(1280,800),Vector2i(1920,1080)]:
  root.size=resolution;await settle()
  for mode in ["inventory","buy","sell","buyback","business","ledger"]:
   var market=hud.market_panel
   market.open_panel(mode,true,"shop");root.get_node("UIArtService").apply_all();await settle()
   for i in range(market.item_ids.size()):
    var id:String=market._illustration_id(str(market.item_ids[i]))
    check(market.item_list.get_item_icon(i)==art.texture_for(id,"items"),"actual market "+mode+" exact item icon "+id)
   check_icons(market)
   check(root.get_visible_rect().encloses(market.get_child(1).get_global_rect()),"market "+mode+" stays inside viewport")
   await capture("handpainted-market-"+mode+"-"+str(resolution.x))
   if mode=="inventory":
    market._choose_inventory_side("storage");await settle()
    for i in range(market.item_ids.size()):
     var id:String=market._illustration_id(str(market.item_ids[i]))
     check(market.item_list.get_item_icon(i)==art.texture_for(id,"items"),"actual storage exact icon "+id)
    check_icons(market)
    await capture("handpainted-storage-"+str(resolution.x))
    market._choose_inventory_side("bag")
   market.close()
  var gift=hud.gift_panel;gift.open_panel("lin");root.get_node("UIArtService").apply_all();await settle()
  check(check_icons(gift)>=2,"new soups and milk visible as gifts")
  check(root.get_visible_rect().encloses(gift.panel.get_global_rect()),"gift panel stays inside viewport")
  await capture("handpainted-gifts-"+str(resolution.x));gift.close()
  for mode in ["cook","process","tools","pantry"]:
   var kitchen=hud.kitchen_panel;kitchen.open_panel(false,mode);root.get_node("UIArtService").apply_all();await settle()
   for i in range(kitchen.entry_ids.size()):
    var id:String=str(kitchen.entry_ids[i])
    var category:="stations" if mode=="tools" else "items"
    if mode=="pantry":id=id.get_slice(":",1)
    elif mode=="process":
     for recipe in state.system_catalog.kitchen.processing:
      if str(recipe.id)==id:id=str(recipe.out);break
    check(kitchen.list.get_item_icon(i)==art.texture_for(id,category),"actual kitchen "+mode+" exact icon "+id)
    check(art.texture_for(id,category)!=null,"every listed recipe or appliance has actual art "+id)
   check(root.get_visible_rect().encloses(kitchen.get_child(1).get_global_rect()),"kitchen "+mode+" stays inside viewport")
   await capture("handpainted-kitchen-"+mode+"-"+str(resolution.x));kitchen.close()
  var facilities=hud.farm_facility_panel;facilities.open_panel(false,0);root.get_node("UIArtService").apply_all();await settle()
  for i in range(facilities.type_list.item_count):
   var id:String=str(facilities.type_list.get_item_metadata(i))
   check(facilities.type_list.get_item_icon(i)==art.texture_for(id,"facilities") and art.texture_for(id,"facilities")!=null,"actual functional facility exact image "+id)
  check(root.get_visible_rect().encloses(facilities.get_child(1).get_global_rect()),"facilities stays inside viewport")
  await capture("handpainted-functional-facilities-"+str(resolution.x));facilities.close()
  var catalog=hud.item_catalog_panel;catalog.open_panel();root.get_node("UIArtService").apply_all();await settle()
  check(catalog.item_ids.size()==190,"original item encyclopedia retains all 190 entries")
  var shown:=0
  for page in range(ceili(catalog.item_ids.size()/24.0)):
   catalog.page=page;catalog.refresh();root.get_node("UIArtService").apply_all();await settle()
   for id in catalog.card_buttons:
    var card:Control=catalog.card_buttons[id]
    shown+=1
    check(check_icons(card)==1,"each encyclopedia card draws one unique item illustration "+str(id))
   await capture("handpainted-item-catalog-page-%d-%d"%[page,resolution.x])
  check(shown==190,"every item appears in actual paged encyclopedia")
  catalog.close()
 print("ICON_CONSUMERS_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
