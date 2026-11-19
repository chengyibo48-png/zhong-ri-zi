extends RefCounted
## Runtime intent lives here; the renderer never pays, advances time or rewards.
const GEOMETRY=preload("res://scripts/house_geometry.gd")
var active:Dictionary={}
var serial:int=0
var epoch:int=0
var write_save:Callable
func _init(writer:Callable=Callable())->void:write_save=writer
func reset()->void:active.clear();epoch+=1
func describe(s:Node,p:Dictionary)->Dictionary:
	var room:String=str(p.get("house",s.current_interior));var c:Dictionary=GEOMETRY.profile(room)
	if c.is_empty():return {"ready":false,"reason":"这间屋子的活动尚未准备好。"}
	var kind:String=str(p.get("activity","theme"));var owner:String=str(c.owner) if kind=="theme" else ""
	var minutes:int=10 if owner!="" else 5
	var reason:String=""
	var live:Dictionary=GEOMETRY.resolve(room,str(p.get("id","")))
	if s.current_interior!=room or live.is_empty():reason="物件已不在当前房间，请重新走近。"
	elif s.player_navigation_position().get("x")==null:reason="请先走到物件旁。"
	elif Vector2(float(live.x),float(live.y)).distance_to(s.interior_position)>56:reason="请先走到物件旁。"
	elif s.minutes+minutes>1320:reason="今晚先歇一歇，明天还能继续。"
	elif owner!="" and (not s.interior_npc_positions.has(owner) or Vector2(s.interior_npc_positions[owner]).distance_to(Vector2(float(live.x),float(live.y)))>112):reason="等"+s.npc_name(owner)+"回到工作角再一起做；现在可以自由看看。"
	if reason=="":
		for other:String in s.interior_npc_positions:
			if other!=owner and Vector2(s.interior_npc_positions[other]).distance_to(Vector2(float(live.x),float(live.y)))<18:reason="有人正在使用这个位置，稍等一会儿。";break
	var h:Dictionary=s.interior_state.get("household",{})
	return {"ready":reason=="","reason":reason,"name":str(p.get("name",c.title)),"owner":owner,"minutes":minutes,"kind":kind,"room":room,"first":not h.get("receipts",{}).has(room+":"+kind),"memorial":str(c.memorial) if kind=="theme" else "坐下来的一刻" if kind=="seat" else "翻过的生活记录","steps":c.steps if kind=="theme" else [{"kind":"choice","label":"选一个舒服的方式","options":["慢慢坐一会儿" if kind=="seat" else "翻开旧记录","先留意屋里的声音" if kind=="seat" else "整理一页书签"]},{"kind":"record","label":"让手边的小物安稳归位","options":["依原来的顺序收好","对照标记后归位"]},{"kind":"choice","label":"收好这一刻","options":["放回原处","留一张小记号"]}]}
func start(s:Node,p:Dictionary)->Dictionary:
	if s.action_busy() or not active.is_empty():return {"ready":false,"reason":"先做完手边的事。"}
	var view:=describe(s,p)
	if not view.ready:return view
	serial+=1;active={"token":serial,"epoch":epoch,"day":s.day,"room":s.current_interior,"point":p.duplicate(true),"step":0,"choices":[],"view":view,"running":false}
	return snapshot()
func snapshot()->Dictionary:
	return active.duplicate(true)
func input(s:Node,token:int,value:Variant)->bool:
	if active.is_empty() or int(active.token)!=token or bool(active.running) or active.epoch!=epoch or int(active.step)>=3:return false
	if s.day!=int(active.day) or not describe(s,active.point).ready:return false
	var step:Dictionary=active.view.steps[int(active.step)]
	if str(step.kind)=="align":
		if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value)-float(step.target))>float(step.tolerance):return false
		active.choices.append(0 if float(value)<.5 else 1)
	else:
		if not value is int or value not in [0,1]:return false
		if step.has("expected") and value!=int(step.expected):s.message="再观察一下："+str(step.get("hint",""));return false
		active.choices.append(value)
	active.step+=1
	return true
func finish(s:Node,token:int)->bool:
	if active.is_empty() or int(active.token)!=token or int(active.step)!=3 or bool(active.running):return false
	if s.day!=int(active.day) or not describe(s,active.point).ready:return false
	active.running=true
	var point:Dictionary=active.point.duplicate(true);point._contact_aligned=true
	point.x=float(point.get("contactX",point.x));point.y=float(point.get("contactY",float(point.y)-24))
	point.kind="house-activity"
	var kind:String="rest" if active.view.kind=="seat" else "build" if str(active.view.owner) in ["chen","wu","xiaohe","luSenior","bao"] else "read"
	var spec:Dictionary=s.ACTION_RULES.spec(kind,str(active.view.name));spec.duration=1.5;spec.houseContact={"x":point.x,"y":point.y}
	var generation:int=epoch
	if not s.begin_action(spec,point,_commit.bind(s,token,generation),_cancel_animation.bind(token)):
		active.running=false;return false
	return true
func _cancel_animation(token:int)->void:
	if not active.is_empty() and int(active.token)==token:active.clear()
func cancel(token:int=-1)->void:
	if active.is_empty() or token>=0 and int(active.token)!=token:return
	if not bool(active.running):active.clear()
func _commit(s:Node,token:int,generation:int)->void:
	if s.transactions!=null and not s.transactions.preparing:
		s.transactions.submit("house:_commit",__commit_mutate.bind(s,token,generation));return
	__commit_mutate(s,token,generation)
func __commit_mutate(s:Node,token:int,generation:int)->void:
	if active.is_empty() or active.token!=token or generation!=epoch:return
	var view:Dictionary=describe(s,active.point)
	if not view.ready or int(active.day)!=s.day:active.clear();s.message="条件变了，这次先收好，没有消耗。";return
	var old:Dictionary=s.interior_state.duplicate(true);var old_time:float=s.minutes
	var owner:String=str(view.owner);var old_relation:Dictionary=s.relations.get(owner,{}).duplicate(true)
	var h:Dictionary=s.interior_state.get("household",preload("res://scripts/house_save.gd").defaults()).duplicate(true)
	var key:String=str(active.room)+":"+str(view.kind);var first:bool=not h.receipts.has(key)
	if first:
		h.receipts[key]={"room":str(active.room),"kind":str(view.kind),"day":s.day,"serial":int(h.nextReceipt),"choices":active.choices.duplicate()};h.nextReceipt+=1
	else:h.receipts[key].choices=active.choices.duplicate()
	var relation:bool=owner!="" and not bool(h.relationClaims.get(owner,false))
	if relation:
		h.relationClaims[owner]=true;s.relations[owner].points=mini(100,int(s.relations[owner].points)+1)
	s.interior_state.household=h;s.minutes+=int(view.minutes)
	if owner!="" and str(view.kind)=="theme":s.quest_event("houseCooperation","house-coop:"+owner);s.quest_event("neighborWork","house-neighbor:"+owner)
	# The existing writer serializes with background requests and preserves backups.
	if not (bool(write_save.call(s)) if write_save.is_valid() else s.save_game(s.SAVE_PATH,true)):
		s.interior_state=old;s.minutes=old_time
		if owner!="":s.relations[owner]=old_relation
		active.clear();s.message="这次记录没有保存成功，时间和回报都未结算。";return
	active.clear();s.message=("留下了"+str(view.memorial) if first else "又一起度过一小段安静时光")+(" · 关系 +1" if relation else "")+" · %d 分钟"%int(view.minutes)
	s.domain_changed.emit("household")
	if relation:s.domain_changed.emit("relations")
	s.clock_changed.emit();s.changed.emit()

var fixture_serial:int=0
var pending_fixture:int=0
func fixture_state(s:Node,id:String)->bool:
	return preload("res://scripts/house_life.gd").state(s,s.current_interior,id)
func toggle_fixture(s:Node,p:Dictionary)->bool:
	if s.action_busy() or not active.is_empty():return false
	var view:Dictionary=preload("res://scripts/house_life.gd").condition(s,p)
	if not view.ready:s.message=str(view.reason);return false
	if str(view.fixture.type)=="preset":return false
	fixture_serial+=1;pending_fixture=fixture_serial
	var point:Dictionary=p.duplicate(true);point.x=p.contactX;point.y=p.contactY;point._contact_aligned=true
	var spec:Dictionary=s.ACTION_RULES.spec("read",str(p.name));spec.duration=.55;spec.houseContact={"x":point.x,"y":point.y}
	var expected:bool=fixture_state(s,str(p.id));var room:String=s.current_interior
	if not s.begin_action(spec,point,_commit_fixture.bind(s,p.duplicate(true),pending_fixture,epoch,room,expected),func():pending_fixture=0):pending_fixture=0;return false
	return true
func _commit_fixture(s:Node,p:Dictionary,token:int,generation:int,room:String,expected:bool)->void:
	if s.transactions!=null and not s.transactions.preparing:
		s.transactions.submit("house:_commit_fixture",__commit_fixture_mutate.bind(s,p,token,generation,room,expected));return
	__commit_fixture_mutate(s,p,token,generation,room,expected)
func __commit_fixture_mutate(s:Node,p:Dictionary,token:int,generation:int,room:String,expected:bool)->void:
	if pending_fixture!=token or generation!=epoch:return
	pending_fixture=0
	var check:Dictionary=preload("res://scripts/house_life.gd").condition(s,p)
	if not check.ready or room!=s.current_interior or fixture_state(s,str(p.id))!=expected:return
	var old:Dictionary=s.interior_state.duplicate(true)
	var h:Dictionary=s.interior_state.household.duplicate(true)
	if not h.has("fixtureStates"):h.fixtureStates={}
	h.fixtureStates[str(p.id)]=not expected;s.interior_state.household=h
	if not (bool(write_save.call(s)) if write_save.is_valid() else s.save_game(s.SAVE_PATH,true)):
		s.interior_state=old;s.message="没有保存成功，物件保持原样。";return
	s.message=("已经收好" if expected else "轻轻打开")+" · "+str(p.name)
	s.sound_requested.emit("soft");s.domain_changed.emit("household");s.changed.emit()
func set_home_preset(s:Node,on:bool)->bool:
	if s.transactions!=null and not s.transactions.preparing:return s.transactions.submit("house:set_home_preset",_set_home_preset_mutate.bind(s,on))
	return _set_home_preset_mutate(s,on)
func _set_home_preset_mutate(s:Node,on:bool)->bool:
	if s.current_interior!="building-farm-12" or s.action_busy() or not active.is_empty():return false
	var old:Dictionary=s.interior_state.duplicate(true);s.interior_state.household=s.interior_state.household.duplicate(true);s.interior_state.household.homePreset=on
	if not (bool(write_save.call(s)) if write_save.is_valid() else s.save_game(s.SAVE_PATH,true)):
		s.interior_state=old;s.message="补充布置没有保存成功，原样保留。";return false
	s.remove_meta("house_life_rows")
	s.domain_changed.emit("household");s.changed.emit();return true
