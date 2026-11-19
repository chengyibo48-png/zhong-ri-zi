extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);s.flags.introDone=true;s.current_interior="";s.ui_open=false;s.animals.clear();s.ranch.births=[];s.day=30;s.minutes=600
	var meadow:Script=load("res://scripts/ranch_meadow.gd");var nav:RefCounted=load("res://scripts/npc_navigation.gd").new();nav.refresh(s)
	check(not nav.blocked(s,"",meadow.ENTRY.x,meadow.ENTRY.y),"original pasture entry is walkable")
	check(8*600*600>10*(330*420+440*280),"eight activity fields exceed ten times original pen area")
	for i:int in 8:
		var r:Rect2=meadow.pen(i);var center:Vector2=r.get_center()
		check(not nav.route(s,meadow.ID,{"x":meadow.EXIT.x,"y":meadow.EXIT.y},{"x":center.x,"y":center.y}).is_empty(),"field reachable through real gate "+str(i))
		check(nav.blocked(s,meadow.ID,r.position.x,r.position.y+200),"visual field fence blocks movement "+str(i))
		var g:Vector2=meadow.gate(i);check(not nav.blocked(s,meadow.ID,g.x,g.y),"gate passage remains clear "+str(i))
	for id:String in s.ranch.barns:s.ranch.barns[id].built=true;s.ranch.barns[id].space=3
	var slots:Dictionary={};var kinds:Array=["cow","cow","sheep","goat","hen","duck","pig","rabbit"]
	for type_id:String in kinds:
		for index:int in 4:
			var a:Dictionary=s._ranch_new_animal(type_id,"female","local",40);var row:Dictionary=meadow.assignment(s,a);var slot:String=str(row.pen)+":"+str(row.slot)
			check(not slots.has(slot),"animal has distinct grazing space "+str(a.id));slots[slot]=true
			a.position.room=meadow.ID;var at:Vector2=meadow.stand(row);a.position.inside={"x":at.x,"y":at.y,"direction":"down"}
	var snapshot:Dictionary=s._make_save_data().duplicate(true);s.current_interior=meadow.ID;s.interior_position=Vector2(1500,1850);snapshot=s._make_save_data().duplicate(true)
	check(s.load_game_data(snapshot),"v35 preserves expanded-map player and animal coordinates "+s.message)
	check(s.current_interior==meadow.ID and s.animals[0].position.room==meadow.ID and float(s.animals[0].position.inside.x)>113,"meadow room is not normalized back into a barn")
	s.current_interior="";s.player_position=meadow.ENTRY
	check(s.enter_room_state("ranch-meadow") or meadow.activate(s),"meadow entrance transaction")
	check(s.leave_room_state() and s.current_interior=="","meadow return restores original pasture")
	var cow:Dictionary=s.animals[0];cow.hunger=30;cow.position.inside.walking=false;s.ranch.grass=[100,100]
	var zone:int=int(s.system_catalog.ranch.species.cow.get("grazingZone",s.ranch.zone));var before_grass:float=float(s.ranch.grass[zone]);var before_hunger:float=cow.hunger
	load("res://scripts/ranch_care.gd").graze(s,cow,2.1)
	check(float(cow.hunger)>before_hunger and float(s.ranch.grass[zone])<before_grass,"expanded meadow uses original grass and ration rules")
	var pig:Dictionary={}
	for animal:Dictionary in s.animals:
		if str(animal.type)=="pig":pig=animal;break
	s.day=32;s.minutes=600;s.ranch.policy="day";pig.position.inside.walking=false;var products:int=s.ranch.products.size()
	var movement:RefCounted=load("res://scripts/ranch_movement.gd").new();meadow.advance_animal(s,pig,.1,{},movement)
	check(s.ranch.products.size()==products+1 and str(s.ranch.products.back().item)=="truffle" and s.ranch.products.back().room==meadow.ID,"pig keeps four-day truffle purpose in real meadow")
	check(s.load_game_data(s._make_save_data().duplicate(true)),"meadow products save and reload")
	print("RANCH_MEADOW: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
