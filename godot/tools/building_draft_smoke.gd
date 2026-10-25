extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle()->void:
 await process_frame
 await process_frame
func run()->void:
 await settle()
 var temp:String=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state:Node=root.get_node("GameState");state.set_process(false)
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world:Node=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var hud:Node=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 state.building.house=3;state.building.layout=[];state.building.revision=0;state.building.nextId=1;state.furniture.bench=3
 hud.show_building({},true)
 var panel:Node=hud.building_panel;panel._set_tab("layout")
 for zone_id in ["home","court","orchard"]:
  panel.zone_id=zone_id
  for house_level in range(4):
   state.building.house=house_level;panel._refresh_layout();await settle()
   var zone:Dictionary=state.system_catalog.building.zones[zone_id]
   for cell in range(int(zone.cols)*int(zone.rows)):
    var reason:String=state.BUILDING_GEOMETRY.reserved(state,zone_id,cell)
    var button:Button=panel.grid.get_child(cell)
    check(button.tooltip_text==reason if reason!="" else button.tooltip_text=="空地","actual source reserved cell "+zone_id+"/"+str(house_level)+"/"+str(cell))
 state.building.house=3;panel.zone_id="court";panel._refresh_layout();await settle()
 var piece:Dictionary={"key":1,"type":"bench","zone":"home","cell":3,"rotation":0}
 check(state.check_building_layout([piece]).ok,"source-valid home layout")
 check(panel.draft_epoch==state.building_epoch,"draft records loaded building owner")
 panel.draft=[piece]
 panel._apply_layout();await settle()
 check(state.building.layout==[piece] and state.building.revision==1 and state.building.nextId==2 and state.furniture.bench==2,"actual UI commits all layout fields")
 var saved:Variant=state._read_save_json(state.SAVE_PATH)
 check(saved is Dictionary and JSON.parse_string(JSON.stringify(saved.building.layout))==JSON.parse_string(JSON.stringify([piece])) and saved.furniture.bench==2,"actual UI immediately saves committed furniture")
 var old_epoch:int=state.building_epoch
 var data:Dictionary=state._make_save_data()
 var revision:int=state.building.revision
 var bank:Dictionary=state.furniture.duplicate(true)
 check(state.load_game_data(data),"reload same revision")
 check(state.building_epoch>old_epoch and state.building.revision==revision,"reload changes owner even for equal revision")
 panel._apply_layout();await settle()
 check(state.message=="场地刚有变化，请重新打开布置图。","actual UI rejects previous owner's draft")
 check(state.furniture==bank,"stale draft does not alter materials "+JSON.stringify(state.furniture)+" expected "+JSON.stringify(bank))
 check(state.building.revision==revision,"stale draft does not alter layout revision")
 var rejected_save:Variant=state._read_save_json(state.SAVE_PATH)
 check(rejected_save is Dictionary and int(rejected_save.building.revision)==revision and JSON.parse_string(JSON.stringify(rejected_save.building.layout))==JSON.parse_string(JSON.stringify([piece])) and JSON.parse_string(JSON.stringify(rejected_save.furniture))==JSON.parse_string(JSON.stringify(bank)),"stale draft preserves saved progress; failure notification may be saved")
 panel._begin_layout();panel.draft=[];panel._apply_layout();await settle()
 check(state.building.layout.is_empty() and state.furniture.bench==3 and state.building.revision==revision+1,"new owner's draft returns original furniture")
 hud.close_top_panel()
 print("Building draft: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
