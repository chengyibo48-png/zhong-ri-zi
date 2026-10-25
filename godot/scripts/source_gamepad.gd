extends RefCounted
var previous:Array=[]
var menu_at:float=0.0
var motion:Dictionary={"x":0.0,"y":0.0}
var used:=false
func down(buttons:Array,index:int)->bool:
	return index<buttons.size() and bool(buttons[index])
func edge(buttons:Array,index:int)->bool:
	return down(buttons,index) and not down(previous,index)
func poll(sample:Dictionary,enabled:bool,hidden:bool,locked:bool,panel:bool,now:float,focus_kind:String="none")->Array[Dictionary]:
	motion={"x":0.0,"y":0.0}
	used=false
	var commands:Array[Dictionary]=[]
	if not enabled or hidden:return commands
	if not bool(sample.get("connected",false)):
		previous=[]
		return commands
	var buttons:Array=sample.get("buttons",[])
	var axes:Array=sample.get("axes",[])
	var x:float=float(axes[0]) if axes.size()>0 else 0.0
	var y:float=float(axes[1]) if axes.size()>1 else 0.0
	if locked:
		if edge(buttons,1):commands.append({"kind":"cancel"})
		previous=buttons.duplicate()
		return commands
	used=edge(buttons,0) or edge(buttons,1) or edge(buttons,10) or absf(x)>0.2 or absf(y)>0.2
	if panel:
		if edge(buttons,4) or edge(buttons,5):commands.append({"kind":"tab","value":1 if edge(buttons,5) else -1})
		if edge(buttons,1) or edge(buttons,9):commands.append({"kind":"close"})
		else:
			var horizontal:=1 if edge(buttons,15) else -1 if edge(buttons,14) else 0
			if horizontal!=0 and focus_kind in ["select","range","number"]:commands.append({"kind":"horizontal","value":horizontal})
			var direction:=1 if down(buttons,13) else -1 if down(buttons,12) else int(signf(y)) if absf(y)>0.5 else 0
			if direction!=0 and now>menu_at:
				menu_at=now+190.0
				commands.append({"kind":"focus","value":direction})
			if edge(buttons,0):commands.append({"kind":"activate"})
	else:
		motion.x=(x if absf(x)>0.2 else 0.0)+(1.0 if down(buttons,15) else 0.0)-(1.0 if down(buttons,14) else 0.0)
		motion.y=(y if absf(y)>0.2 else 0.0)+(1.0 if down(buttons,13) else 0.0)-(1.0 if down(buttons,12) else 0.0)
		if motion.x!=0.0 or motion.y!=0.0:commands.append({"kind":"interrupt"})
		if edge(buttons,10):commands.append({"kind":"target"})
		if edge(buttons,0):commands.append({"kind":"interact"})
		for entry in [[2,"bag"],[3,"map"],[8,"journal"]]:
			if edge(buttons,entry[0]):commands.append({"kind":entry[1]})
		if edge(buttons,9) or edge(buttons,1):commands.append({"kind":"menu"})
		if edge(buttons,4) or edge(buttons,5):commands.append({"kind":"tool","value":1 if edge(buttons,5) else -1})
	previous=buttons.duplicate()
	return commands
func sample_native()->Dictionary:
	var pads:=Input.get_connected_joypads()
	if pads.is_empty():return {"connected":false}
	var device:int=pads[0]
	var buttons:Array=[]
	buttons.resize(17)
	buttons.fill(false)
	# Browser standard mapping differs from Godot's button enumeration.
	for pair in [[0,JOY_BUTTON_A],[1,JOY_BUTTON_B],[2,JOY_BUTTON_X],[3,JOY_BUTTON_Y],[4,JOY_BUTTON_LEFT_SHOULDER],[5,JOY_BUTTON_RIGHT_SHOULDER],[8,JOY_BUTTON_BACK],[9,JOY_BUTTON_START],[10,JOY_BUTTON_LEFT_STICK],[11,JOY_BUTTON_RIGHT_STICK],[12,JOY_BUTTON_DPAD_UP],[13,JOY_BUTTON_DPAD_DOWN],[14,JOY_BUTTON_DPAD_LEFT],[15,JOY_BUTTON_DPAD_RIGHT]]:
		buttons[pair[0]]=Input.is_joy_button_pressed(device,pair[1])
	return {"connected":true,"buttons":buttons,"axes":[Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y)]}
