extends SceneTree
var records:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
 create_timer(180).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn")
 for frame in 8:await process_frame
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/map-layout-envelope-audit-20261010.json"))
 var sheet:Image
 for i in audit.pairs.size():
  var pair:Dictionary=audit.pairs[i];var a:Array=pair.a.box;var b:Array=pair.b.box
  var bounds:=Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3])).merge(Rect2(float(b[0]),float(b[1]),float(b[2]),float(b[3])))
  world.player.global_position=bounds.get_center()+Vector2(0,65);world.player.camera.zoom=Vector2(2,2);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  for frame in 6:await process_frame
  await physics_frame
  var shape:=CircleShape2D.new();shape.radius=6
  var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.transform=Transform2D(0,bounds.get_center());query.exclude=[world.player.get_rid()]
  var hits:Array=world.get_world_2d().direct_space_state.intersect_shape(query)
  await RenderingServer.frame_post_draw
  var img:=root.get_texture().get_image()
  var path:="res://artifacts/remaining-fixed-overlap-%02d-20261010.png"%i
  if img.save_png(path)!=OK:quit(1);return
  records.append({"index":i,"a":pair.a.id,"b":pair.b.id,"kinds":[pair.a.kind,pair.b.kind],"intersection_has_static_geometry":not hits.is_empty(),"screenshot":path,"manual_review":"pending","route_obstruction_proven":false})
  if i%9==0:sheet=Image.create(1920,1200,false,Image.FORMAT_RGBA8);sheet.fill(Color("f2e8d2"))
  img.resize(640,400,Image.INTERPOLATE_LANCZOS);sheet.blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),Vector2i((i%3)*640,((i%9)/3)*400))
  if i%9==8 or i==audit.pairs.size()-1:
   if sheet.save_png("res://artifacts/remaining-fixed-overlap-sheet-%d-20261010.png"%(i/9))!=OK:quit(1);return
 var f:=FileAccess.open("res://artifacts/remaining-fixed-overlap-review-20261010.json",FileAccess.WRITE);f.store_string(JSON.stringify({"pairs":records,"isolated_userdata":true,"note":"A static hit at one sample is not proof of a blocked route; review silhouettes and entrances separately."},"  ")+"\n");f.close()
 print("FIXED_OVERLAP: ",records.size()," screenshots and physics samples captured")
 await root.get_node("AudioService").prepare_exit();quit(0)
