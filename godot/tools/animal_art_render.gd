extends SceneTree
const ART=preload("res://scripts/animal_art.gd")
const VISUAL=preload("res://scripts/ranch_visual.gd")
var passed:int=0
var failed:int=0
class AnimalPaint extends Node2D:
 var animal:Dictionary={}
 var catalog:Dictionary={}
 var clock:float=0.0
 var painted:bool=false
 func _draw()->void:painted=preload("res://scripts/ranch_visual.gd").animal(self,animal,Vector2.ZERO,catalog,clock)
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle()->void:
 for i in range(6):await process_frame
func capture(name:String)->void:
 await settle();await RenderingServer.frame_post_draw
 var image:Image=root.get_texture().get_image()
 check(image!=null and not image.is_empty(),"actual GPU image "+name)
 if image!=null:check(image.save_png("res://artifacts/"+name+".png")==OK,"saved actual image "+name)
func fixture(species:String,direction:String,id:String)->Dictionary:
 return {"id":id,"type":species,"name":{"hen":"鸡","duck":"鸭","cow":"牛","sheep":"羊","pig":"猪"}[species],"age":40,"breed":"local","trait":"calm","hunger":80,"mood":80,"health":80,"clean":80,"illness":0,"rest":false,"ready":0,"position":{"direction":direction,"walking":true,"x":0.0,"y":0.0,"room":null}}
func run()->void:
 create_timer(180).timeout.connect(func():quit(1))
 var scratch:String=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:Node=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 state.appearance=preload("res://scripts/character_art.gd").data().playerProfile.duplicate(true);state.appearance.weatherDress=false
 var inventory:Dictionary=state.inventory.duplicate(true);var props:Array=state.world_village.allProps.duplicate(true);var day:int=state.day
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world:Node=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.visible=false
 world.player.global_position=Vector2(3100,3100);world.player.camera.zoom=Vector2(2,2);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
 world.player.visible=false
 var camera_center:Vector2=world.player.camera.get_screen_center_position()
 var visible_height:float=root.get_visible_rect().size.y/world.player.camera.zoom.y
 var first_foot:float=-visible_height*0.5+72.0
 var row_spacing:float=minf(66.0,(visible_height-92.0)/3.0)
 var species_list:Array=["hen","duck","cow","sheep","pig"]
 var directions:Array=["down","left","right","up"]
 state.animals.clear()
 for row in range(4):
  for col in range(5):
   var a:Dictionary=fixture(species_list[col],directions[row],"art-review-"+str(row)+"-"+str(col))
   a.position.x=camera_center.x+float(col-2)*86.0;a.position.y=camera_center.y+first_foot+float(row)*row_spacing
   state.animals.append(a)
 var animals:Array=state.animals.duplicate(true)
 world._refresh();await settle()
 check(world.animal_nodes.size()==20,"actual farm creates every directional animal")
 for index in range(6):
  state.ranch_actor_clock=(float(index)+0.1)/6.0
  for node in world.animal_nodes:node.queue_redraw()
  await capture("handpainted-animals-live-walk-"+str(index)+"-1280")
  for i in range(world.animal_nodes.size()):
   var node:Node2D=world.animal_nodes[i];var a:Dictionary=state.animals[i]
   check(bool(node.painted_active),"actual RanchAnimal uses bitmap "+str(a.id)+str(index))
   check(node.global_position==Vector2(float(a.position.x),float(a.position.y)),"real authored animal foot point unchanged")
   var v:Dictionary=VISUAL.appearance(a,state.system_catalog.ranch,state.ranch_actor_clock)
   var descriptor:Dictionary=ART.frame(a,v,state.ranch_actor_clock)
   check(int(descriptor.get("index",-1))==index,"actual movement clock selects proper source frame")
   if not descriptor.is_empty():
    var frame_image:Image=descriptor.texture.get_image().get_region(Rect2i(descriptor.source))
    var occupied:Rect2i=frame_image.get_used_rect()
    var ratio:Vector2=descriptor.destination.size/descriptor.source.size
    var local_bounds:Rect2=Rect2(descriptor.destination.position+Vector2(occupied.position)*ratio,Vector2(occupied.size)*ratio)
    var screen_bounds:Rect2=node.get_global_transform_with_canvas()*local_bounds
    check(root.get_visible_rect().encloses(screen_bounds),"whole actual animal inside logical viewport "+str(a.id)+str(index))
 check(state.animals==animals,"rendering cannot change animal save fields")
 var layer:CanvasLayer=CanvasLayer.new();layer.layer=1000;root.add_child(layer)
 var background:ColorRect=ColorRect.new();background.color=Color("f2e8d2");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(background)
 for species in species_list:
  var probes:Array[Node2D]=[]
  var title:Label=Label.new();title.text=str(species)+" · 四方向行走帧";title.position=Vector2(18,8);title.add_theme_color_override("font_color",Color("354537"));background.add_child(title)
  var viewport_size:Vector2=root.get_visible_rect().size
  for row in range(4):
   for column in range(6):
    var probe:AnimalPaint=AnimalPaint.new();probe.animal=fixture(species,directions[row],"gallery");probe.catalog=state.system_catalog.ranch;probe.clock=(float(column)+0.1)/6.0
    probe.position=Vector2(32.0+(viewport_size.x-64.0)*(float(column)+0.5)/6.0,viewport_size.y*(0.24+float(row)*0.20));probe.scale=Vector2.ONE*(1.35 if species=="cow" else 1.8);background.add_child(probe);probes.append(probe)
    var v:Dictionary=VISUAL.appearance(probe.animal,probe.catalog,probe.clock);var descriptor:Dictionary=ART.frame(probe.animal,v,probe.clock)
    check(not descriptor.is_empty(),"actual gallery source exists")
    if not descriptor.is_empty():
     var cell:Image=descriptor.texture.get_image().get_region(Rect2i(descriptor.source));var used:Rect2i=cell.get_used_rect();var ratio:float=float(preload("res://scripts/world_art.gd").entries()["animals/"+species].worldHeight)/108.0
     var bounds:Rect2=Rect2(probe.position+(Vector2(used.position)-Vector2(128,116))*ratio*probe.scale.x,Vector2(used.size)*ratio*probe.scale.x)
     check(root.get_visible_rect().encloses(bounds),"complete real silhouette lies inside gallery viewport")
  await capture("handpainted-animal-"+species+"-walk-gallery-1280")
  for probe in probes:check(bool(probe.painted),"gallery uses actual shared RanchVisual bitmap path");probe.queue_free()
  title.queue_free();await settle()
 layer.queue_free();await settle()
 check(state.inventory==inventory,"rendering preserves inventory")
 check(state.world_village.allProps==props,"rendering preserves source map and collisions")
 check(state.day==day,"rendering cannot advance time")
 print("ANIMAL_ART_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
