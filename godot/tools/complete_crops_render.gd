extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in range(5):await process_frame
func run()->void:
 var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
 var inventory:Dictionary=state.inventory.duplicate(true);var gold:int=state.money
 var plots:Array=state.plots.duplicate(true)
 state.day=0;state.ui_open=false;state.visual_fx.motion="full";state.visual_fx.density="standard"
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide()
 var effects=world.get_node("WorldEffects");effects.set_process(false)
 var queue:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/characters-crops-completion-20261010/queue.json"))
 var low:Vector2=state.farm_plot_position(0);var high:Vector2=low
 for index in range(16):low=low.min(state.farm_plot_position(index));high=high.max(state.farm_plot_position(index))
 var center:Vector2=(low+high)*.5+Vector2(0,-12)
 world.player.global_position=low+Vector2(-45,40)
 world.player.camera.position=center-world.player.global_position
 var zoom:=minf(2.0,minf(800.0/(high.x-low.x+100),500.0/(high.y-low.y+100)))
 world.player.camera.zoom=Vector2(zoom,zoom);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
 for condition in ["healthy","wilt","pest","disease"]:
  for page in range(7):
   for index in range(16):
    var id:String=queue.cropJobs[page*4+index/4].id
    var plot:Dictionary=state.plots[index]
    plot.crop=id;plot.tilled=true;plot.growth=state.crop_days(id)*[0.0,.4,.8,1.0][index%4]
    plot.health=15 if condition=="wilt" else 100;plot.pests=60 if condition=="pest" else 0;plot.disease=60 if condition=="disease" else 0
    effects._update_crop_presentation(.1);world.plot_nodes[index].queue_redraw()
    check(preload("res://scripts/farm_surface_art.gd").crop_condition(plot)==condition,"Live crop condition")
   await settle();await RenderingServer.frame_post_draw
   var image:=root.get_texture().get_image()
   check(image.get_size()==Vector2i(1280,800),"Actual gameplay viewport")
   check(image.save_png("res://artifacts/characters-crops-completion-20261010/crops-"+condition+"-"+str(page)+".png")==OK,"Retained actual crop page")
 for season in range(4):
  state.day=season*28;effects._update_crop_presentation(.1)
  await settle();await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(int(world.plot_nodes[0].crop_presentation.season)==season,"Actual season reaches plot")
  image.save_png("res://artifacts/characters-crops-completion-20261010/crops-season-"+str(season)+".png")
 var clock:float=effects._crop_clock
 state.visual_fx.motion="reduced";effects._update_crop_presentation(.1)
 check(effects._crop_clock==clock and not bool(world.plot_nodes[0].crop_presentation.motion),"Reduced motion stops crop sway")
 state.visual_fx.motion="full";state.ui_open=true;effects._update_crop_presentation(.1)
 check(effects._crop_clock==clock and not bool(world.plot_nodes[0].crop_presentation.motion),"Open menu pauses crop sway")
 state.ui_open=false;state.day=0
 state.plots[0].growth=state.crop_days(str(state.plots[0].crop))*.99
 effects.configure_plots(world.plot_nodes);state.plots[0].growth=state.crop_days(str(state.plots[0].crop))
 effects._scan_crop_growth()
 check(world.plot_nodes[0].growth_pulse_age==0,"Maturity feedback starts at mature stage")
 world.plot_nodes[0]._process(.85);effects._scan_crop_growth()
 check(world.plot_nodes[0].growth_pulse_age<0,"Maturity feedback occurs once")
 check(state.inventory==inventory and state.money==gold,"Visual checks never commit stock or payment")
 state.plots=plots
 print("COMPLETE_CROPS_RENDER: ",passed," passed, ",failed," failed; all 28 crops, four conditions, four stages and seasons")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
