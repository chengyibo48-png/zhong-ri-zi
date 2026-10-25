extends RefCounted
# Port of the final creatures-view.js silhouettes, states and eight-frame feet.
const LIFT := [0,1,2,1,0,0,0,0]
static func appearance(a: Dictionary, catalog: Dictionary, clock: float, pose: Dictionary = {}) -> Dictionary:
	var p: Dictionary = a.get("position",{})
	if p.get("room") != null: p = p.get("inside",{})
	var active := not pose.is_empty() and clock<float(pose.get("until",0))
	var action := str(pose.get("action",""))
	return {"direction":str(p.get("direction","down")),"walking":bool(p.get("walking",false)),
		"young":int(a.get("age",0))<int(catalog.get("species",{}).get(str(a.get("type","")),{}).get("adult",6)),
		"sick":int(a.get("illness",0))>=20,"sleepy":bool(a.get("rest",false)),"hungry":int(a.get("hunger",100))<35,
		"dirty":int(a.get("clean",100))<45,"eating":active and action=="feed","happy":active and action in ["pet","clean"],
		"sheared":active and action=="collect" and str(a.get("type",""))=="sheep",
		"tail":1.5 if str(a.get("trait",""))=="friendly" else 0.5 if str(a.get("trait",""))=="shy" else 1.0}

static func _color(value: Variant) -> Color:
	return value if value is Color else Color(str(value))
static func _shade(color: Color, amount: int) -> Color:
	return Color(clampf(color.r+float(amount)/255,0,1),clampf(color.g+float(amount)/255,0,1),clampf(color.b+float(amount)/255,0,1),color.a)
static func _box(c: CanvasItem,x: float,y: float,w: float,h: float,color: Variant) -> void:
	c.draw_rect(Rect2(floorf(x+0.5),floorf(y+0.5),maxf(1,floorf(w+0.5)),maxf(1,floorf(h+0.5))),_color(color))
static func _blob(c: CanvasItem,x: float,y: float,w: float,h: float,color: Variant) -> void:
	var points := PackedVector2Array([Vector2(x+3,y),Vector2(x+w-3,y),Vector2(x+w,y+3),Vector2(x+w,y+h-3),Vector2(x+w-3,y+h),Vector2(x+3,y+h),Vector2(x,y+h-3),Vector2(x,y+3)])
	for index in range(points.size()): points[index] = Vector2(floorf(points[index].x+0.5),floorf(points[index].y+0.5))
	c.draw_colored_polygon(points,_color(color))
static func _shadow(c: CanvasItem, at: Vector2,w: float,h: float) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := float(i)*TAU/24
		points.append(at+Vector2(5+cos(angle)*w/2,3+sin(angle)*h/2))
	c.draw_colored_polygon(points,Color("#263e352b"))

static func animal(c: CanvasItem,a: Dictionary,at: Vector2,catalog: Dictionary,clock: float,pose: Dictionary = {}) -> bool:
	var v := appearance(a,catalog,clock,pose)
	var type_id := str(a.get("type","hen"))
	var bird := type_id in ["hen","duck"]
	var side := str(v.direction) in ["left","right"]
	var back := str(v.direction)=="up"
	var size := 0.64 if bool(v.young) else 1.23 if type_id=="cow" else 1.0
	if bird: size *= 0.62 if type_id == "hen" else 0.57
	var coat := Color("#a38c6e") if str(a.get("breed","local"))=="hardy" else Color("#e2ccad") if str(a.get("breed","local"))=="productive" else Color(str(catalog.get("species",{}).get(type_id,{}).get("color","#d6be8d")))
	var shade := _shade(coat,-26)
	var highlight := _shade(coat,20)
	var phase := posmod(floori(clock*9),8)
	var lift := float(LIFT[phase]) if bool(v.walking) else 0.0
	at = at.round()
	_shadow(c,at,(31.0 if bird else 49.0)*size,8*size)
	if preload("res://scripts/animal_art.gd").draw(c,a,v,at,clock if str(GameState.visual_fx.get("motion","full"))=="full" else 0.0):
		_animal_status(c,a,v,at,size)
		return true
	c.draw_set_transform(at,0,Vector2((-1.0 if str(v.direction)=="left" else 1.0)*size,size))
	var legs: Array = [[-1,-7],[1,7]] if bird else [[-1,-18],[1,-9],[1,12],[-1,21]] if side else [[-1,-11],[1,7]]
	for leg in legs:
		var l := lift if int(leg[0])<0 else float(LIFT[(phase+4)%8]) if bool(v.walking) else 0.0
		_box(c,float(leg[1]),-10-l,3 if bird else 5,10,"#b48845" if bird else "#937957")
		_box(c,float(leg[1])-1,-l,7,3,"#d0a052" if bird else "#464c40")
	var bw := (33.0 if side else 25.0) if bird else (51.0 if side else 33.0)
	var bh := 23.0 if bird else (29.0 if side else 34.0)
	var by := -32.0 if bird else -39.0
	_blob(c,-bw/2,by,bw,bh,shade)
	_blob(c,-bw/2+2,by+1,bw-4,bh-4,coat)
	_box(c,-bw/2+5,by+3,bw-12,3,highlight)
	if type_id=="sheep" and not bool(v.sheared):
		for i in range(10):
			_blob(c,-bw/2+2+(i%5)*(bw-5)/5,by-2+floorf(float(i)/5)*9,10,9,"#dfd9c3" if i%2 else "#ede8d5")
	elif type_id=="cow":
		_box(c,-bw/2+8,by+6,9,8,shade); _box(c,2,by+16,8,7,shade)
	elif bird:
		_blob(c,-bw/2+3,by+10,15 if side else 18,10,"#aab7a0" if type_id=="duck" else "#c2a16f")
		_box(c,-bw/2+6,by+14,10,1,highlight)
	if bool(v.dirty):
		for i in range(6): _box(c,-bw/2+5+i*4,by+bh-6-(i%2)*3,3,2,"#8d7956")
	var hx := (15.0 if bird else 25.0) if side else 0.0
	var hy := (-37.0 if bird else -32.0)+(roundf(3+sin(clock*9)*2) if bool(v.eating) else 3.0 if bool(v.hungry) and not bool(v.walking) else 0.0)
	var hw := 15.0 if bird else 22.0 if type_id=="pig" else 20.0
	if not back or side:
		_blob(c,hx-hw/2,hy,hw,17 if bird else 21,"#9b8b72" if type_id=="sheep" else coat)
		if not bird:
			_box(c,hx-hw/2-4,hy+1,6,5,coat); _box(c,hx+hw/2-2,hy+1,6,5,coat)
			if type_id=="cow":
				_box(c,hx-9,hy-6,3,8,"#dcd9b7"); _box(c,hx+7,hy-6,3,8,"#dcd9b7")
		var closed := bool(v.sleepy) or bool(v.sick) or posmod(floori(clock*3+float(a.get("age",0))),19)==0
		var eyes: Array = [hx+2] if side else [hx-5,hx+4]
		for eye in eyes:
			_box(c,float(eye),hy+6,2,1 if closed else 3,"#2e4138")
			if not closed: _box(c,float(eye),hy+6,1,1,"#f6efd2")
		if bird:
			_box(c,hx+6 if side else hx-3,hy+11,10 if type_id=="duck" else 7,4,"#d5a052")
			if type_id=="hen":
				_box(c,hx-3,hy-4,7,2 if bool(v.young) else 4,"#b65e4c"); _box(c,hx+2,hy+16,3,4,"#b65e4c")
			else: _box(c,hx-5,hy+17,10,2,"#729387")
		else:
			_blob(c,hx+3 if side else hx-8,hy+12,17,9,"#bd8981" if type_id=="pig" else "#c7b391")
			_box(c,hx+10 if side else hx-4,hy+16,2,2,"#796252")
			if type_id=="pig" or not side: _box(c,hx+15 if side else hx+3,hy+16,2,2,"#796252")
	else:
		_box(c,-6,by-3,12,6,coat)
		if type_id=="hen": _box(c,-3,by-5,6,3,"#b65e4c")
	if not bird:
		var tx := -28.0 if side else 0.0
		var ty := -23.0 if side else -16.0
		var wiggle := roundf(sin(clock*4)*float(v.tail)*2)
		_box(c,tx,ty,2,13,"#9d8968"); _box(c,tx-1+wiggle,ty+11,4,4,"#b4897b" if type_id=="pig" else "#76644a")
		if not back:
			_box(c,hx-8,hy+20,16,3,"#72959c" if str(a.get("trait",""))=="shy" else "#b25c4c" if str(a.get("trait",""))=="friendly" else "#789257")
			_box(c,hx,hy+23,3,3,"#dcc07a")
	c.draw_set_transform(Vector2.ZERO)
	_animal_status(c,a,v,at,size)
	return false

static func _animal_status(c:CanvasItem,a:Dictionary,v:Dictionary,at:Vector2,size:float)->void:
	var symbol := "!" if bool(v.sick) or bool(a.get("lost",false)) else "…" if bool(v.hungry) else "✦" if int(a.get("ready",0))>0 or int(a.get("feathers",0))>0 else "♡" if bool(v.happy) else ""
	if symbol!="":
		_blob(c,at.x-9,at.y-59*size,18,16,"#ac7350" if bool(v.sick) or bool(a.get("lost",false)) else "#6a8c70")
		c.draw_string(ThemeDB.fallback_font,at+Vector2(-9,-47*size),symbol,HORIZONTAL_ALIGNMENT_CENTER,18,12,Color("#fff2d2"))

static func pet(c: CanvasItem,pet_data: Dictionary,companion: Dictionary,at: Vector2,clock: float,minutes: float) -> void:
	if preload("res://scripts/pet_art.gd").draw(c,pet_data,companion,at,minutes,clock): return
	var p: Dictionary = pet_data.get("position",{})
	var cat := str(companion.get("type","cat"))=="cat"
	var left := str(p.get("direction","down"))=="left"
	var back := str(p.get("direction","down"))=="up"
	var side := left or str(p.get("direction","down"))=="right"
	var rest := int(pet_data.get("energy",100))<15 or minutes>=1140
	var walking := bool(p.get("walking",false)) and not rest
	var hungry := float(pet_data.get("hunger",100))<28.0
	var patted_today := int(companion.get("patted",-1))==int(GameState.day)
	var coat := Color("#c49c66") if cat else Color("#b58758")
	var wag := roundf(sin(clock*(1 if rest else 5))*(1 if rest else 3))
	var bob := absf(sin(clock*12.0))*1.4 if walking else sin(clock*1.8)*0.6 if not rest else 0.0
	at = at.round()
	c.draw_set_transform(at+Vector2(0,4.0-bob if rest else -bob),-0.035 if rest else sin(clock*7.0)*0.025 if walking else 0.0,Vector2(-0.5 if left else 0.5,0.5))
	_shadow(c,Vector2.ZERO,32,6)
	for x in [-10,8]:
		var step_lift := sin(clock*12.0+float(x))*2.0 if walking else 0.0
		_box(c,x,-9-step_lift,4,10,"#80644a"); _box(c,x-1,-step_lift,6,2,"#5c5543")
	_blob(c,-18 if side else -13,-21 if rest else -24,34 if side else 26,19 if rest else 19,coat)
	var hx := 13.0 if side else 0.0
	_blob(c,hx-9,-30 if rest else -34,18,20,"#d9b886")
	if cat:
		c.draw_colored_polygon(PackedVector2Array([Vector2(hx-9,-27 if rest else -31),Vector2(hx-9,-37 if rest else -41),Vector2(hx-2,-31 if rest else -35)]),coat)
		c.draw_colored_polygon(PackedVector2Array([Vector2(hx+2,-31 if rest else -35),Vector2(hx+9,-37 if rest else -41),Vector2(hx+9,-27 if rest else -31)]),coat)
	else:
		_box(c,hx-11,-33,5,13,"#796049"); _box(c,hx+7,-33,5,13,"#796049")
	if not back:
		if rest:
			_box(c,hx-5,-27,4,1,"#334237"); _box(c,hx+3,-27,4,1,"#334237")
		else:
			_box(c,hx-4,-28,2,3,"#334237"); _box(c,hx+4,-28,2,3,"#334237")
		_box(c,hx,-22,3,2,"#735846")
		if cat:
			_box(c,hx-13,-22,8,1,"#e7d6ac"); _box(c,hx+7,-22,8,1,"#e7d6ac")
	_box(c,-21 if side else 0,-24+wag,4,15,coat)
	_box(c,hx-8,-16,17,3,"#ae6250"); _box(c,hx,-13,3,3,"#e2c77d")
	c.draw_set_transform(Vector2.ZERO)
	if rest:
		c.draw_string(ThemeDB.fallback_font,at+Vector2(8,-23-sin(clock*1.2)*1.4),"z",HORIZONTAL_ALIGNMENT_CENTER,8,8,Color("#e5dfc9"))
	elif hungry:
		c.draw_ellipse(at+Vector2(0,3),7.0,2.0,Color("#8f744d"))
		c.draw_ellipse(at+Vector2(0,1),4.0,1.0,Color("#d8c17b"))
	elif patted_today and int(floor(clock*0.45))%4==0:
		c.draw_circle(at+Vector2(10,-20),2.0,Color("#e98f92")); c.draw_circle(at+Vector2(13,-18),1.5,Color("#e98f92"))
	elif walking and int(pet_data.get("training",0))>=20:
		c.draw_arc(at+Vector2(sin(clock*4.0)*10.0,-10),3.0,0.0,TAU,12,Color("#e1b75f"),1.2)
	elif not walking and not rest and posmod(floori(clock/7.0),5)==2:
		_box(c,roundf(at.x-2),roundf(at.y-29),3,7,"#c49c66"); _box(c,roundf(at.x-4),roundf(at.y-31),3,3,"#d9b886")

static func action_primitives(a: Dictionary,at: Vector2,kind: String,age: float) -> Array:
	var rows: Array = []
	var x := at.x
	var y := at.y
	if kind=="feed":
		rows.append(["oval",x+26,y+1,12,5,"#866b46"])
		rows.append(["oval",x+26,y-1,10,3,"#cbb679"])
		for i in range(7): rows.append(["rect",floorf(x+22+(i%3)*3+0.5),floorf(y-11+fmod(age*14+i*3,10)+0.5),2,2,"#e2ca7a"])
	if kind=="collect" and str(GameState.system_catalog.ranch.species.get(str(a.type),{}).get("harvestAction",""))=="milk":
		rows.append(["rect",floorf(x+18+0.5),floorf(y-2+0.5),15,15,"#8ba7a0"])
		rows.append(["oval",x+25,y-1,7,3,"#eee9cc"])
		rows.append(["rect",floorf(x+25+0.5),floorf(y-12+0.5),1,10,"#eee8d0"])
	if kind=="collect" and str(GameState.system_catalog.ranch.species.get(str(a.type),{}).get("harvestAction","")) =="shear":
		rows.append(["line",x-1,y-31,x+16,y-17,"#627c78",2])
		rows.append(["line",x+17,y-31,x,y-17,"#627c78",2])
		for i in range(4): rows.append(["oval",x-15+i*10,y-8+age*5,4,3,"#eee6ce"])
	if kind=="collect" and str(GameState.system_catalog.ranch.species.get(str(a.type),{}).get("harvestAction",""))=="groom":
		var brush_x := x-8+sin(age*7)*8
		rows.append(["rect",brush_x,y-22,14,5,"#927252"])
		for i in range(5):rows.append(["line",brush_x+i*3,y-17,brush_x+i*3,y-13,"#dbc99d",1])
		for i in range(3):rows.append(["oval",x-8+i*8,y-5+age*3,3,2,"#e9dfcf"])
	if kind=="collect" and str(a.type) in ["hen","duck"]:
		rows.append(["oval",x+22,y-1,14,6,"#ab8652"])
		for i in range(3): rows.append(["oval",x+14+i*7,y-5,4,6,"#f0e5bf"])
	if kind=="clean":
		for i in range(8): rows.append(["oval",x-20+i*6,y-20-sin(age*3+i)*7,2,2,"#dfede1"])
	return rows

static func action_visible(fx: Dictionary,id: String,room: String,clock: float) -> bool:
	return not fx.is_empty() and str(fx.get("id",""))==id and str(fx.get("room","") if fx.get("room")!=null else "")==room and clock-float(fx.get("at",0))<=2.2

static func action(c: CanvasItem,a: Dictionary,at: Vector2,fx: Dictionary,room: String,clock: float,origin: Vector2 = Vector2.ZERO) -> void:
	if not action_visible(fx,str(a.id),room,clock): return
	c.draw_set_transform(-origin)
	for row in action_primitives(a,at+origin,str(fx.kind),clock-float(fx.at)):
		if row[0]=="rect": c.draw_rect(Rect2(float(row[1]),float(row[2]),float(row[3]),float(row[4])),Color(str(row[5])))
		elif row[0]=="line": c.draw_line(Vector2(float(row[1]),float(row[2])),Vector2(float(row[3]),float(row[4])),Color(str(row[5])),float(row[6]))
		else:
			var points := PackedVector2Array()
			for i in range(24): points.append(Vector2(float(row[1]),float(row[2]))+Vector2(cos(float(i)*TAU/24)*float(row[3]),sin(float(i)*TAU/24)*float(row[4])))
			c.draw_colored_polygon(points,Color(str(row[5])))
	c.draw_set_transform(Vector2.ZERO)
