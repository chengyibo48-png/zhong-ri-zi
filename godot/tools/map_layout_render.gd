extends SceneTree
var passed:=0
var failed:=0
const LAYOUT=preload("res://scripts/world_layout.gd")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in range(8):await process_frame
func capture(name:String)->void:
 await settle();await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 check(image!=null and image.get_size()==Vector2i(1280,800),"actual native viewport size")
 check(image.save_png("res://artifacts/map-layout-"+name+"-20261009.png")==OK,"actual frame archived")
func run()->void:
 create_timer(180).timeout.connect(func():quit(1))
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 var original_village:Dictionary=state.world_village.duplicate(true)
 var original_plots:Array=state.plots.duplicate(true)
 var original_pet:Dictionary=state.ranch.pet.duplicate(true)
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var plan:Dictionary=LAYOUT.plan();var found:Dictionary={};var prop_count:=0
 for node in world.get_children():
  if node.get_script()==null or node.get_script().resource_path!="res://scripts/world_prop.gd":continue
  prop_count+=1
  if node.data.has("_layout_rect"):
   var kind:String=str(node.data.get("kind",node.data.get("type","")))
   var identity:=""
   for key in plan.props:
    var row:Dictionary=plan.props[key]
    if str(row.kind)==kind and Vector2(float(row.x),float(row.y))==node.position:identity=key;break
   check(identity!="","real runtime scenery matches audited placement")
   check(not found.has(identity),"no duplicate planned scenery")
   found[identity]=true
   check(node.find_children("*","CollisionShape2D",true,false).is_empty(),"decorative move adds no hidden collider")
 check(prop_count==742,"all authored scenery retained")
 check(found.size()==352,"all planned scenery actually instantiated")
 var shape_rects:Dictionary={}
 for node in world.get_children():
  if not node is StaticBody2D:continue
  var shape:CollisionShape2D=node.get_child(0)
  var bounds:=Rect2(node.position-shape.shape.size*.5,shape.shape.size)
  check(not shape_rects.has(bounds),"runtime contains no duplicated static blocker")
  shape_rects[bounds]=true
 for row in plan.collisionOverrides:
  var corrected:=Rect2(float(row.rect[0]),float(row.rect[1]),float(row.rect[2]),float(row.rect[3]))
  var obsolete:=Rect2(float(row.source[0]),float(row.source[1]),float(row.source[2]),float(row.source[3]))
  check(shape_rects.has(corrected) and not shape_rects.has(obsolete),"real physics uses corrected wall, not only a moved picture")
 await physics_frame
 var space:PhysicsDirectSpaceState2D=world.get_world_2d().direct_space_state
 var circle:=CircleShape2D.new();circle.radius=6
 var destination:Vector2i=world._nearest_npc_walkable(Vector2(960,1100))
 for house in state.world_village.houses:
  var door:=Vector2(float(house.door.x),float(house.door.y))
  var query:=PhysicsShapeQueryParameters2D.new();query.shape=circle;query.transform=Transform2D(0,door+Vector2(0,12));query.exclude=[world.player.get_rid()]
  check(space.intersect_shape(query).is_empty(),"actual player-sized entrance space remains clear "+str(house.id))
  var start:Vector2i=world._nearest_npc_walkable(door+Vector2(0,20))
  check(not world.npc_navigation.get_id_path(start,destination).is_empty(),"every building entrance reaches shared village routes "+str(house.id))
 var snapshots:Array=[]
 for cell in world.ground_layer.get_used_cells():snapshots.append([cell.x,cell.y,world.ground_layer.get_cell_atlas_coords(cell).x,world.ground_layer.get_cell_atlas_coords(cell).y,world.npc_navigation.is_point_solid(cell)])
 var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/cohesion-original-map-20261009.json"))
 for i in snapshots.size():
  check(float(snapshots[i][0])==float(reference.cells[i][0]) and float(snapshots[i][1])==float(reference.cells[i][1]) and float(snapshots[i][2])==float(reference.cells[i][2]) and float(snapshots[i][3])==float(reference.cells[i][3]),"typed ground metadata retains original semantics")
  check(snapshots[i][4]==reference.solids[i][2],"navigation occupancy retains original safe grid")
 var lookup:Image=world.ground_layer.material.get_shader_parameter("cell_atlas").get_image()
 var changed:=0
 for cell in world.ground_layer.get_used_cells():
  var authored:Vector2i=world.ground_layer.get_cell_atlas_coords(cell)
  var drawn:=roundi(lookup.get_pixelv(cell).r*255)
  check(drawn==LAYOUT.ground_column(cell,authored.x),"drawn terrain matches explicit farm floor and route plan")
  if drawn!=authored.x:changed+=1
 check(changed>0,"crop road conflict is really corrected on GPU lookup")
 var points:Dictionary={"farm":Vector2(2770,1740),"town":Vector2(2840,590),"bamboo":Vector2(1070,1650),"river":Vector2(1550,3290),"mountain":Vector2(1260,680),"pasture":Vector2(2570,2540)}
 for region in points:
  world.player.global_position=points[region];world.player.camera.zoom=Vector2(1.1,1.1);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  await capture(str(region)+"-spring")
 for season in range(1,4):
  state.day=season*28;world._refresh_ground_season(season);call_group("seasonal_world_props","refresh_season")
  world.player.global_position=points.farm;world.player.camera.zoom=Vector2(1.1,1.1);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
  await capture("farm-season-"+str(season))
  var seasonal:Image=world.ground_layer.material.get_shader_parameter("cell_atlas").get_image()
  for cell in world.ground_layer.get_used_cells():check(roundi(seasonal.get_pixelv(cell).g*255)/4==season,"planned ground remains in current season")
 state.day=0;world._refresh_ground_season(0);call_group("seasonal_world_props","refresh_season")
 var saved_companion:Dictionary=state.pet_state.duplicate(true)
 var saved_minutes:float=state.minutes
 state.pet_state={"type":"cat"};state.minutes=360
 world.player.global_position=Vector2(2795,1800);world.player.camera.zoom=Vector2(1.1,1.1);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
 for direction in ["down","left","right","up"]:
  state.ranch.pet={"energy":100,"position":{"x":2832,"y":1800,"direction":direction}}
  var fixture:Dictionary=state.ranch.pet.duplicate(true)
  check(not preload("res://scripts/pet_art.gd").frame(state.ranch.pet,state.pet_state,state.minutes).is_empty(),"actual pet state binds real cat direction")
  world.queue_redraw();await capture("cat-"+direction)
  check(state.ranch.pet==fixture,"actual cat rendering leaves pet energy and position untouched")
 state.ranch.pet=original_pet.duplicate(true);state.pet_state=saved_companion;state.minutes=saved_minutes;world.queue_redraw()
 var view:=SubViewport.new();view.size=Vector2i(1536,1536);view.world_2d=root.world_2d;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var camera:=Camera2D.new();view.add_child(camera);camera.position=Vector2(1920,1920);camera.zoom=Vector2(.4,.4);camera.make_current();camera.force_update_scroll()
 await settle();await RenderingServer.frame_post_draw
 var overview:=view.get_texture().get_image()
 check(overview.get_size()==Vector2i(1536,1536),"whole 3840x3840 world has native square overview")
 check(overview.save_png("res://artifacts/map-layout-whole-world-20261009.png")==OK,"actual full map overview saved")
 view.queue_free();await settle()
 check(state.world_village==original_village,"logical house doors and schedules unchanged")
 check(state.plots==original_plots,"rendering leaves all crop state unchanged")
 check(state.ranch.pet==original_pet,"pet rendering does not mutate saved position or energy")
 print("MAP_LAYOUT_RENDER: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
