extends RefCounted
class_name FishingSession
var game: Dictionary = {}

func start(plan: Dictionary, point: Dictionary) -> void:
	game = {"p":point.duplicate(true),"plan":plan.duplicate(true),"stage":"charge","phaseTime":0.0,"time":0.0,"charge":0.0,"holding":false,"launched":false,"landed":false,"paid":false,"hooked":false,"missed":false,"caught":false,"safe":0.0,"total":0.0,"progress":0.3,"fishPos":0.5,"barPos":0.5,"velocity":0.0,"barSize":0.26,"tension":35.0,"warn":false,"reason":""}
	var equipment: Array = plan.get("tackles",[])
	game.barSize = minf(0.65,0.25+float(plan.get("skill",0))*0.025+(0.12 if str(plan.mode)=="relaxed" else 0.0)+(0.12 if equipment.has("steadyFloat") else 0.0))

func phase() -> String:
	if game.is_empty(): return ""
	return {"charge":"蓄力抛竿","cast":"抛竿","wait":"等漂","bite":"咬钩","fight":"追踪鱼影","caught":"抄鱼","miss":"收空竿"}.get(str(game.stage),"")

func transition(stage: String) -> void:
	game.stage=stage
	game.phaseTime=0.0

func command(kind: String) -> void:
	if game.is_empty(): return
	if kind=="clear": game.holding=false; return
	if kind=="cancel": game.missed=true;game.reason="主动收竿";transition("miss");return
	if kind=="release":
		if str(game.plan.get("inputStyle","hold"))=="hold": game.holding=false
		if game.stage=="charge" and str(game.plan.get("inputStyle","hold"))=="hold": launch()
		return
	if kind not in ["press","toggle"]: return
	if game.stage=="charge" and str(game.plan.get("inputStyle","hold"))=="toggle":
		if bool(game.holding):launch()
		else:game.holding=true
		return
	if game.stage=="bite": game.hooked=true;transition("fight")
	game.holding=not bool(game.holding) if kind=="toggle" or str(game.plan.get("inputStyle","hold"))=="toggle" else true

func toggle() -> void: command("toggle")

func launch() -> void:
	if game.stage!="charge":return
	game.launched=true
	if float(game.charge)>0.2: game.plan.depth=clampi(int(float(game.charge)*3),0,2)
	game.holding=false
	transition("cast")

func tick(delta: float, paused: bool=false) -> void:
	if game.is_empty():return
	if paused: game.holding=false;return
	var step := clampf(delta,0.0,0.1)
	game.time=float(game.time)+step
	game.phaseTime=float(game.phaseTime)+step
	if float(game.time)>45.0 and not bool(game.caught):
		game.missed=true;game.reason="鱼游远了";transition("miss");return
	match str(game.stage):
		"charge":
			if bool(game.holding): game.charge=minf(1.0,float(game.phaseTime)/1.2)
			if float(game.phaseTime)>=1.2: launch()
		"cast":
			if float(game.phaseTime)>=0.55: game.landed=true;transition("wait")
		"wait":
			if float(game.phaseTime)>=float(game.plan.wait): transition("bite")
		"bite":
			if str(game.plan.mode)=="relaxed" and float(game.phaseTime)>=0.25: game.hooked=true;transition("fight")
			elif float(game.phaseTime)>1.5: game.missed=true;game.reason="错过提竿窗口";transition("miss")
		"fight": _fight(step)

func _fight(step: float) -> void:
	var t := float(game.phaseTime)
	var difficulty := float(game.plan.get("difficulty",20))
	var relaxed := str(game.plan.mode)=="relaxed"
	var amplitude := (0.16+difficulty*0.002)*(0.68 if relaxed else 1.0)
	var speed := float(game.plan.get("speed",0.65+difficulty*0.012))
	var cycle:=maxf(2.0,float(game.plan.get("pause",3.0)))
	var surge:=fmod(t,cycle)>cycle-1.0
	var seed_phase := float(int(game.plan.get("seed",1))%628)/100.0
	var target := 0.5
	match str(game.plan.get("movement","smooth")):
		"smooth": target=0.5+sin(t*speed+seed_phase)*amplitude
		"mixed": target=0.5+sin(t*speed+seed_phase)*amplitude*0.7+sin(t*speed*2.3)*amplitude*0.25
		"sinker": target=0.34+sin(t*speed+seed_phase)*amplitude*0.7
		"floater": target=0.67+sin(t*speed+seed_phase)*amplitude*0.65
		"hop": target=0.5+sin(floor(t/maxf(.3,float(game.plan.get("pause",.77))))*1.7+seed_phase)*amplitude
		"dart": target=0.5+sin(t*speed+seed_phase)*amplitude*(0.35 if not surge else 1.15)
	game.warn=str(game.plan.get("movement",""))=="dart" and fmod(t,cycle)>cycle-1.0-float(game.plan.get("warning",.4)) and fmod(t,cycle)<cycle-.9
	game.fishPos=move_toward(float(game.fishPos),clampf(target,0.08,0.92),step*(0.18+difficulty*0.006))
	var force := 2.8 if bool(game.holding) else -2.8
	game.velocity=clampf((float(game.velocity)+force*step)*exp(-4.0*step),-0.65,0.65)
	game.barPos=clampf(float(game.barPos)+float(game.velocity)*step,float(game.barSize)*0.5,1.0-float(game.barSize)*0.5)
	if float(game.barPos)<=float(game.barSize)*0.5 or float(game.barPos)>=1.0-float(game.barSize)*0.5:game.velocity=float(game.velocity)*0.15
	var inside := absf(float(game.fishPos)-float(game.barPos))<=float(game.barSize)*0.5
	game.total=float(game.total)+step
	if inside: game.safe=float(game.safe)+step
	var loss := 0.055*(0.65 if game.plan.get("tackles",[]).has("gentleSinker") else 1.0)
	var gain := 0.075-difficulty*0.00035
	if inside:game.progress=minf(1.0,float(game.progress)+gain*step)
	elif not bool(game.plan.get("tutorial",false)):game.progress=maxf(0.0,float(game.progress)-loss*step)
	game.tension=(1.0-float(game.progress))*100.0
	if float(game.progress)>=1.0:game.caught=true;transition("caught")
	elif float(game.progress)<=0.0:game.missed=true;game.reason="鱼影离开控制范围太久";transition("miss")

func snapshot() -> Dictionary: return game.duplicate(true)
func cancel() -> void: game={}
