extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
 for frame in range(8):await process_frame
func run() -> void:
 create_timer(180).timeout.connect(func():quit(1))
 var tag := str(OS.get_cmdline_user_args()[0])
 var scratch := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var cells: Array = []
 var solids: Array = []
 for cell in world.ground_layer.get_used_cells():
  var coords:Vector2i=world.ground_layer.get_cell_atlas_coords(cell)
  cells.append([cell.x,cell.y,coords.x,coords.y])
  solids.append([cell.x,cell.y,world.npc_navigation.is_point_solid(cell)])
 var snapshot:Dictionary={"cells":cells,"solids":solids,"world":world.world_data}
 var baseline_path:="res://artifacts/cohesion-original-map-20261009.json"
 if tag=="before":
  var file:=FileAccess.open(baseline_path,FileAccess.WRITE);file.store_string(JSON.stringify(snapshot));file.close()
 else:
  var observed:=FileAccess.open("res://artifacts/cohesion-observed-map-20261009.json",FileAccess.WRITE);observed.store_string(JSON.stringify(snapshot));observed.close()
  var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
  check(JSON.stringify(snapshot)==FileAccess.get_file_as_string(baseline_path),"every actual ground cell, navigation solid and original world datum remains byte-identical")
  check(material_unused(reference),"serialized reference includes original entire map")
  check(world.ground_layer.material is ShaderMaterial,"actual game uses terrain blending")
  var material:ShaderMaterial=world.ground_layer.material
  check(material.get_shader_parameter("ground_atlas").get_size()==Vector2(1280,2048),"background texel detail matches painted character assets without changing world tile spacing")
  check(material.get_shader_parameter("cell_atlas").get_size()==Vector2(120,120),"lookup covers original whole map")
  check(world.ground_layer.tile_set.tile_size==Vector2i(32,32),"original world tile spacing")
 var points:Dictionary={}
 for region in ["farm","town","river","bamboo","pasture","mountain"]:
  for house in state.world_village.houses:
   if str(house.region)==region:
    points[region]=Vector2(float(house.door.x),float(house.door.y))+Vector2(0,45);break
  check(points.has(region),"original scene has building and background for "+region)
 for season in range(4 if tag=="after" else 1):
  state.day=season*28
  world._refresh_ground_season(season);call_group("seasonal_world_props","refresh_season")
  for region in points:
   if season>0 and region not in ["farm","town"]:continue
   world.player.global_position=points[region]
   world.player.camera.zoom=Vector2(1.35,1.35);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
   await settle();await RenderingServer.frame_post_draw
   var image:=root.get_texture().get_image()
   check(image!=null and image.get_size()==Vector2i(1280,800),"real full scene rendered "+region)
   check(image.save_png("res://artifacts/cohesion-"+tag+"-"+region+"-s"+str(season)+"-1280.png")==OK,"actual scene saved")
  if tag=="after":
   for cell in world.ground_layer.get_used_cells():
    check(world.ground_layer.get_cell_atlas_coords(cell).y/4==season,"original seasonal tile lookup")
 if tag=="after":
  root.size=Vector2i(1920,1080);state.day=0
  world._refresh_ground_season(0);call_group("seasonal_world_props","refresh_season")
  for region in ["farm","town"]:
   for zoom in [1.0,1.2,1.4]:
    world.player.global_position=points[region];world.player.camera.zoom=Vector2(zoom,zoom);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
    await settle();await RenderingServer.frame_post_draw
    var image:=root.get_texture().get_image()
    check(root.size==Vector2i(1920,1080),"actual requested desktop window size")
    check(root.get_visible_rect().size==Vector2(960,600),"original logical viewport aspect preserved")
    check(image.get_size()==Vector2i(1728,1080),"native 16:10 image within 1920x1080 window, original letterboxing respected")
    check(image.save_png("res://artifacts/cohesion-after-"+region+"-s0-1920-z"+str(roundi(zoom*100))+".png")==OK,"supported camera zoom picture saved")
 await root.get_node("AudioService").prepare_exit()
 print("COHESION_SCENE_RENDER: ",passed," passed, ",failed," failed")
 quit(1 if failed else 0)

func material_unused(reference: Dictionary) -> bool:
 return reference.cells.size()==14400 and reference.solids.size()==14400 and not reference.world.is_empty()
