extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;printerr("FAIL: ",label)
func settle()->void:
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
func run()->void:
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 state.appearance={"shirt":1,"skin":2,"hair":2,"hairColor":1,"hat":true,"bag":true,"outfit":"traveler","weatherDress":true}
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var visual=world.player.character_visual
 var saved:Dictionary=state.appearance.duplicate(true)
 var money:int=state.money;var inventory:Dictionary=state.inventory.duplicate(true)
 for today in range(112):
  state.day=today
  for indoors in [false,true]:
   state.current_interior="home" if indoors else ""
   visual._refresh_player_appearance();visual.queue_redraw();await settle()
   var rainy:bool=not indoors and int(state.weather_profile().get("rain",0))>0
   var cold:bool=not indoors and state.season_index()==3
   var expected:="rain" if rainy else "cold" if cold else "festival" if posmod(today,28)==13 else "traveler"
   check(visual.painted_active and visual.wardrobe.painted_active,"Live weather clothing uses painted parts")
   check(visual.wardrobe.pack_for(visual.appearance)==expected,"Live season and room selector")
   check(state.appearance==saved,"Room and weather never change saved outfit")
 state.current_interior="";state.day=0
 var resident=load("res://scripts/character_visual.gd").new();world.add_child(resident);resident.configure("zhou");resident.set_process(false)
 resident.set_working(true);resident.queue_redraw();await settle()
 check(resident.painted_active,"Working resident uses authored care action")
 check(preload("res://scripts/character_art.gd").has_clip("zhou","care"),"Work action resolves to existing manifest clip")
 check(state.money==money and state.inventory==inventory,"Clothing rendering does not commit economy")
 check(state.save_game("user://wardrobe-compatibility.json",true),"Customized wardrobe save")
 state.appearance={}
 check(state.load_game("user://wardrobe-compatibility.json") and state.appearance==saved,"Customized wardrobe survives save load")
 print("WARDROBE_COMPATIBILITY_RENDER: ",passed," passed, ",failed," failed; 112 days, indoor and outdoor, working NPC, save and load")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
