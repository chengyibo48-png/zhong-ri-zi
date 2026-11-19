extends SceneTree
var s:Node
var passed:=0
var failed:=0
const N=preload("res://scripts/ranch_nurture.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func run()->void:
	s=root.get_node("GameState");s.set_process(false);s.ui_open=false
	N.ensure(s);var snapshot:Dictionary=s._make_save_data().duplicate(true)
	check(int(snapshot.version)==35,"new snapshots use v35")
	snapshot.version=34
	check(s.load_game_data(snapshot),"v34 migrates with quest and fishing progress "+s.message)
	check(s.ranch.has("families") and s.ranch.has("petRecords"),"migration initializes family and pet identities")
	s.pet_state.name="旧伙伴";s.pet_state.bond=63;s.ranch.pet.training=40
	var kind:String=str(s.pet_state.type);var other:String="dog" if kind=="cat" else "cat"
	check(N.pet_exchange(s,other),"formal adoption switches active household")
	check(s.pet_state.bond==0 and s.ranch.pet.training==0,"new pet never inherits former bond or training")
	check(N.pet_exchange(s,kind) and s.pet_state.name=="旧伙伴" and s.pet_state.bond==63 and s.ranch.pet.training==40,"return restores same companion identity")
	check(not N.pet_exchange(s,kind),"repeated adoption is idempotent")
	s.animals.clear();s.ranch.births=[];s.ranch.families={}
	for barn:String in s.ranch.barns:s.ranch.barns[barn].built=true;s.ranch.barns[barn].space=3;s.ranch.barns[barn].clean=100;s.ranch.barns[barn].comfort=2
	var mother:Dictionary=s._ranch_new_animal("cow","female","local",30)
	var father:Dictionary=s._ranch_new_animal("cow","male","local",30)
	var child:Dictionary=s._ranch_new_animal("cow","female","local",30,[mother.id,father.id])
	var grand:Dictionary=s._ranch_new_animal("cow","male","local",30,[child.id])
	check(N.related(s,str(mother.id),str(grand.id)),"grandparent pairing is rejected")
	s.animals.erase(child);s.animals.erase(grand)
	check(N.related(s,str(mother.id),str(grand.id)),"family history survives removal from active roster")
	s.ranch.births=[{"id":"test-birth","type":"cow","mother":mother.id,"father":father.id,"breed":"local","remaining":1,"total":8}]
	s.ranch.barns.cattle.clean=0;var before:int=s.animals.size()
	N.advance_births(s,0,false);N.advance_births(s,1,false)
	check(s.animals.size()==before and s.ranch.births[0].pausedDays==2,"bad environment pauses with explicit reason")
	N.advance_births(s,2,false)
	check(s.animals.size()==before+1 and s.ranch.births.is_empty(),"third paused settlement enters free protective nursery")
	N.advance_births(s,2,false)
	check(s.animals.size()==before+1 and s.ranch.birthHistory.size()==1,"birth creates exactly one animal and receipt")
	check(mother.rest and mother.postpartumUntil==s.day+2,"mother receives two day recovery")
	var baby:Dictionary=s.animals.back();check(baby.parents==[mother.id,father.id] and baby.age==0 and baby.generation==1,"newborn identity and ancestry preserved")
	var saved:Dictionary=s._make_save_data().duplicate(true)
	check(s.load_game_data(saved),"v35 family and pet state round trip "+s.message)
	print("RANCH_NURTURE: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
