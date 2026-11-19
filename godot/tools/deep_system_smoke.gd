extends SceneTree
var passed:=0
var failed:=0
var state:Node
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func settle()->void:
	for i in range(5):await process_frame
func writer_started(coordinator:Node)->bool:
	for i in range(60):
		if coordinator.thread!=null:return true
		await create_timer(.01).timeout
	return false
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	state=root.get_node("GameState");state.set_process(false);state.flags.introDone=true;state.current_interior=""
	var rig:Script=load("res://scripts/player_rig.gd");var motion:RefCounted=rig.new();motion.face(Vector2.RIGHT)
	motion.sample(Vector2(60,0),.001)
	check(float(motion.stride_phase)<=.002201,"distance phase respects the 2.2-cycle-per-second ceiling")
	motion.sample(Vector2(12,0),.1);motion.face(Vector2.LEFT)
	motion.advance(.024);check(motion.presentation_direction(Vector2.DOWN)==Vector2.RIGHT,"turn first gathers weight in the previous view")
	motion.advance(.027);check(motion.presentation_direction(Vector2.DOWN)==Vector2.LEFT,"four-view texture switches after gathering weight")
	check(float(motion.snapshot().turn_weight)<.7,"stride amplitude is reduced at the direction switch")
	motion.advance(.06);check(not motion.snapshot().turning,"turn recovers in a bounded time")
	var bounded:=true;var finite:=true
	for i in range(120):
		motion.sample(Vector2(195.0/60,0),1.0/60);motion.advance(1.0/60)
		for correction:Vector2 in motion.support_offsets:bounded=bounded and correction.length()<=1.801
		var frame:Dictionary=rig.solve(state.appearance,{},"field","left","walk",i/60.0,-1,motion.snapshot())
		for row:Dictionary in frame.commands:
			if row.get("limb","")!="leg":continue
			var joints:PackedVector2Array=row.joints;finite=finite and joints[0].distance_to(joints[2])<=12.301
	check(bounded and finite,"short support releases before leg reach can stretch")
	motion.sample(Vector2(65,0),.016)
	check(is_zero_approx(motion.stride_phase) and motion.support_offsets==[Vector2.ZERO,Vector2.ZERO],"teleport clears phase and world support anchors")
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var world:Node=current_scene;world.set_process(false);world.player.set_physics_process(false);state.ui_open=false
	state.autosave_coordinator.barrier(true);state._autosave_timer.stop();state._movement_autosave_timer.stop()
	var layout_count:int=world.layout_refresh_count
	state.inventory.cabbageSeed=int(state.inventory.get("cabbageSeed",0))+1;state.money+=1;state.changed.emit();await settle()
	check(int(world.layout_refresh_count)==layout_count,"inventory and money changes do not rebuild scene collisions")
	state.plots[0].fertility=clampf(float(state.plots[0].fertility)-1,0,100);state.changed.emit();await settle()
	check(int(world.layout_refresh_count)==layout_count,"crop-domain refresh leaves furniture collisions intact")
	var dirty:Array=state.get_meta("farm_dirty_indices",[])
	check(dirty.has(0) and dirty.has(1) and dirty.size()<=3,"one plot change invalidates only its row neighbors")
	var old_decor:Array=state.legacy_systems.get("layouts",[]).duplicate(true)
	state.legacy_systems.layouts=[{"id":"bench","slot":0}];state.changed.emit();await settle()
	check(world.legacy_furniture_nodes.has(0),"legacy furniture placement still creates its live visual")
	state.legacy_systems.layouts=old_decor;state.changed.emit();await settle()
	check(int(world.layout_refresh_count)==layout_count,"legacy furniture visuals do not rebuild modern collisions")
	var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(state);var first:String=nav.scope_stamp
	state.building.revision=int(state.building.revision)+1;state.changed.emit();await settle();nav.refresh(state)
	check(nav.scope_stamp!=first and int(world.layout_refresh_count)>layout_count,"layout revision refreshes navigation and scene collisions")
	var geometry_scope:String=nav.scope_stamp
	state.collection["reviewStamp"]=1;state.changed.emit();nav.refresh(state)
	check(nav.scope_stamp==geometry_scope,"collection metadata changes cannot discard layout navigation grids")
	state.collection.erase("reviewStamp");state.changed.emit()
	var old_land:Dictionary=state.building.get("land",{}).duplicate(true)
	state.building.land={"orchard":not bool(old_land.get("orchard",false))};nav.refresh(state)
	check(nav.scope_stamp!=geometry_scope,"land unlocks invalidate geometry even without a furniture revision change")
	state.building.land=old_land;nav.refresh(state)
	state._autosave_timer.stop();var coordinator:Node=state.autosave_coordinator;coordinator.barrier(true)
	var started:int=coordinator.metrics.started
	for i in range(20):state.request_autosave()
	await create_timer(.15).timeout;coordinator.barrier()
	check(int(coordinator.metrics.started)==started+1 and int(coordinator.metrics.merged)>=19,"repeated pending autosaves coalesce into one immutable snapshot")
	state.request_autosave();check(await writer_started(coordinator),"manual-save race probe observes a started background writer")
	state.money=4321;check(state.save_game(state.SAVE_PATH,true),"manual save joins any active background writer")
	await create_timer(.12).timeout
	var repository:Script=load("res://scripts/save_repository.gd");var saved:Variant=repository.read(state.SAVE_PATH)
	check(saved is Dictionary and int(saved.money)==4321,"older background completion cannot overwrite the manual save")
	var load_snapshot:Dictionary=state._make_save_data().duplicate(true);load_snapshot.money=5432
	state.money=1234;state.request_autosave();check(await writer_started(coordinator),"load race probe observes a started old-generation writer")
	check(state.load_game_data(load_snapshot),"valid load cancels pending old-generation autosave")
	check(state.save_game(state.SAVE_PATH,true),"new generation can save synchronously")
	await create_timer(.15).timeout;saved=repository.read(state.SAVE_PATH)
	check(saved is Dictionary and int(saved.money)==5432,"loaded progress survives pending stale autosaves")
	var failure:Dictionary=coordinator._write("user://missing-parent-v11/save.json",state._make_save_data().duplicate(true),false)
	check(not failure.ok,"background writer reports filesystem failure without a success acknowledgement")
	coordinator.barrier(true);coordinator.use_threads=false;state._autosave_timer.stop()
	var completed:int=coordinator.metrics.completed;state.money=6543;state.request_autosave()
	await create_timer(.16).timeout;saved=repository.read(state.SAVE_PATH)
	check(int(coordinator.metrics.completed)>completed and saved is Dictionary and int(saved.money)==6543,"non-threaded web fallback commits a coalesced deferred save")
	coordinator.use_threads=true
	var historical:Dictionary=state._make_save_data().duplicate(true);historical.version=31
	var fish_catalog:Dictionary=state.system_catalog.fishing.species;var species:String=fish_catalog.keys()[0];var water:String=fish_catalog[species].waters[0]
	historical.fishing={"version":1,"mode":"relaxed","bait":"plain","release":false,"waters":{},"records":{},"last":null}
	historical.fishing.records[species]={"count":2,"best":20.0,"grade":1,"waters":[water]}
	check(state.load_game_data(historical) and int(state.fishing.version)==2 and int(state.fishing.records[species].count)==2,"historical fishing v1 imports without losing catch records")
	check(int(historical.fishing.version)==1,"legacy fishing normalization does not mutate its input")
	historical.fishing.records[species].grade=99
	check(not state.load_game_data(historical),"malformed historical fishing records still reject before state mutation")
	var lights:Script=load("res://scripts/scene_lighting.gd");lights.refresh(state)
	var identities:Dictionary={}
	for light:Dictionary in lights.sources:identities[light.id]=true
	check(identities.size()==lights.sources.size(),"shared lamp registry has unique stable source identities")
	check(is_equal_approx(lights.strength(1260,2)/lights.strength(1260,0),.32),"rear-facing lantern strength is shared by actor and furniture rules")
	var work:Script=load("res://scripts/resident_work_pose.gd");var station:Dictionary=state.system_catalog.interiors.layouts["home-chen"].rows[0]
	var context:Dictionary=work.describe(state,"chen",Vector2(float(station.x),float(station.y)+24),"home-chen",{"walking":false,"plan":{"key":"work"}})
	check(not context.is_empty() and context.kind=="build" and context.station!="","configured carpenter uses an authored physical interior workbench")
	check(work.describe(state,"chen",Vector2.ZERO,"",{"plan":{"key":"work"}}).is_empty(),"an outdoor schedule point cannot masquerade as a physical workbench")
	check(work.describe(state,"bao",Vector2.ZERO,"",{"plan":{"key":"work"}}).is_empty(),"unconfigured resident retains original behavior")
	var cache:Script=load("res://scripts/texture_cache.gd");var art:Script=load("res://scripts/character_art.gd")
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8);var texture:Texture2D=ImageTexture.create_from_image(image)
	art._textures["fixture-v11"]=texture;cache.touch(art._textures,"fixture-v11",texture);cache.trim(art._textures,0)
	check(art._textures.has("fixture-v11"),"active scene texture leases override the soft budget")
	var owner:Node=current_scene if current_scene!=null else root
	owner.get_meta("active_texture_lease",{}).erase("fixture-v11");texture=null;cache.trim(art._textures,0)
	check(not art._textures.has("fixture-v11"),"unreferenced texture entries can be reclaimed")
	coordinator.barrier(true)
	print("DEEP_SYSTEM: %d passed, %d failed; autosave_metrics="%[passed,failed],JSON.stringify(coordinator.metrics))
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
