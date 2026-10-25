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
 var state:=root.get_node("GameState");state.set_process(false);state.day=0;state.flags.introDone=true
 var inventory:Dictionary=state.inventory.duplicate(true);var money:int=state.money
 state.appearance=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json")).playerProfile.duplicate(true)
 state.appearance.weatherDress=false
 root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false)
 var hud=world.hud
 if hud.onboarding_open():hud.toggle_onboarding()
 var expressions:=["calm","focus","happy","surprised","thought","tired","worried"]
 var people:=0
 for person in state.npc_catalog:
  for emotion in expressions:
   state.neighbors.people[person.id].last={"text":"表情校验 · "+emotion,"emotion":emotion,"category":"校验"}
   hud.show_npc_dialogue(person.id);await settle()
   var widget=hud.npc_dialogue.column.get_child(2).get_child(0)
   check(widget.get_script()==load("res://scripts/character_portrait.gd") and widget.painted_active,"Actual dialogue painted portrait "+str(person.id)+emotion)
   check(widget.emotion==emotion,"Dialogue expression binding "+str(person.id)+emotion)
   if emotion in ["calm","worried"]:root.get_texture().get_image().save_png("res://artifacts/characters-crops-completion-20261010/dialogue-"+str(person.id)+"-"+emotion+".png")
   hud.close_top_panel()
  people+=1
 check(people==24,"24 resident dialogue actors")
 hud.hide();world.player.character_visual.hide()
 var center:Vector2=state.farm_plot_position(5)+Vector2(0,-12)
 world.player.global_position=center
 world.player.camera.position=Vector2.ZERO;world.player.camera.zoom=Vector2(1.8,1.8);world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
 var visual:Script=load("res://scripts/character_visual.gd")
 var review_layer:=CanvasLayer.new();review_layer.layer=100;world.add_child(review_layer)
 var paper:=ColorRect.new();paper.color=Color("#e9dfc2");paper.size=Vector2(960,600);paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;review_layer.add_child(paper)
 var nodes:Array=[]
 for row in range(4):
  for frame in range(6):
   var node:Node2D=visual.new();review_layer.add_child(node);node.position=Vector2(90+frame*150,140+row*140);nodes.append(node)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_art_manifest.json"))
 var count:=0
 for actor_id in manifest.actors:
  for clip in manifest.actors[actor_id].clips:
   var spec:Dictionary=manifest.actors[actor_id].clips[clip]
   if not spec.has("sourceFrames") or not spec.sourceFrames[0].has("rect"):continue
   for i in range(24):
    var node=nodes[i]
    node.scale=Vector2.ONE
    if actor_id=="player":node.configure_player()
    else:node.configure(actor_id)
    node.scale*=2.0
    node.facing=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][i/6]
    node.action_state=clip;node.action_duration=1;node.action_elapsed=(i%6+.25)/6.0;node.fishing_state="idle";node.riding=false
    node.walk_clock=(i%6+.25)/float(spec.fps);node.set_process(false);node.queue_redraw()
   await settle()
   for i in range(24):check(nodes[i].painted_active,"Actual action uses handpainted frame "+str(actor_id)+clip+str(i))
   root.get_texture().get_image().save_png("res://artifacts/characters-crops-completion-20261010/action-"+str(actor_id)+"-"+clip+".png");count+=1
 check(state.money==money and state.inventory==inventory,"Preview never commits money or inventory")
 print("COMPLETE_CHARACTERS_RENDER: ",passed," passed, ",failed," failed; ",people," dialogue actors, ",count," actual action pages")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)




