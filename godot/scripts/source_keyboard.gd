extends RefCounted
# The original app uses a Set of DOM key names, rather than physical polling.
var keys:Dictionary={}
func clear()->void:keys.clear()
func key_name(event:InputEventKey)->String:
	match event.keycode:
		KEY_SHIFT:return "shift"
		KEY_UP:return "arrowup"
		KEY_DOWN:return "arrowdown"
		KEY_LEFT:return "arrowleft"
		KEY_RIGHT:return "arrowright"
	# Release events may omit unicode; ordinary keycodes are Unicode values.
	var value:int=event.unicode if event.unicode>0 and event.unicode<=0x10ffff else int(event.keycode)
	# JavaScript full lowercase expands capital dotted I into two code points.
	if value==0x0130:return "i\u0307"
	if value>=32 and value<=0x10ffff:return char(value).to_lower()
	return OS.get_keycode_string(event.keycode).to_lower()
func accept(event:InputEventKey,bindings:Dictionary,blocked:bool,text_focus:bool)->bool:
	var key:=key_name(event)
	if not event.pressed:
		keys.erase(key)
		return false
	if blocked or text_focus or event.ctrl_pressed or event.meta_pressed or event.alt_pressed:return false
	if key=="shift":keys[key]=true
	var directions:Array=[bindings.get("up","w"),bindings.get("left","a"),bindings.get("down","s"),bindings.get("right","d"),"arrowup","arrowdown","arrowleft","arrowright"]
	if directions.has(key):
		keys[key]=true
		return true
	return false
func direction(bindings:Dictionary)->Vector2:
	var right:=keys.has(str(bindings.get("right","d"))) or keys.has("arrowright")
	var left:=keys.has(str(bindings.get("left","a"))) or keys.has("arrowleft")
	var down:=keys.has(str(bindings.get("down","s"))) or keys.has("arrowdown")
	var up:=keys.has(str(bindings.get("up","w"))) or keys.has("arrowup")
	return Vector2(float(right)-float(left),float(down)-float(up))
func fast()->bool:return keys.has("shift")

# Action order follows the original document keydown handler. Modal controls
# receive their own native GUI events; they do not invoke world shortcuts.
func commands(event:InputEventKey,bindings:Dictionary,panel:bool,locked:bool,text_focus:bool,button_focus:bool)->Array[String]:
	var result:Array[String]=[]
	if not event.pressed:return result
	if event.keycode==KEY_ESCAPE:
		result.append("cancel" if locked else "close" if panel else "menu")
		return result
	if panel or locked or text_focus or event.ctrl_pressed or event.meta_pressed or event.alt_pressed:return result
	var key:=key_name(event)
	if key==" " and button_focus:return result
	if event.echo:return result
	if key in ["[","]"]:
		result.append("previous_target" if key=="[" else "next_target")
		return result
	if key.length()==1 and key>="1" and key<="8":result.append("tool:"+key)
	if key==str(bindings.get("interact","e")) or key==" ":result.append("interact")
	for action in ["bag","map","journal"]:
		if key==str(bindings.get(action,"")):result.append(action)
	match key:
		"tab":result.append("menu")
		"c":result.append("calendar")
		"q":result.append("seeds")
		"f":result.append("fullscreen")
		"h":result.append("hud")
	return result
