extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func same(a:Variant,b:Variant)->bool:
 return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func settle()->void:
 await process_frame
 await process_frame
func run()->void:
 await settle()
 var temp:String=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state:Node=root.get_node("GameState");state.set_process(false)
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LEGACY_FURNITURE_FIXTURE")))
 for row in fixture.rows:
  check(state.load_game_data(state.convert_external_save(row.before)),"load original "+row.label)
  var got:bool=state.recover_legacy_furniture(int(row.requested))
  check(got==row.result.ok and state.message==row.result.msg,"original recovery result "+row.label)
  check(same(state.building,row.expected.building),"recovery building "+row.label)
  check(same(state.furniture,row.expected.furniture),"recovery entire furniture basket "+row.label)
  check(same(state.legacy_systems.layouts,row.expected.layouts) and state.legacy_systems.greenhouse==row.expected.greenhouse,"old placement and greenhouse "+row.label)
  check(state.money==row.expected.money and state.stamina==row.expected.stamina and state.minutes==row.expected.minutes,"recovery no unrelated cost "+row.label)
 var atlas:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_furniture.json"))
 check(same(atlas.slots,fixture.slots.map(func(p:Dictionary)->Dictionary:return {"x":p.x,"y":p.y})),"all 24 source world coordinates")
 for key in atlas.assets:check(ResourceLoader.exists(atlas.assets[key].path),"source seasonal artwork "+str(key))
 check(state.load_game_data(state.convert_external_save(fixture.source)),"actual world source load")
 change_scene_to_file("res://scenes/main.tscn");await settle()
 var world:Node=current_scene;world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 check(world.legacy_furniture_nodes.size()==2,"old source props instantiated")
 for slot in [5,23]:
  var prop:Node=world.legacy_furniture_nodes.get(slot)
  var expected:Dictionary=fixture.slots[slot]
  check(prop is Sprite2D and prop.position==Vector2(expected.x,expected.y) and prop.texture!=null,"source prop position and texture "+str(slot))
 for season in range(4):
  state.day=season*28;state.changed.emit();await settle()
  for slot in [5,23]:
   var prop:Node=world.legacy_furniture_nodes[slot]
   check(prop.season==season and prop.texture.resource_path.ends_with("-%d-%d.svg"%[season,slot%6]),"live seasonal legacy art")
 state.day=0;state.changed.emit();await settle()
 world.hud.show_building({},true)
 var panel:Node=world.hud.building_panel;panel._set_tab("layout");await settle()
 var button:Button=panel.find_child("RecoverLegacy5",true,false)
 check(button!=null and not button.disabled,"actual legacy recovery button")
 var quantity:int=int(state.furniture.get("bench",0));var revision:int=int(state.building.revision)
 button.pressed.emit();await settle()
 check(world.legacy_furniture_nodes.size()==1 and not world.legacy_furniture_nodes.has(5),"recover removes only matching world prop")
 check(int(state.furniture.bench)==quantity+1 and int(state.building.revision)==revision+1 and panel.draft_revision==state.building.revision,"actual UI returns furniture and rebases draft")
 var saved:Variant=state._read_save_json(state.SAVE_PATH)
 check(saved is Dictionary and saved.legacy_systems.layouts.size()==1 and int(saved.furniture.bench)==quantity+1,"actual recovery immediately persisted")
 if OS.get_environment("LEGACY_FURNITURE_SCREENSHOT")!="":
  world.hud.close_top_panel()
  state.player_position=Vector2(3168,2182);world.player.global_position=state.player_position
  await settle();await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LEGACY_FURNITURE_SCREENSHOT"))
 world.hud.close_top_panel()
 print("Legacy furniture: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
