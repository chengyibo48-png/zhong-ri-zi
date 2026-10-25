extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run()->void:
 await process_frame
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 create_timer(60).timeout.connect(func():quit(1))
 var state:=root.get_node("GameState");state.set_process(false)
 check(ProjectSettings.get_setting("application/config/name")=="种日子 · Godot","packaged project loaded")
 check(not FileAccess.file_exists("res://tools/market_ui_smoke.gd"),"test source excluded")
 check(FileAccess.file_exists("res://data/initial_state.json"),"initial state packaged")
 check(FileAccess.file_exists("res://data/systems.json"),"system data packaged")
 check(state.item_catalog.size()==214 and state.crop_catalog.size()==28 and state.npc_catalog.size()==24,"full catalogs in package")
 check(state.system_catalog.ranch.species.size()==7,"seven ranch species in package")
 check(state.system_catalog.fishing.species.size()==16,"sixteen aquatic species in package")
 check(state.museum_entries.size()==266,"266 encyclopedia entries in package")
 check(load("res://scripts/quest_service.gd").guides().size()==40,"40 actual guide definitions packaged")
 check(FileAccess.file_exists("res://data/quests.json"),"quest configuration packaged")
 check(ResourceLoader.exists("res://scripts/ui_shell.gd") and ResourceLoader.exists("res://scripts/quest_save_rules.gd"),"new UI and pure save rules packaged")
 change_scene_to_file("res://scenes/main.tscn")
 await process_frame;await process_frame
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 check(world.get_node_or_null("WorldEffects")!=null,"world effects instantiated")
 check(world.hud!=null and world.player!=null,"world and native UI instantiated")
 var hud=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 for method in ["show_feedback","show_weather","show_kitchen","show_museum","show_help","show_settings","show_neighbor_book"]:
  check(hud.has_method(method),"page route "+method)
  if hud.has_method(method):
   hud.call(method)
   check(state.ui_open,"native page opens "+method)
   hud.close_top_panel()
   check(not state.ui_open,"native page closes "+method)
 state.stamina=37.875
 var wanted_day:int=state.day
 check(state.save_game("user://export-check.json",true),"export actual save write")
 state.stamina=0
 check(state.load_game("user://export-check.json") and state.stamina==37.875 and state.day==wanted_day,"export actual save restore")
 var actor_manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json"))
 var clips:=0;var portraits:=0
 for actor in actor_manifest.actors.values():
  for spec in actor.clips.values():
   check(bool(actor.get("ready",false)) or bool(spec.get("ready",false)),"Packaged action ready")
   check(load(str(spec.path)) is Texture2D,"Packaged action texture")
   clips+=1
  for path in actor.portraits.values():
   check(load(str(path)) is Texture2D,"Packaged portrait texture")
   portraits+=1
 check(clips==153 and portraits==175,"Complete character resource totals")
 var wardrobe:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/wardrobe_art_manifest.json"))
 var parts:=0
 for pack in wardrobe.packs.values():
  for direction in pack.parts.values():
   for part in direction.values():
    check(load(str(part.path)) is Texture2D,"Packaged clothing component")
    parts+=1
 check(parts==232,"All handpainted wardrobe components packaged")
 var scenery:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json"))
 for crop_id in state.crop_catalog:
  var entry:Dictionary=scenery.entries["crops/"+str(crop_id)]
  check(load(str(entry.path)) is Texture2D,"Healthy crop atlas packaged")
  for condition in ["wilt","pest","disease"]:
   check(load(str(entry.stateVariants[condition].path)) is Texture2D,"Crop condition atlas packaged")
 var fine_paths:Dictionary={}
 for key in scenery.entries:
  var art:Dictionary=scenery.entries[key]
  var paths:Array=art.get("states",{}).values()+art.get("seasons",[])
  paths.append(str(art.get("path","")))
  for path in paths:
   if str(path).contains("/fine/"):fine_paths[str(path)]=true
  if str(key).begins_with("buildings/"):
   check(art.get("seasons",[]).size()==4,"Four building seasons packaged "+str(key))
   check(load(str(art.get("states",{}).get("night",""))) is Texture2D,"Building night packaged "+str(key))
 for path in fine_paths:
  check(load(str(path)) is Texture2D,"Fine painting in independent package "+str(path))
 check(fine_paths.size()==674,"All 674 accepted fine paintings packaged")
 for path in ["res://scripts/save_repository.gd","res://scripts/native_save_rules.gd","res://scripts/interaction_ui_scheduler.gd","res://scripts/presentation_profile.gd","res://art/shaders/seasonal_night.gdshader"]:
  check(ResourceLoader.exists(path),"Current quality resource packaged "+path)
 state.appearance={"shirt":2,"skin":1,"hair":3,"hairColor":2,"hat":false,"bag":true,"outfit":"apron","weatherDress":false}
 world.player.character_visual.configure_player();world.player.character_visual.queue_redraw()
 for i in range(4):await process_frame
 if OS.get_environment("EXPORT_SCREENSHOT")!="":
  await RenderingServer.frame_post_draw
  check(world.player.character_visual.wardrobe.painted_active,"Packaged customized character actually rendered")
 var room=load("res://scenes/interior.tscn")
 check(room is PackedScene,"room scene packaged")
 if OS.get_environment("EXPORT_SCREENSHOT")!="":
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("EXPORT_SCREENSHOT"))
 print("Export package: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
