extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle() -> void:
 for f in range(5):await process_frame
func run() -> void:
 create_timer(60).timeout.connect(func():quit(1))
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 var art=load("res://scripts/item_art.gd")
 var expected:=0
 for pair in [["stations",state.system_catalog.kitchen.stations],["facilities",state.system_catalog.farming.facilities]]:
  for id in pair[1]:
   expected+=1
   var key:String=pair[0]+"/"+str(id)
   check(art.manifest().has(key),"original device registered "+key)
   check(art.manifest().get(key,{}).get("status","")=="ready" and art.texture_for(key)!=null,"every original device has an independent bitmap "+key)
 check(expected==17,"all ten processing stations and seven functional facilities")
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var panel=world.hud.farm_facility_panel
 panel.open_panel(false,0);await settle()
 for i in range(panel.type_list.item_count):
  var id:String=str(panel.type_list.get_item_metadata(i))
  check(panel.type_list.get_item_icon(i)==art.texture_for(id,"facilities"),"actual facility list exact icon "+id)
 check(panel.type_list.item_count==7,"all existing facility types reachable")
 panel.close()
 var kitchen=world.hud.kitchen_panel
 kitchen.open_panel(false,"tools");await settle()
 for i in range(kitchen.entry_ids.size()):
  var id:String=str(kitchen.entry_ids[i])
  check(kitchen.list.get_item_icon(i)==art.texture_for(id,"stations"),"actual kitchen appliance list exact icon "+id)
 check(kitchen.entry_ids.size()==10,"all existing processing stations reachable")
 kitchen.close()
 print("FACILITY_ART_SMOKE: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
