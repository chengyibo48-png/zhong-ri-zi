extends SceneTree
const SAVE_JSON = preload("res://scripts/save_json.gd")
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("FAIL "+label)
func layer_index(map: Control,id: String) -> int:
	for i in range(map.type_option.item_count):
		if str(map.type_option.get_item_metadata(i))==id:return i
	return -1
func _run() -> void:
	var state=root.get_node("GameState")
	state.set_process(false)
	var file:=FileAccess.open(OS.get_environment("ATLAS_TARGETS_FIXTURE"),FileAccess.READ)
	if file==null:
		await root.get_node("AudioService").prepare_exit()
		quit(1)
		return
	var row:Dictionary=SAVE_JSON.decode(JSON.parse_string(file.get_line()))
	check(state.load_game_data(state.convert_external_save(row.before)),"full source state loaded")
	var world=load("res://scenes/main.tscn").instantiate()
	root.add_child(world);current_scene=world
	world.set_process(false);world.player.set_physics_process(false)
	await process_frame
	world.hud.show_map()
	var map=world.hud.map_panel
	check(map._selected_target().is_empty() and map.go_button.disabled,"first map opening does not select an unrelated destination")
	for layer in ["all","homes","neighbors","services","harvest","water","animals","resources","pins"]:
		var index:=layer_index(map,layer)
		check(index>=0,"source layer present "+layer)
		map.type_option.select(index)
		map.type_option.item_selected.emit(index)
		var expected:Array=state.atlas_targets().filter(func(t:Dictionary)->bool:return layer=="all" or str(t.type)==layer)
		check(map.targets.size()==expected.size(),"actual layer target count "+layer)
		check(map.targets.all(func(t:Dictionary)->bool:return layer=="all" or str(t.type)==layer),"actual layer contains only source category "+layer)
		var saved:Dictionary=state._read_save_json(ProjectSettings.globalize_path(state.SAVE_PATH))
		check(str(saved.atlas.layer)==layer,"actual layer selection persisted "+layer)
	var index:=layer_index(map,"harvest")
	map.type_option.item_selected.emit(index)
	map.selected_id="harvest-1";map.custom_target.clear();map.refresh()
	var ripe:Dictionary=map._selected_target()
	check(str(ripe.get("id",""))=="harvest-1" and not map.go_button.disabled,"ripe field selected and route available")
	map.track_button.pressed.emit()
	check(str(state.atlas.tracking.get("id",""))=="harvest-1","actual track button records source harvest identity")
	var stale:Dictionary=ripe.duplicate(true)
	state.plots[1].crop=""
	state.changed.emit()
	check(map._selected_target().is_empty() and map.go_button.disabled,"harvested field disappears and departure disabled")
	map.custom_target=stale
	map._refresh_detail()
	check(map._selected_target().is_empty() and map.track_button.disabled,"cached map selection resolves disappearance")
	check(state.atlas_resolve(state.atlas.tracking).is_empty(),"rendered tracking no longer resolves completed field")
	var loaded:Dictionary=state._make_save_data().duplicate(true)
	check(state.load_game_data(loaded),"native state with stale tracking reloads")
	check(state.atlas.tracking==null,"load clears finished source target")
	map.custom_target={"x":2831.125,"y":1652.75,"kind":"walk","name":"地图落点"}
	map.selected_id="";map._refresh_detail()
	check(not map._selected_target().is_empty() and not map.track_button.disabled,"id-less map point can be tracked")
	map.track_button.pressed.emit()
	check(state.atlas.tracking.get("id")==null,"free-point tracking preserves null identity")
	var saved:Dictionary=state._read_save_json(ProjectSettings.globalize_path(state.SAVE_PATH))
	check(saved.atlas.tracking.get("id")==null and float(saved.atlas.tracking.x)==2831.125 and float(saved.atlas.tracking.y)==1652.75,"actual free-point file retains exact position and null id")
	check(state.load_game(state.SAVE_PATH),"free-point save file loads")
	check(state.atlas.tracking.get("id")==null and not state.atlas_resolve(state.atlas.tracking).is_empty(),"id-less tracking remains valid after reload")
	map.custom_target.clear();map.selected_id=""
	map.close();map.open_panel()
	check(float(map._selected_target().get("x",0))==2831.125,"reopened map restores persisted source tracking selection")
	map.custom_target.clear();map.selected_id=""
	map.type_option.item_selected.emit(layer_index(map,"resources"))
	check(not map.targets.is_empty(),"ready discovered resources available")
	var resource:Dictionary=map.targets[0].duplicate(true)
	map.custom_target=resource;map.selected_id=str(resource.id);map._refresh_detail()
	var id:=str(resource.id).trim_prefix("resource-")
	state.forage.patches[id]={"lastDay":state.day,"readyDay":state.day+3,"pressure":0}
	state.changed.emit()
	check(map._selected_target().is_empty() and map.go_button.disabled,"regenerating resource removes cached map selection")
	map.custom_target.clear();map.type_option.item_selected.emit(layer_index(map,"pins"))
	map._map_point_selected(Vector2(2010,3715))
	check(str(map._selected_target().get("id",""))=="pin-2","actual map click respects layer and southern pin")
	map._map_point_selected(Vector2.ZERO)
	check(map._selected_target().get("id")==null and float(map._selected_target().x)==0.0 and float(map._selected_target().y)==0.0,"empty map click remains source literal coordinate")
	check(map.go_button.disabled,"blocked literal coordinate cannot depart")
	map._clear_target()
	check(state.atlas.tracking==null,"actual clear route removes tracking")
	check(map._selected_target().is_empty() and map.map_canvas.preview_target.is_empty(),"clear route also clears current selection and preview")
	world.hud.close_top_panel()
	state.stop_walking()
	current_scene=null;world.queue_free()
	await process_frame
	await root.get_node("AudioService").prepare_exit()
	print("Atlas actual UI, target lifecycle and persistence: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
