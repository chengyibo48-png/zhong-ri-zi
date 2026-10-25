extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 create_timer(180).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 var w:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/map-layout-envelope-audit-20261010.json"))
 var masks:Dictionary={};var stamps:Dictionary={}
 var viewport:=SubViewport.new();viewport.size=Vector2i(512,512);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 for pair in audit.pairs:
  for entry in [pair.a,pair.b]:
   var identity:String=entry.id
   if masks.has(identity):continue
   var tokens:Array=identity.split(":");var rows:Array=w.village.allProps if tokens[0]=="village" else w.tiles.objects
   var data:Dictionary=preload("res://scripts/world_layout.gd").prop(rows[int(tokens[1])],int(tokens[1]),str(tokens[0]))
   var kind:String=str(data.get("kind",data.get("type","")));var asset:Dictionary=w.tiles.assets.get(kind,{})
   if not data.has("w"):data.w=asset.get("w",48)
   if not data.has("h"):data.h=asset.get("h",56)
   var at:=Vector2(float(data.x),float(data.y))
   if kind=="house":at+=Vector2(float(data.w)*.5,float(data.h))
   var prop=load("res://scripts/world_prop.gd").new();prop.data=data;prop.position=Vector2(256,300);viewport.add_child(prop);prop.set_process(false)
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   var img:=viewport.get_texture().get_image();var used:=img.get_used_rect()
   if used.position.x==0 or used.position.y==0 or used.end.x>=512 or used.end.y>=512:push_error("Clipped measurement "+identity);quit(1);return
   var pixels:Dictionary={}
   for y in range(used.position.y,used.end.y):
    for x in range(used.position.x,used.end.x):
     if img.get_pixel(x,y).a>=.5:pixels[Vector2i((at+Vector2(x-256,y-300)).round())]=true
   masks[identity]=pixels;stamps[identity]={"opaque_core_pixels":pixels.size(),"screen_measurement_clipped":false}
   prop.queue_free();await process_frame
 var results:Array=[]
 for i in audit.pairs.size():
  var pair:Dictionary=audit.pairs[i];var a:Dictionary=masks[pair.a.id];var b:Dictionary=masks[pair.b.id];var overlap:=0
  for p in a:
   if b.has(p):overlap+=1
  results.append({"index":i,"a":pair.a.id,"b":pair.b.id,"kinds":[pair.a.kind,pair.b.kind],"opaque_core_overlap_pixels":overlap,"pixel_intersection":overlap>0})
 var file:=FileAccess.open("res://artifacts/remaining-fixed-silhouette-review-20261010.json",FileAccess.WRITE);file.store_string(JSON.stringify({"scope":"actual original WorldProp draw paths rendered alone, 1 world pixel resolution, alpha >= .5 excludes soft ground shadows; not a collision or whole-route proof","independent_prop_masks":stamps,"pairs":results},"  ")+"\n");file.close()
 print("FIXED_SILHOUETTE: ",results.size()," pairs independently measured, ",masks.size()," actual prop silhouettes")
 viewport.queue_free();await process_frame;await root.get_node("AudioService").prepare_exit();quit(0)
