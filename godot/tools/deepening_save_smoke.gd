extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL ",label)
func run()->void:
	var scratch:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
	if scratch=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):quit(1);return
	var state:Node=root.get_node("GameState");state.set_process(false)
	var total:int=state.FARM_LAYOUT.TOTAL
	var baseline:Dictionary=state._make_save_data()
	for count in [24,72]:
		var old:=baseline.duplicate(true);old.plots=old.plots.slice(0,count)
		for i in count:
			old.plots[i].crop="cabbage";old.plots[i].growth=1.25+i*.01;old.plots[i].tilled=true;old.plots[i].fertility=71;old.plots[i].moisture=58;old.plots[i].repeats=3
		var original:=old.duplicate(true)
		check(state.load_game_data(old),"known old layout loads "+str(count))
		check(state.plots.size()==total,"current layout expands without reset")
		var intact:=true
		for i in count:
			for key:String in ["crop","growth","tilled","fertility","moisture","repeats"]:intact=intact and state.plots[i][key]==old.plots[i][key]
		check(intact,"all old indexed crops and soil fields retained "+str(count))
		var blank:=true
		for i in range(count,total):blank=blank and str(state.plots[i].crop)=="" and not bool(state.plots[i].tilled)
		check(blank,"only new plots start blank")
		check(old==original,"loading never mutates input object")
		check(state.money==int(baseline.money) and state.inventory==baseline.inventory,"economy preserved")
		check(state.save_game("user://v9-old-layout.json",true) and state.load_game("user://v9-old-layout.json"),"expanded layout survives disk roundtrip")
	check(state.load_game_data(baseline),"restore full current save")
	baseline=state._make_save_data().duplicate(true)
	for count in [0,1,23,25,48,71,73,total-1,total+1]:
		if count in [24,72,total]:continue
		var invalid:=baseline.duplicate(true);invalid.plots.resize(count)
		check(not state.load_game_data(invalid),"unknown or truncated plot count rejected "+str(count))
		check(state._make_save_data()==baseline,"failed read preserves complete state")
	var sparse:Dictionary={"version":1,"plots":baseline.plots.slice(0,24),"inventory":{}}
	check(state.load_game_data(sparse),"early save without fishing module loads")
	check(not state.fishing_plan(str(state.system_catalog.fishing.waters.keys()[0])).is_empty(),"default fishing remains usable")
	var old_maps:=baseline.duplicate(true);old_maps.fishing.waters=true;old_maps.fishing.records=1
	var retained:=old_maps.duplicate(true)
	check(state.load_game_data(old_maps) and state.fishing.waters is Dictionary and state.fishing.records is Dictionary,"primitive legacy fish maps get usable empty defaults")
	check(old_maps==retained,"legacy fish conversion is copy-only")
	print("DEEPENING_SAVE: %d passed, %d failed; current_plots=%d"%[passed,failed,total])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
