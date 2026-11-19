extends SceneTree
var passed:int=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failures.append(label);printerr("FAIL ",label)
func run()->void:
 create_timer(90).timeout.connect(func():quit(2))
 var s:Node=root.get_node("GameState");s.set_process(false);s.quest_runtime.set_process(false)
 var service:Script=load("res://scripts/starter_livestock.gd")
 check(service.count(s)==2 and s.ranch_animal_count("cow")==2,"fresh startup owns two adult cattle")
 check(s.ranch_animal_count("hen")==1 and s.ranch_animal_count("duck")==1,"initial poultry preserved")
 var fresh:Dictionary=s._new_game_snapshot()
 check(fresh.animals.size()==4 and bool(fresh.flags.get(service.FLAG,false)),"explicit new life snapshot includes starter pair and receipt")
 check(load("res://scripts/native_save_schema.gd").error(fresh,s.initial_state)=="","new life snapshot passes existing v38 schema")
 var parsed:Variant=load("res://scripts/save_repository.gd").read(OS.get_environment("ZRZ_SOURCE_SAVE"))
 check(s.load_game_data(parsed),"load actual existing v38 save into isolated runtime")
 s.ui_open=true
 var originals:Array=s.animals.duplicate(true)
 var previous:Dictionary={"money":s.money,"inventory":s.inventory.duplicate(true),"day":s.day,"minutes":s.minutes,"relations":s.relations.duplicate(true),"fishing":s.fishing.duplicate(true),"plots":s.plots.duplicate(true)}
 check(service.count(s)==1 and not s.flags.get(service.FLAG,false),"existing player needs exactly one additional livestock animal")
 change_scene_to_file("res://scenes/main.tscn")
 for i:int in 3:await process_frame
 current_scene.player.set_physics_process(false)
 await s.wait_for_saves()
 for i:int in 4:await process_frame
 check(service.count(s)==2 and s.animals.size()==originals.size()+1,"actual HUD startup grants one missing animal")
 check(bool(s.flags.get(service.FLAG,false)),"grant persists one-time receipt")
 var intact:bool=true
 for animal:Dictionary in originals:
  var i:int=s.ranch_animal_index(str(animal.id))
  if i<0 or s.animals[i]!=animal:intact=false
 check(intact,"all original animals and their state remain unchanged")
 var unchanged:bool=true
 for field:String in previous:
  if s.get(field)!=previous[field]:unchanged=false;printerr("CHANGED ",field)
 check(unchanged,"money inventory crops fishing relationships and date conserved")
 var ids:Dictionary={}
 for animal:Dictionary in s.animals:ids[str(animal.id)]=true
 check(ids.size()==s.animals.size(),"starter animal identity unique")
 check(s._ranch_space_for("cow")==false,"two cattle occupy original two-place barn correctly")
 check(not service.grant(s),"repeat startup cannot grant again")
 check(s.save_game("user://starter-test-v38.json",true),"updated herd saves")
 await s.wait_for_saves()
 check(s.load_game("user://starter-test-v38.json"),"updated herd loads")
 check(service.count(s)==2 and not service.grant(s),"save/load cannot duplicate starter grant")
 var gifted:int=-1
 for i:int in s.animals.size():
  if not originals.any(func(a:Dictionary):return str(a.id)==str(s.animals[i].id)):gifted=i;break
 if gifted>=0:s.animals.remove_at(gifted)
 check(not service.grant(s) and service.count(s)==1,"intentional later animal removal does not respawn entitlement")
 var file:=FileAccess.open(OS.get_environment("ZRZ_ART_OUTPUT")+"/starter.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"failures":failures,"isolated":true},"  "));file.close()
 print("STARTER_LIVESTOCK passed=",passed," failures=",failures.size())
 current_scene.queue_free();await process_frame
 await s.wait_for_saves();await root.get_node("AudioService").prepare_exit();quit(0 if failures.is_empty() else 1)
