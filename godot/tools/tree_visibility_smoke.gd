extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else: failed += 1; push_error(label)
func settle() -> void:
 for frame in range(5): await process_frame
func fade_settle() -> void:
 await create_timer(0.45).timeout
 await settle()
func run() -> void:
 create_timer(300).timeout.connect(func():quit(1))
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state:=root.get_node("GameState")
 state.set_process(false)
 state.flags.introDone=true
 var original_world:=FileAccess.get_file_as_string("res://data/world.json")
 change_scene_to_file("res://scenes/main.tscn")
 await settle()
 var world=current_scene
 world.set_process(false);world.player.set_physics_process(false)
 var world_art=load("res://scripts/world_art.gd")
 var entries:Dictionary=world_art.entries()
 var door:Dictionary=entries["buildings/home-lin"].door
 var trees:Array=[]
 var saved:Array=[]
 var target:Node2D
 for prop in world.get_children():
  if prop.get_script()==null or prop.get_script().resource_path!="res://scripts/world_prop.gd":continue
  var row:Dictionary=prop.get("data")
  var kind:=str(row.get("kind",""))
  var foliage:=kind in ["tree","willow","orchard","blossom"] and bool(entries.get("props/"+kind,{}).get("baseReady",false))
  if not foliage:
   check(not prop.is_processing(),"non-painted-foliage props do not poll visibility")
   continue
  check(prop.is_processing(),"only explicitly painted foliage processes occlusion")
  trees.append(prop)
  saved.append({"data":row.duplicate(true),"position":prop.position})
  if prop.position.distance_to(Vector2(3685,527))<0.01:target=prop
 check(target!=null,"original Lin doorstep tree exists")
 if target==null:quit(1);return
 # Occlusion now updates only visible props: keep each tested canopy in view.
 var camera:Camera2D=world.player.camera
 camera.position_smoothing_enabled=false
 camera.set_as_top_level(true)
 camera.global_position=target.global_position
 camera.force_update_scroll()
 var far:=Vector2(2048,2048)
 world.player.global_position=far
 await fade_settle()
 for prop in trees:check(is_equal_approx(prop.modulate.a,1.0),"unrelated foliage remains opaque")
 for season in range(4):
  state.day=28*season;call_group("seasonal_world_props","refresh_season")
  world.player.global_position=Vector2(float(door.x),float(door.y)+45.0)
  await fade_settle()
  check(is_equal_approx(target.modulate.a,0.42),"actual canopy fades behind player in season "+str(season))
  check(bool(target.get("painted_active")),"faded tree still uses its real seasonal bitmap")
  check(Vector3(target.modulate.r,target.modulate.g,target.modulate.b)==Vector3.ONE,"native tree color channels remain unchanged")
  world.player.global_position=target.global_position+Vector2(0,30)
  await fade_settle()
  check(is_equal_approx(target.modulate.a,1.0),"player in front of trunk keeps foliage opaque")
  world.player.global_position=target.global_position+Vector2(80,-12)
  await fade_settle()
  check(is_equal_approx(target.modulate.a,1.0),"player beside canopy keeps foliage opaque")
 world.player.global_position=Vector2(float(door.x),float(door.y)+45.0)
 await settle()
 world.player.global_position=far
 await fade_settle()
 check(is_equal_approx(target.modulate.a,1.0),"reversed fade restores original opacity")
 for i in range(trees.size()):
  check(trees[i].position==saved[i].position and trees[i].data==saved[i].data,"tree data and positions remain unchanged")
  check(trees[i].get_child_count()==0,"visibility introduces no physical nodes")
 for prop in trees:
  if not str(prop.data.get("kind","")) in ["willow","blossom","orchard"]:continue
  camera.global_position=prop.global_position
  camera.force_update_scroll()
  for season in range(4):
   state.day=28*season;call_group("seasonal_world_props","refresh_season")
   world.player.global_position=prop.position+Vector2(0,-20)
   await fade_settle()
   check(is_equal_approx(prop.modulate.a,.42),"every original willow, blossom and orchard fades behind player in each season")
   check(prop.painted_active,"fading seasonal tree remains actual seasonal bitmap")
   world.player.global_position=prop.position+Vector2(0,35)
   await fade_settle()
   check(is_equal_approx(prop.modulate.a,1.0),"every original willow, blossom and orchard restores alpha in each season")
 check(original_world==FileAccess.get_file_as_string("res://data/world.json"),"authored collision/navigation/interaction data byte-identical")
 print("TREE_VISIBILITY_SMOKE: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
