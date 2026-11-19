extends RefCounted
class_name FishingSession
## Deterministic simulation only. Drawing, payment and rewards live elsewhere.
const PATTERNS={"smooth":[3.2,.65,.6,1.6],"mixed":[2.6,.7,1.0,1.6],"sinker":[2.8,.85,1.1,1.8],"floater":[3.4,.55,.8,1.6],"hop":[1.9,.55,.7,1.2],"dart":[2.6,.8,1.1,2.0]}
var game:Dictionary={}
var accumulator:float=0.0
const STEP:float=1.0/120.0
func start(plan:Dictionary,point:Dictionary)->void:
	accumulator=0.0
	game={"p":point.duplicate(true),"plan":plan.duplicate(true),"stage":"charge","phaseTime":0.0,"time":0.0,"charge":0.0,"chargeTime":0.0,"chargeArmed":false,"inputDown":false,"holding":false,"launched":false,"landed":false,"paid":false,"hooked":false,"missed":false,"caught":false,"safe":0.0,"total":0.0,"progress":0.0,"fishPos":.5,"barPos":.5,"barSize":.3,"velocity":0.0,"tension":35.0,"stamina":100.0,"distance":1.0,"highTime":0.0,"lowTime":0.0,"bufferUntil":-1.0,"fishPhase":"cruise","fishPhaseTime":0.0,"warn":false,"danger":false,"reason":"","hint":"","eventSerial":0,"events":[]}
	_preview();_event("prepare")
func phase()->String:
	return "" if game.is_empty() else str({"charge":"蓄力抛竿","cast":"抛竿","wait":"观察浮漂","bite":"咬钩提竿","fight":"收放线","caught":"抄鱼","miss":"收竿"}.get(str(game.stage),""))
func _event(kind:String)->void:
	game.eventSerial+=1;game.events.append({"serial":game.eventSerial,"kind":kind,"at":game.time})
	while game.events.size()>8:game.events.pop_front()
func transition(stage:String)->void:
	game.stage=stage;game.phaseTime=0.0;_event(stage)
func _preview()->void:
	var depth:int=int(game.plan.get("depth",1))
	if float(game.chargeTime)>.18:depth=clampi(int(float(game.charge)*3),0,2)
	game.previewDepth=depth
	var choices:Array=game.p.get("landings",[])
	game.landing=choices[depth].duplicate(true) if choices.size()>depth else {"x":float(game.p.get("waterX",0)),"y":float(game.p.get("waterY",0))}
func command(kind:String)->void:
	if game.is_empty() or game.stage in ["caught","miss"]:return
	if kind=="clear":
		game.holding=false;game.inputDown=false;game.chargeArmed=false;game.bufferUntil=-1.0
		if game.stage=="charge":game.charge=0.0;game.chargeTime=0.0;_preview()
		return
	if kind=="cancel":_miss("主动收竿","想继续时可以再抛一竿；落水前不消耗饵料。" );return
	var toggle_style:bool=str(game.plan.get("inputStyle","hold"))=="toggle"
	if kind=="release":
		game.inputDown=false
		if not toggle_style:
			game.holding=false
			if game.stage=="charge" and bool(game.chargeArmed):launch()
		return
	if kind not in ["press","toggle"]:return
	if kind=="press":
		if bool(game.inputDown):return
		game.inputDown=true
	if game.stage=="charge":
		if (toggle_style or kind=="toggle") and bool(game.chargeArmed):launch()
		else:game.chargeArmed=true;game.holding=true
		return
	if game.stage=="bite":_hook();return
	if game.stage=="wait":
		if float(game.plan.wait)-float(game.phaseTime)<=.12:game.bufferUntil=float(game.time)+.12
		return
	if game.stage=="fight":game.holding=not bool(game.holding) if toggle_style or kind=="toggle" else true
func toggle()->void:command("toggle")
func launch()->void:
	if game.is_empty() or game.stage!="charge":return
	_preview();game.plan.depth=int(game.previewDepth);game.holding=false;game.chargeArmed=false;game.launched=true;transition("cast")
func _hook()->void:
	game.hooked=true;game.holding=true;game.bufferUntil=-1.0;transition("fight")
func _miss(reason:String,hint:String)->void:
	game.missed=true;game.holding=false;game.reason=reason;game.hint=hint;transition("miss")
func tick(delta:float,paused:bool=false)->void:
	if game.is_empty():return
	if paused:command("clear");accumulator=0.0;return
	if not is_finite(delta) or delta<=0:return
	accumulator+=delta
	while accumulator+0.000000001>=STEP:
		accumulator=maxf(0.0,accumulator-STEP)
		if game.stage in ["caught","miss"]:accumulator=0.0;break
		_step(STEP)
func _step(dt:float)->void:
	game.time+=dt;game.phaseTime+=dt
	match str(game.stage):
		"charge":
			if bool(game.holding):game.chargeTime+=dt;game.charge=minf(1.0,float(game.chargeTime)/1.2);_preview()
			if float(game.phaseTime)>=15.0:_miss("暂未抛竿","准备好后再按住蓄力、松开抛竿；这一竿没有落水。")
		"cast":
			if float(game.phaseTime)>=.55:game.landed=true;transition("wait")
		"wait":
			game.nibble=float(game.plan.wait)-float(game.phaseTime)<=.35
			if float(game.phaseTime)>=float(game.plan.wait):
				transition("bite")
				if float(game.bufferUntil)>=float(game.time):_hook()
		"bite":
			if str(game.plan.mode)=="relaxed" and float(game.phaseTime)>=.25:_hook()
			elif float(game.phaseTime)>1.5+(.35 if game.plan.get("tackles",[]).has("steadyFloat") else 0.0):_miss("错过提竿窗口","等浮漂明确下沉并听到咬钩声，再按一下提竿。")
		"fight":_fight(dt)
func _fight(dt:float)->void:
	var d:float=clampf(float(game.plan.get("difficulty",20))/80.0,0,1)
	var relaxed:bool=str(game.plan.mode)=="relaxed";var tutorial:bool=bool(game.plan.get("tutorial",false))
	var tackle:Array=game.plan.get("tackles",[])
	var pattern:Array=PATTERNS.get(str(game.plan.get("movement","smooth")),PATTERNS.smooth)
	var cycle:float=0.0
	for length:float in pattern:cycle+=length
	var phase_time:float=fmod(float(game.phaseTime)*clampf(float(game.plan.get("speed",1)),.7,1.4)+float(int(game.plan.get("seed",1))%97)/200.0,cycle)
	var phase_index:int=0
	while phase_index<3 and phase_time>float(pattern[phase_index]):phase_time-=float(pattern[phase_index]);phase_index+=1
	var fish_phase:String=["cruise","charge","surge","recover"][phase_index]
	if str(game.fishPhase)!=fish_phase:game.fishPhase=fish_phase;_event("fish_"+fish_phase)
	game.fishPhaseTime=phase_time;game.warn=fish_phase in ["charge","surge"]
	var pull:float=[3.0+5*d,10.0+8*d,16.0+14*d,-1.0][phase_index]
	if relaxed:pull*=.65
	if tackle.has("steadyFloat"):pull*=.9
	var rate:float=(15.0+pull)*(1.0-.03*clampi(int(game.plan.get("skill",0)),0,4)) if bool(game.holding) else -24.0+pull*.35
	game.tension=clampf(float(game.tension)+rate*dt,0,100)
	if tutorial:game.tension=clampf(float(game.tension),12,96)
	var fatigue:float=1.0-float(game.stamina)/100.0
	var efficiency:float=1.0+.08*clampi(int(game.plan.get("rod",0)),0,2)
	if bool(game.holding):
		var safe_line:bool=float(game.tension)>=12 and float(game.tension)<=90
		if safe_line:
			game.stamina=maxf(0,float(game.stamina)-14.0*(1.0-.3*d)*efficiency*dt)
			game.distance=maxf(0,float(game.distance)-.11*(1.0-.28*d)*efficiency*(1+.3*fatigue)*dt)
	else:
		var escape:float=(.03+.045*d) if fish_phase=="surge" else .008
		if tackle.has("gentleSinker"):escape*=.8
		game.distance=minf(1,float(game.distance)+escape*(1-.5*fatigue)*dt)
	game.total+=dt
	if float(game.tension)>=20 and float(game.tension)<=80:game.safe+=dt
	var danger:bool=float(game.tension)>=85
	if danger and not bool(game.danger):_event("danger")
	game.danger=danger
	game.highTime=float(game.highTime)+dt if float(game.tension)>=100 else 0.0
	game.lowTime=float(game.lowTime)+dt if float(game.tension)<=8 else 0.0
	game.progress=clampf((1-float(game.distance))*.7+(1-float(game.stamina)/100.0)*.3,0,1)
	game.fishPos=.5+sin(float(game.phaseTime)*1.7)*.2
	if float(game.highTime)>=.35:_miss("鱼线张力过高","突进前先松开卸力；张力回落后再收线。")
	elif float(game.lowTime)>=(1.8 if tackle.has("gentleSinker") else 1.2):_miss("鱼线松弛太久","张力偏低时短暂收线，避免一直松手。")
	elif float(game.distance)<=.08 and float(game.stamina)<=20:game.caught=true;game.progress=1.0;game.holding=false;transition("caught")
	elif float(game.phaseTime)>=45:_miss("鱼游远了","尽量在游动与恢复阶段收线，突进时及时松开。")
func snapshot()->Dictionary:return game.duplicate(true)
func cancel()->void:game={};accumulator=0.0
