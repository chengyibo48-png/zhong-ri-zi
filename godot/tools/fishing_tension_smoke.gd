extends SceneTree
const SESSION=preload("res://scripts/fishing_session.gd")
var passed:=0
var failed:=0
var results:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+label)
func plan()->Dictionary:return {"id":1,"fish":"fish","mode":"standard","inputStyle":"hold","depth":1,"seed":731,"wait":.5,"difficulty":18,"speed":1.0,"movement":"smooth","rod":0,"skill":0,"tackles":[],"tutorial":false}
func point()->Dictionary:return {"id":"fixture","waterX":100.0,"waterY":100.0,"landings":[{"x":80,"y":100},{"x":100,"y":100},{"x":120,"y":100}]}
func fight(p:Dictionary,policy:String="correct",dt:float=1.0/60.0)->RefCounted:
	var session:RefCounted=SESSION.new();session.start(p,point());session.command("press");session.tick(.1);session.command("release")
	for i:int in ceili(65.0/dt):
		var g:Dictionary=session.game
		if g.stage in ["caught","miss"]:break
		if g.stage=="bite":session.command("press")
		if g.stage=="fight":
			if policy=="hold":
				if not bool(g.holding):session.command("press")
			elif policy=="release":session.command("release")
			else:
				var surge:bool=str(g.fishPhase) in ["charge","surge"]
				if bool(g.holding) and (float(g.tension)>=68 or surge and float(g.tension)>=50):session.command("release")
				elif not bool(g.holding) and (float(g.tension)<=24 or float(g.tension)<=35 and not surge):session.command("press")
		session.tick(dt)
	return session
func run()->void:
	var a:RefCounted=SESSION.new();a.start(plan(),point());a.command("press");a.tick(.1);a.command("release")
	check(a.game.stage=="cast" and int(a.game.plan.depth)==1,"short tap preserves selected landing")
	a.start(plan(),point());a.command("press")
	for i:int in 20:a.tick(.1)
	check(a.game.stage=="charge" and is_equal_approx(float(a.game.charge),1.0),"maximum charge waits for release")
	a.command("release");check(int(a.game.plan.depth)==2,"long hold lands at far preset")
	var toggle_plan:Dictionary=plan();toggle_plan.inputStyle="toggle";a.start(toggle_plan,point());a.command("press");a.command("press")
	check(a.game.stage=="charge","duplicate physical press ignored")
	a.command("release");a.command("press");check(a.game.stage=="cast","toggle casting requires two physical presses")
	a.start(plan(),point());a.command("press");a.tick(.1);var time:float=a.game.time;a.tick(.1,true)
	check(a.game.time==time and not bool(a.game.holding) and not bool(a.game.chargeArmed),"pause freezes clocks and clears held input")
	a.command("release");check(a.game.stage=="charge","release after pause cannot accidentally cast")
	a.start(plan(),point());a.launch()
	while a.game.stage=="cast":a.tick(1.0/120)
	while float(a.game.phaseTime)<.41:a.tick(1.0/120)
	a.command("press")
	for i:int in 16:a.tick(1.0/120)
	check(bool(a.game.hooked),"120 ms pre-bite input buffer")
	var held:RefCounted=fight(plan(),"hold");var loose:RefCounted=fight(plan(),"release")
	check(held.game.reason=="鱼线张力过高","constant reeling fails for real tension")
	check(loose.game.reason=="鱼线松弛太久","constant release fails for slack line")
	var controlled:RefCounted=fight(plan())
	check(bool(controlled.game.caught),"visible-state controller catches ordinary fish")
	var replay:RefCounted=fight(plan());check(controlled.snapshot()==replay.snapshot(),"seed and input replay are deterministic")
	var slow:RefCounted=fight(plan(),"correct",1.0/30)
	check(bool(slow.game.caught) and absf(float(slow.game.total)-float(controlled.game.total))<.6,"30 and 60 Hz stay within timing tolerance")
	a.start(plan(),point());a.transition("fight");a.game.tension=100;a.game.holding=true;a.tick(.1)
	check(not bool(a.game.missed),"critical high tension has rescue grace")
	a.command("release");a.tick(.1);check(float(a.game.highTime)==0,"unloading rescues high-tension grace")
	var state:Node=root.get_node("GameState");state.set_process(false)
	for id:String in state.system_catalog.fishing.species:
		var species:Dictionary=state.system_catalog.fishing.species[id]
		if not species.methods.has("rod"):continue
		for mode:String in ["standard","relaxed"]:
			for rod:int in 3:
				for equipment:int in 8:
					var tackle:Array=[]
					for slot:int in 3:
						if equipment&(1<<slot):tackle.append(["steadyFloat","gentleSinker","fishBell"][slot])
					if tackle.size()>rod:continue
					for skill:int in 5:
						var p:Dictionary=plan();p.merge({"fish":id,"difficulty":float(species.difficulty),"speed":float(species.get("speed",1)),"movement":str(species.movement),"mode":mode,"rod":rod,"skill":skill,"tackles":tackle},true)
						var session:RefCounted=fight(p)
						check(bool(session.game.caught),"controlled catch %s/%s/%d/%d/%d"%[id,mode,rod,equipment,skill])
						results.append({"fish":id,"mode":mode,"difficulty":species.difficulty,"rod":rod,"skill":skill,"equipment":equipment,"caught":session.game.caught,"seconds":session.game.total,"ratio":float(session.game.safe)/maxf(.001,float(session.game.total)),"reason":session.game.reason})
	for behavior:String in SESSION.PATTERNS:
		var p:Dictionary=plan();p.movement=behavior;p.difficulty=60;check(bool(fight(p).game.caught),"all six behavior profiles "+behavior)
	# Distinct input edges, equipment effects and critical-state escape windows.
	a.start(plan(),point());a.launch()
	while a.game.stage=="cast":a.tick(.01)
	a.command("press")
	for i:int in 220:a.tick(.01)
	check(a.game.stage=="miss" and not bool(a.game.hooked),"holding before bite cannot auto hook standard mode")
	a.start(plan(),point())
	for i:int in 151:a.tick(.1)
	check(a.game.stage=="miss" and not bool(a.game.landed),"15 second preparation timeout stays unpaid")
	var teaching:Dictionary=plan();teaching.tutorial=true
	var protected:RefCounted=fight(teaching,"release")
	check(not bool(protected.game.caught) and protected.game.reason=="鱼游远了","teaching protects critical tension but still needs actual reeling")
	var gentle:Dictionary=plan();gentle.tackles=["gentleSinker"]
	a.start(gentle,point());a.transition("fight");a.game.tension=0
	for i:int in 15:a.tick(.1)
	check(not bool(a.game.missed),"gentle sinker extends slack grace beyond 1.2 seconds")
	for i:int in 4:a.tick(.1)
	check(bool(a.game.missed),"gentle sinker slack grace still expires at 1.8 seconds")
	var plain:RefCounted=SESSION.new();plain.start(plan(),point());plain.transition("fight");plain.game.holding=true;plain.tick(.1)
	var upgrade:Dictionary=plan();upgrade.rod=1;a.start(upgrade,point());a.transition("fight");a.game.holding=true;a.tick(.1)
	check(is_equal_approx((100-float(a.game.stamina))/(100-float(plain.game.stamina)),1.08),"rod level adds eight percent reel efficiency")
	upgrade=plan();upgrade.skill=4;a.start(upgrade,point());a.transition("fight");a.game.holding=true;a.tick(.1)
	check(is_equal_approx((float(a.game.tension)-35)/(float(plain.game.tension)-35),.88),"four skill levels lower tension growth by twelve percent")
	upgrade=plan();upgrade.tackles=["steadyFloat"];a.start(upgrade,point());a.launch()
	while a.game.stage!="bite":a.tick(.01)
	for i:int in 160:a.tick(.01)
	check(a.game.stage=="bite","steady float adds a real 0.35 second hook window")
	a.command("press");check(a.game.stage=="fight","late hook inside extended window succeeds")
	var toggled:RefCounted=SESSION.new();toggled.start(toggle_plan,point());toggled.command("press");toggled.command("release");toggled.command("press");toggled.command("release")
	for i:int in 6000:
		var g:Dictionary=toggled.game
		if g.stage in ["caught","miss"]:break
		var click:bool=g.stage=="bite"
		if g.stage=="fight":
			var surge:bool=str(g.fishPhase) in ["charge","surge"]
			click=bool(g.holding) and (float(g.tension)>=68 or surge and float(g.tension)>=50) or not bool(g.holding) and (float(g.tension)<=24 or float(g.tension)<=35 and not surge)
		if click:toggled.command("press");toggled.command("release")
		toggled.tick(1.0/120)
	check(bool(toggled.game.caught),"toggle input catches using physical press release edges")
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT");DirAccess.make_dir_recursive_absolute(out)
	var file:=FileAccess.open(out+"/tension-balance.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("FISHING_TENSION: %d passed, %d failed; balance_games=%d"%[passed,failed,results.size()])
	await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
