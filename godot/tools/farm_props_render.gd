extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle()->void:
 for i in range(6):await process_frame
func capture(name:String)->void:
 await settle();await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 check(image!=null and not image.is_empty(),"real GPU viewport "+name)
 if image!=null:check(image.save_png("res://artifacts/"+name+".png")==OK,"saved actual frame")
func run()->void:
 create_timer(120).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_art.theme="paper"
 var world_art=load("res://scripts/world_art.gd")
 var original:Array=state.world_village.allProps.duplicate(true)
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 if world.hud.onboarding_open():world.hud.toggle_onboarding()
 var kinds:=["scarecrow","haystack","rack"]
 var actual:Dictionary={}
 for kind in kinds:actual[kind]=[]
 for node in world.find_children("*","Node2D",true,false):
  if node.get_script()==null or node.get_script().resource_path!="res://scripts/world_prop.gd":continue
  var kind:String=str(node.data.get("kind",node.data.get("type","")))
  if not actual.has(kind):continue
  actual[kind].append(node)
  check(node.global_position==Vector2(float(node.data.x),float(node.data.y)),"original world foot position unchanged "+kind)
  check(node.painted_active,"actual original prop issues bitmap draw "+kind)
  check(world_art.key_for(node.data)=="props/"+kind,"actual instance binds its own unique kind "+kind)
  check(node.find_children("*","CollisionShape2D",true,false).is_empty(),"visual added no new collider")
 for kind in kinds:
  check(not actual[kind].is_empty(),"original map contains live "+kind+" instances")
  var row:Dictionary=world_art.entries()["props/"+kind]
  check(bool(row.get("baseReady",false)) and str(row.status)=="partial","single sprite does not claim whole object complete")
  check(load("res://scripts/character_art.gd").texture(str(row.path))!=null,"real prop PNG exists")
  if actual[kind].is_empty():continue
  var node:Node2D=actual[kind][0]
  world.player.global_position=node.global_position+Vector2(0,45)
  world.player.camera.zoom=Vector2(3,3);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  await capture("handpainted-world-prop-"+kind+"-1280")
 var layer:=CanvasLayer.new();layer.layer=1000;root.add_child(layer)
 var background:=ColorRect.new();background.color=Color("f2e8d2");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(background)
 for index in range(kinds.size()):
  var kind:String=kinds[index]
  var data:Dictionary={"kind":kind,"x":0,"y":0,"w":48,"h":56}
  if not actual[kind].is_empty():data=actual[kind][0].data.duplicate(true)
  var prop=load("res://scripts/world_prop.gd").new();prop.data=data;background.add_child(prop)
  var viewport_size:=root.get_visible_rect().size
  prop.position=Vector2(viewport_size.x*(0.125+0.25*(index%4)),viewport_size.y*(0.38 if index<4 else 0.80));prop.scale=Vector2(2,2);prop.queue_redraw()
  var rectangle:Array=world_art.entries()["props/"+kind].worldRect
  var bounds:=Rect2(prop.position+Vector2(float(rectangle[0]),float(rectangle[1]))*2,Vector2(float(rectangle[2]),float(rectangle[3]))*2)
  check(root.get_visible_rect().encloses(bounds),"whole gallery object inside logical viewport "+kind)
  var label:=Label.new();label.position=prop.position+Vector2(-60,40);label.text={"scarecrow":"田间稻草人","haystack":"草料堆","rack":"竹木收纳架"}[kind];label.add_theme_color_override("font_color",Color("354537"));background.add_child(label)
 await capture("handpainted-farm-props-gallery")
 for child in background.get_children():
  if child is Node2D:check(bool(child.get("painted_active")),"gallery uses actual WorldProp draw route")
  elif child is Label:check(root.get_visible_rect().encloses(child.get_global_rect()),"gallery label remains visible")
 check(state.world_village.allProps==original,"all original world prop data unchanged")
 layer.queue_free();await settle()
 print("FARM_PROPS_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)

