extends Node2D
## Ground changes stay inside each authored pen; fixtures leave the centre aisle clear.
const PRODUCTS = preload("res://scripts/ranch_products.gd")
class FixturePaint extends Node2D:
	var asset := ""
	var home := ""
	var rect := Rect2()
	func _draw() -> void:
		var texture: Texture2D=preload("res://scripts/character_art.gd").texture("res://art/world/ranch/"+asset+".png")
		if texture==null:return
		preload("res://scripts/ground_style.gd").shadow(self,Vector2.ZERO,rect.size.x*0.8,5)
		draw_texture_rect(texture,rect,false)
		if asset=="trough":
			var total:=0
			for value:Variant in GameState.ranch.barns[home].get("trough",{}).values():total+=int(value)
			for seed:int in range(mini(24,total*3)):draw_circle(Vector2(-26+fposmod(seed*7.3,49),-23+fposmod(seed*4.2,8)),1.1,Color("d2bc6c"))
var elapsed := 0.0
func _ready() -> void:
	z_index = 0
	y_sort_enabled = true
	for home: String in GameState.system_catalog.ranch.barns:
		if str(GameState.system_catalog.ranch.barns[home].house)!=GameState.current_interior:continue
		for spec: Array in [["bed",Vector2(240,397),Rect2(-62,-57,124,57)],["bed",Vector2(720,397),Rect2(-62,-57,124,57)],["trough",Vector2(250,489),Rect2(-40,-41,80,41)],["box",Vector2(730,489),Rect2(-30,-57,60,57)]]:
			var prop:=FixturePaint.new();prop.asset=str(spec[0]);prop.home=home;prop.position=spec[1];prop.rect=spec[2];add_child(prop)
	GameState.changed.connect(queue_redraw)
	GameState.clock_changed.connect(queue_redraw)
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.4:
		elapsed = 0; queue_redraw()
		for prop: Node2D in get_children(): prop.queue_redraw()
func _draw() -> void:
	var room: String = GameState.current_interior
	if room == "":
		for index: int in range(GameState.system_catalog.forage.pens.size()):
			var pen: Dictionary = GameState.system_catalog.forage.pens[index]
			_draw_pen(pen)
			var grass: float = float(GameState.ranch.grass[index])/100.0
			var rect := Rect2(float(pen.x)+14,float(pen.y)+14,float(pen.w)-28,float(pen.h)-28)
			draw_rect(rect,Color(0.32,0.45,0.24,0.10+grass*0.13))
			for i: int in range(160):
				var p := rect.position+Vector2(fposmod(i*73.1,rect.size.x),fposmod(i*47.7,rect.size.y))
				if float(i)/160.0 > grass:
					draw_line(p,p+Vector2(5,1),Color(0.57,0.45,0.29,0.3),1.2)
				else:
					draw_polyline(PackedVector2Array([p+Vector2(-3,-4-grass*4),p,p+Vector2(3,-6-grass*4)]),Color(0.36,0.47,0.23,0.7),1.2,true)
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(15,25),"草量 %d%% · 轮牧恢复" % roundi(grass*100),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ddd7ae"))
		var corner:Dictionary=GameState.system_catalog.ranch.compostCorner
		_art("box",Rect2(float(corner.x)-22,float(corner.y)-40,44,40))
		_tag(Vector2(float(corner.x)-55,float(corner.y)-50),"圈肥熟化角")
		var bay: Dictionary = GameState.system_catalog.ranch.shallowWater
		var centre := Vector2(float(bay.x)+float(bay.w)/2,float(bay.y)+float(bay.h)/2)
		_art("shallow",Rect2(float(bay.x),float(bay.y),float(bay.w),float(bay.h)))
		_tag(centre+Vector2(-65,58),"浅水湾 · 鸭子戏水")
	else:
		for home: String in GameState.system_catalog.ranch.barns:
			var def: Dictionary = GameState.system_catalog.ranch.barns[home]
			if str(def.house) != room: continue
			var barn: Dictionary = GameState.ranch.barns[home]
			var clean: float = float(barn.clean)/100.0
			for i: int in range(70):
				var p := Vector2(160+fposmod(i*79,640),330+fposmod(i*43,155))
				if p.x>400 and p.x<560: continue
				draw_line(p,p+Vector2(7,2),Color(0.77,0.66,0.36,0.25+clean*0.3),1.5)
				if i>int(clean*70): draw_circle(p,2,Color(0.34,0.26,0.18,0.35))
			_tag(Vector2(175,220),"%s · 垫草%s · 清洁 %d%%" % [str(def.name),"干爽" if clean>0.6 else "待更换",roundi(clean*100)])
			var trough: Dictionary = barn.get("trough",{})
			var total := 0
			for amount: Variant in trough.values(): total += int(amount)

			_tag(Vector2(205,438),"料槽 %d 份" % total)
			_tag(Vector2(685,420),"收集箱 %d/%d" % [PRODUCTS.box_count(GameState,home),int(def.boxCapacity)])
			_tag(Vector2(165,545),str(barn.get("feedStatus","手动添料"))+"  ·  "+str(barn.get("collectStatus","手工收取")))
	for point: Dictionary in PRODUCTS.points(GameState,room):
		if str(point.kind) != "ranch-product": continue
		var row: Dictionary = {}
		for candidate: Dictionary in GameState.ranch.products:
			if str(candidate.id)==str(point.id): row=candidate; break
		var tex: Texture2D = preload("res://scripts/item_art.gd").texture_for(str(row.get("item","")))
		if tex != null:
			var at := Vector2(float(point.x),float(point.y))
			preload("res://scripts/ground_style.gd").shadow(self,at,19,4)
			draw_texture_rect(tex,Rect2(at-Vector2(11,19),Vector2(22,22)),false)

func _wood() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("876849"); box.border_color=Color("b69b73")
	box.set_border_width_all(2);box.set_corner_radius_all(4)
	return box

func _draw_pen(pen: Dictionary) -> void:
	var x := float(pen.x); var y := float(pen.y); var w := float(pen.w); var h := float(pen.h); var gate := float(pen.gate)
	for side: Array in [[Vector2(x,y),Vector2(gate-44,y)],[Vector2(gate+44,y),Vector2(x+w,y)],[Vector2(x,y+h),Vector2(x+w,y+h)],[Vector2(x,y),Vector2(x,y+h)],[Vector2(x+w,y),Vector2(x+w,y+h)]]:
		var from: Vector2 = side[0];var to: Vector2 = side[1]
		if absf(to.y-from.y)<1:
			var pieces:=maxi(1,ceili(from.distance_to(to)/70))
			for j: int in range(pieces):
				var at:=from.lerp(to,(j+0.5)/pieces)
				draw_set_transform(at)
				preload("res://scripts/world_art.gd").draw_prop(self,{"kind":"fence","w":from.distance_to(to)/pieces},GameState.season_index(),GameState.minutes)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_line(from+Vector2(0,-10),to+Vector2(0,-10),Color("8b7957"),3,true)
		var count := maxi(1,ceili(from.distance_to(to)/38))
		for i: int in range(count+1):
			var at := from.lerp(to,float(i)/count)
			draw_line(at+Vector2(0,2),at+Vector2(0,-27),Color("816c50"),4,true)

func _art(id: String, rect: Rect2) -> void:
	var texture: Texture2D = preload("res://scripts/character_art.gd").texture("res://art/world/ranch/"+id+".png")
	if texture != null: draw_texture_rect(texture,rect,false)

func _tag(at: Vector2, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	draw_style_box(_tag_box(),Rect2(at+Vector2(-6,-17),Vector2(width+12,25)))
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f0e1b9"))

func _tag_box() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color(0.17,0.24,0.19,0.88);box.set_corner_radius_all(4);return box
