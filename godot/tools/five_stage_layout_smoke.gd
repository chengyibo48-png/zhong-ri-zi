extends SceneTree
var passed:=0
var failed:=0
const LAYOUT:=preload("res://scripts/world_layout.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func rectangle(row:Array)->Rect2:return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		printerr("Five-stage checks require isolated TEMP and APPDATA");quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false);state.flags.introDone=true
	var world:Dictionary=load("res://scripts/save_json.gd").decode(JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json")));var original:Dictionary=world.duplicate(true)
	var plan:Dictionary=LAYOUT.plan();var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(state)
	check(state.world_village.allProps.size()==world.village.allProps.size(),"no scenery added or removed")
	check(state.world_village.houses==world.village.houses and state.world_village.maps==world.village.maps and state.world_village.corridors==world.village.corridors,"all buildings, roads, bridges and water retained")
	var changed_solids:=0
	for i in world.village.solids.size():
		var source:Rect2=rectangle(world.village.solids[i]);var current:Rect2=rectangle(state.world_village.solids[i])
		check(current==LAYOUT.collision(source),"navigation collider follows central layout "+str(i))
		if source!=current:changed_solids+=1
	for change:Dictionary in plan.compositionV8.changes:
		var index:=int(str(change.key).get_slice(":",1));var source:Dictionary=world.village.allProps[index];var current:=LAYOUT.prop(source,index,"village")
		check(current.kind in ["tree","willow","shrub","flowers","stone"],"environmental scenery eligibility")
		check(Vector2(current.x,current.y)==Vector2(change.after[0],change.after[1]),"display follows central identity "+str(index))
		check(source.kind==current.kind and source.get("seed")==current.get("seed"),"species and source identity retained")
		if bool(change.solid):
			var matching:=false
			for row:Dictionary in plan.collisionOverrides:
				if str(row.reason).begins_with("v8 environmental tree "+str(index)+";"):matching=true;check(rectangle(row.source).size==rectangle(row.rect).size,"original trunk footprint")
			check(matching,"shifted tree has matching collider")
	for row:Dictionary in plan.collisionOverrides:
		if not str(row.reason).begins_with("v8 environmental tree"):continue
		var bounds:=rectangle(row.rect).grow(5);var found:=false
		for y in range(int(bounds.position.y),int(bounds.end.y)):
			for x in range(int(bounds.position.x),int(bounds.end.x)):
				var at:=Vector2(x,y)
				if not LAYOUT.newly_blocked(at):continue
				var actor:=Node2D.new();root.add_child(actor);actor.global_position=at
				LAYOUT.restore_safe_actor(state,actor)
				check(actor.global_position!=at and actor.global_position.distance_to(at)<50,"old save moved to nearby safe landing only for new overlap")
				check(not nav.blocked(state,"",actor.global_position.x,actor.global_position.y),"restored landing is walkable")
				actor.free();found=true;break
			if found:break
		check(found,"new-overlap regression sample")
	var actor:=Node2D.new();root.add_child(actor);actor.position=Vector2(2800,2100);var before:=actor.position
	LAYOUT.restore_safe_actor(state,actor);check(actor.position==before,"normal saved position retained")
	for zone:Dictionary in plan.groundZones:
		if not bool(zone.get("ellipse",false)):continue
		var cell:=Vector2i(Vector2(zone.rect[0],zone.rect[1])/32)
		for column in [6,7,8,9]:check(LAYOUT.ground_column(cell,column)==column,"new planting transitions exclude roads, bridges and water")
	check(world==original,"logical source stays immutable")
	print("LAYOUT_V8: %d passed, %d failed; changes=%d collider_changes=%d"%[passed,failed,plan.compositionV8.changes.size(),changed_solids])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
