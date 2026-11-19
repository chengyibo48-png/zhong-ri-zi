extends SceneTree
const IDS:=["pot","path","fence","orchard","photo","waterbed","scarecrow","greenhouse","lantern","sign","seedrack","rug"]
const ART:=preload("res://scripts/built_furniture_art.gd")
var state:Node
var passed:=0
var failed:=0
var output:String
class Gallery extends Node2D:
	var ids:Array=[]
	var minute:=720
	func _draw()->void:
		draw_rect(Rect2(0,0,1280,800),Color("a7b091"))
		for i in ids.size():
			for view in range(4):
				var anchor:=Vector2(52+(i%4)*315+view*75,200+floorf(i/4.0)*250)
				preload("res://scripts/built_furniture_art.gd").draw(self,{"type":ids[i],"rotation":view},Rect2(anchor-Vector2(33,60),Vector2(66,60)),minute)
			draw_string(ThemeDB.fallback_font,Vector2(22+(i%4)*315,224+floorf(i/4.0)*250),str(ids[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("35483b"))
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func settle()->void:
	for i in range(8):await process_frame
func capture(name:String)->void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"GPU capture "+name)
func fixture(ids:Array,direction:int,zone_id:String)->Array:
	var layout:Array=[];var zone:Dictionary=state.system_catalog.building.zones[zone_id]
	for id:String in ids:
		var found:=false
		for cell in range(int(zone.cols)*int(zone.rows)):
			var piece:Dictionary={"key":layout.size()+1,"type":id,"zone":zone_id,"cell":cell,"rotation":direction}
			if not state.building_placement_valid(piece,layout).ok:continue
			var next:=layout.duplicate(true);next.append(piece)
			if not state.check_building_layout(next).ok:continue
			layout=next;found=true;break
		check(found,"legal placement "+id+str(direction))
	return layout
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		printerr("Five-stage checks require isolated TEMP and APPDATA");quit(1);return
	state=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.ui_hud_visible=false;state.minutes=720
	state.upgrades.yard=true;state.building.house=3;state.building.land.orchard=true;state.building.layout=[];state.building.revision=0;state.legacy_systems.layouts=[]
	output=OS.get_environment("ZRZ_ART_OUTPUT");root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	for id:String in IDS:
		state.furniture[id]=10
		for rotation in range(4):
			var texture:=ART.texture_for(id,rotation)
			check(texture!=null and maxf(texture.get_width(),texture.get_height())<=512,"bounded runtime texture "+id+str(rotation))
		var zone_id:="home" if id in ["photo","rug"] else "court"
		for rotation in range(4):fixture([id],rotation,zone_id)
	var economy:Dictionary={"money":state.money,"stamina":state.stamina,"inventory":state.inventory.duplicate(true),"plots":state.plots.duplicate(true)}
	var page:=Gallery.new();page.ids=IDS.duplicate();root.add_child(page)
	for minute in [720,1200,1260]:page.minute=minute;page.queue_redraw();await capture("furniture-v8-"+str(minute))
	page.queue_free();await process_frame
	check(state.apply_building_layout(fixture(["path","greenhouse","lantern","seedrack"],0,"court"),0,state.building_epoch),"normal outdoor placement commits")
	change_scene_to_file("res://scenes/main.tscn");await settle();current_scene.hud.hide();current_scene.player.set_physics_process(false)
	current_scene.player.global_position=Vector2(3185,2090);current_scene.player.camera.zoom=Vector2(1.6,1.6);current_scene.player.camera.reset_smoothing();current_scene.player.camera.force_update_scroll()
	check(current_scene.built_furniture_nodes.size()==4,"outdoor uses four new actual models")
	for node:Node2D in current_scene.built_furniture_nodes:
		if str(node.piece.type)=="path":check(node.z_index<0,"path stays under actor feet")
	await capture("furniture-v8-courtyard")
	check(state.apply_building_layout(fixture(["rug","photo","pot","lantern"],0,"home"),int(state.building.revision),state.building_epoch),"normal home layout and inventory returns")
	check(state.furniture.path==10 and state.furniture.greenhouse==10 and state.furniture.seedrack==10,"removed outdoor pieces returned to inventory")
	var house:Node=load("res://scripts/interior_world.gd").new();state.current_interior=house._grandfather_house_id();house.free();state.interior_position=Vector2(480,540)
	change_scene_to_file("res://scenes/interior.tscn");await settle();current_scene.hud.hide();current_scene.player.set_physics_process(false)
	var rug_nodes:=0
	for node:Node2D in current_scene.furniture_visuals:
		if node.get_meta("ground_surface",false):rug_nodes+=1;check(node.position==Vector2.ZERO,"rug sorts below characters while above room floor")
	check(rug_nodes==1,"one actual home rug visual")
	await capture("furniture-v8-home")
	check(state.money==economy.money and state.stamina==economy.stamina and state.inventory==economy.inventory and state.plots==economy.plots,"art and placement preserve economy and crops")
	print("FURNITURE_V8: %d passed, %d failed"%[passed,failed])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
