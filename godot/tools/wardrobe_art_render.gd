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
 var money:int=state.money;var inventory:Dictionary=state.inventory.duplicate(true)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800);change_scene_to_file("res://scenes/main.tscn");await settle()
 var world=current_scene;world.set_process(false);world.player.set_physics_process(false);world.hud.hide();world.player.character_visual.hide()
 var layer:=CanvasLayer.new();layer.layer=100;world.add_child(layer)
 var paper:=ColorRect.new();paper.color=Color("#e9dfc2");paper.size=Vector2(1280,800);layer.add_child(paper)
 var visual:Script=load("res://scripts/character_visual.gd");var rig:Script=load("res://scripts/painted_wardrobe.gd")
 var nodes:Array=[]
 for row in range(4):
  for frame in range(6):
   var node=visual.new();layer.add_child(node);node.position=Vector2(100+frame*200,180+row*190);node.scale=Vector2(3,3);nodes.append(node)
 var pages:=0
 for outfit in ["field","apron","traveler","festival","rain","cold"]:
  for action in rig.CLIPS:
   state.appearance={"shirt":pages%4,"skin":pages%3,"hair":pages%4,"hairColor":pages%4,"hat":pages%2==0,"bag":true,"outfit":outfit if outfit in ["field","apron","traveler","festival"] else "field","weatherDress":false}
   for i in range(24):
    var node=nodes[i];node.configure_player();node.appearance.rain=outfit=="rain";node.appearance.cold=outfit=="cold";node.appearance.festival=outfit=="festival"
    node.action_state=action;node.action_duration=1;node.action_elapsed=(i%6+.25)/6.0;node.walk_clock=(i%6+.25)/8.0
    node.facing=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][i/6];node.set_process(false);node.queue_redraw()
   var saved:Dictionary=state.appearance.duplicate(true);await settle()
   for node in nodes:
    check(node.painted_active and node.wardrobe.visible and node.wardrobe.painted_active,"Actual customized action uses real handpainted parts "+outfit+action)
    check(node.wardrobe.pack_for(node.appearance)==outfit,"Actual clothing selector "+outfit)
    check(node.wardrobe.source==saved,"Saved hairstyle skin outfit hat bag unchanged")
    check(node.wardrobe.last_parts.size()>=8,"Complete body with both arms and legs")
   check(state.appearance==saved,"Rendering never overwrites appearance")
   if action in ["idle","chop","dig"] or outfit=="field":root.get_texture().get_image().save_png("res://artifacts/characters-crops-completion-20261010/wardrobe-"+outfit+"-"+action+".png")
   pages+=1
 check(state.money==money and state.inventory==inventory,"Cosmetic renderer never changes economy")
 print("WARDROBE_ART_RENDER: ",passed," passed, ",failed," failed; ",pages," action and clothing pages")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
