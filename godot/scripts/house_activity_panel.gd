extends Control
var paper:PanelContainer
var heading:Label
var status:Label
var prompt:Label
var preview:Control
var slider:HSlider
var choices:HFlowContainer
var confirm:Button
var home_preview:bool=false
var token:int=-1
var alignment:float=.1
var board_texture:Texture2D
var board_region:Rect2
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);set_meta("ui_managed_layout",true);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	paper=PanelContainer.new();paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER);paper.offset_left=-320;paper.offset_right=320;paper.offset_top=-235;paper.offset_bottom=235;add_child(paper)
	var margin:=MarginContainer.new()
	for side:String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	paper.add_child(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);margin.add_child(column)
	var head:=HBoxContainer.new();column.add_child(head)
	heading=Label.new();heading.set_meta("ui_role","heading");heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(heading)
	var back:=Button.new();back.text="先收好";back.set_meta("ui_role","quiet");back.pressed.connect(close);head.add_child(back)
	status=Label.new();status.set_meta("ui_role","caption");status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	prompt=Label.new();prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(prompt)
	preview=Control.new();preview.custom_minimum_size=Vector2(0,90);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview.draw.connect(_draw_board);column.add_child(preview)
	slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.025;slider.custom_minimum_size.y=48;slider.value_changed.connect(func(value:float):alignment=value;preview.queue_redraw());column.add_child(slider)
	choices=HFlowContainer.new();choices.add_theme_constant_override("h_separation",8);column.add_child(choices)
	confirm=Button.new();confirm.text="对好了，接着做";confirm.set_meta("ui_role","primary");confirm.pressed.connect(_align);column.add_child(confirm)
	hide()
func open_panel(point:Dictionary)->void:
	home_preview=false
	preview.custom_minimum_size.y=90
	GameState._interrupt_navigation_for_ui()
	var result:Dictionary=GameState.house_activity.start(GameState,point)
	if not result.has("token"):GameState.message=str(result.get("reason","暂时无法开始。"));return
	token=int(result.token)
	var config:Dictionary=preload("res://scripts/house_geometry.gd").profile(str(result.room))
	var art:Dictionary=preload("res://scripts/world_art.gd").entries().get("interior_props/"+str(config.get("memorialArt","主人手记")),{})
	var owner:String=str(config.get("owner",""))
	var item:String="cloth" if owner=="granny" else "tea" if owner in ["zhou","zhouSenior"] else "bamboo" if owner in ["luSenior","bao"] else "rice" if owner in ["mei","ning"] else "wood"
	board_texture=preload("res://scripts/item_art.gd").texture_for(item)
	if board_texture!=null:board_region=Rect2(board_texture.get_image().get_used_rect())
	show();GameState.ui_open=true;refresh()
func close()->void:
	home_preview=false
	GameState.house_activity.cancel(token);hide();GameState.ui_open=false
func is_open()->bool:return visible
func refresh()->void:
	if home_preview:return
	var a:Dictionary=GameState.house_activity.snapshot()
	if a.is_empty():close();return
	heading.text=str(a.view.name)
	status.text="第 %d / 3 步 · 完成后 %d 游戏分钟 · 不耗体力 · 取消不结算"%[int(a.step)+1,int(a.view.minutes)]
	var owner:String=str(a.view.owner)
	status.text+=("\n首次完成关系 +1，并留下"+str(a.view.memorial)) if owner!="" and not bool(GameState.interior_state.get("household",{}).get("relationClaims",{}).get(owner,false)) else "\n可重复体验；关系不重复增加，原有纪念可以换一种摆法。" if owner!="" else "\n留下生活记录，不发现金或出售物。"
	var step:Dictionary=a.view.steps[int(a.step)];prompt.text=str(step.label)
	for child:Node in choices.get_children():choices.remove_child(child);child.queue_free()
	var align:bool=str(step.kind)=="align";slider.visible=align;confirm.visible=align;choices.visible=not align
	if align:
		alignment=.1;slider.value=.1;slider.grab_focus.call_deferred()
		status.text+="\n用方向键、摇杆或拖动滑块，让手边物件进入浅绿刻线。"
	else:
		for index:int in 2:
			var button:=Button.new();button.text=str(step.options[index]);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.custom_minimum_size=Vector2(180,48);button.pressed.connect(_choose.bind(index));choices.add_child(button)
		choices.get_child(0).grab_focus.call_deferred()
	preview.queue_redraw();UIArtService.apply_subtree(self)
func _choose(index:int)->void:_submit(index)
func _align()->void:_submit(float(slider.value))
func _submit(value:Variant)->void:
	if not GameState.house_activity.input(GameState,token,value):
		var a:Dictionary=GameState.house_activity.snapshot()
		if a.is_empty():close();return
		var ready:Dictionary=GameState.house_activity.describe(GameState,a.point)
		status.text=str(ready.reason) if not ready.ready else str(GameState.message) if str(GameState.message).begins_with("再观察") else "可以慢慢比较、整理，没有时间限制。";return
	if int(GameState.house_activity.active.step)<3:refresh();return
	if GameState.house_activity.finish(GameState,token):get_parent().ui_stack.leave()
	else:status.text="条件变了，先收好；这次没有结算。";GameState.house_activity.cancel(token);hide();GameState.ui_open=false
func _draw_board()->void:
	if home_preview:
		_draw_home_preview();return
	var a:Dictionary=GameState.house_activity.snapshot()
	if a.is_empty():return
	var step:Dictionary=a.view.steps[mini(2,int(a.step))];var width:float=preview.size.x;var y:float=42
	preview.draw_style_box(UIArtService._flat_style("ebe9dc","d2d9cb"),Rect2(0,4,width,78))
	if str(step.kind)!="align":
		var options:Array=step.get("options",[])
		for i:int in options.size():
			var at:Vector2=Vector2(width*(.25+.5*i),42)
			if board_texture!=null and board_region.has_area():
				var size:Vector2=board_region.size;size*=minf(54.0/size.x,54.0/size.y)
				preview.draw_texture_rect_region(board_texture,Rect2(at-size*.5,size),board_region,Color(1,1,1,1 if i==0 else .65))
			preview.draw_string(ThemeDB.fallback_font,at+Vector2(-4,35),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("52634f"))
		return
	var target:float=float(step.get("target",.5));var x:float=24+(width-48)*target
	preview.draw_rect(Rect2(x-12,y-27,24,54),Color("b9cfac"))
	preview.draw_line(Vector2(24,y),Vector2(width-24,y),Color("849780"),2,true)
	var moving:float=24+(width-48)*(alignment if str(step.kind)=="align" else .32+.18*int(a.step))
	if board_texture!=null and board_region.has_area():
		var size:Vector2=board_region.size;size*=minf(66.0/size.x,64.0/size.y)
		preview.draw_texture_rect_region(board_texture,Rect2(Vector2(moving-size.x*.5,y-size.y*.5),size),board_region)
		return
	# Fallback remains a continuous piece.
	var shape:=PackedVector2Array([Vector2(moving-22,y-15),Vector2(moving+12,y-15),Vector2(moving+12,y-7),Vector2(moving+23,y-7),Vector2(moving+23,y+7),Vector2(moving+12,y+7),Vector2(moving+12,y+15),Vector2(moving-22,y+15)])
	preview.draw_colored_polygon(shape,Color("ae885d"));preview.draw_polyline(shape,Color("725738"),1.5,true)
	preview.draw_line(Vector2(moving-17,y-6),Vector2(moving+8,y-6),Color("d6bb90"),1.5,true)

func open_home_preview()->void:
	GameState._interrupt_navigation_for_ui();home_preview=true;token=-1
	heading.text="让老屋多一点生活气"
	var view:Dictionary=preload("res://scripts/house_life.gd").preview(GameState)
	status.text="可补充 %d 件 · 避让已有布置 %d 件\n原家具不移动、不收回；补充物不进入出售库存，不耗时间或材料。"%[view.added,view.skipped]
	prompt.text="下图为实际房间位置；浅色块为将补充的家具。可随时撤回本轮补充。"
	slider.hide();confirm.hide();choices.show();preview.custom_minimum_size.y=160
	for child:Node in choices.get_children():choices.remove_child(child);child.queue_free()
	for entry:Array in [["确认补充空位",true],["撤回本轮补充",false]]:
		var button:=Button.new();button.text=str(entry[0]);button.custom_minimum_size=Vector2(180,48);button.pressed.connect(_apply_home.bind(bool(entry[1])));choices.add_child(button)
	show();GameState.ui_open=true;UIArtService.apply_subtree(self);preview.queue_redraw();choices.get_child(0).grab_focus.call_deferred()
func _apply_home(on:bool)->void:
	if GameState.house_activity.set_home_preset(GameState,on):get_parent().ui_stack.leave()
	else:status.text="位置或保存条件变了，原有家具和补充状态保持不变。"
func _draw_home_preview()->void:
	var scale:float=minf(preview.size.x/756.0,preview.size.y/500.0)
	var origin:Vector2=Vector2((preview.size.x-756*scale)*.5,0)
	preview.draw_rect(Rect2(origin,Vector2(756,500)*scale),Color("d8c4a0"))
	for fixed:Rect2 in [Rect2(185,231,122,57),Rect2(608,274,109,44) if int(GameState.building.get("house",0))>=1 else Rect2()]:
		if fixed.has_area():preview.draw_rect(Rect2(origin+(fixed.position-Vector2(102,104))*scale,fixed.size*scale),Color("75664c"))
	var zone:Dictionary=GameState.system_catalog.building.zones.home;var defs:Dictionary=GameState.system_catalog.building.defs
	for piece:Dictionary in GameState.building.get("layout",[]):
		if str(piece.get("zone",""))!="home":continue
		var d:Dictionary=defs.get(str(piece.type),{});var rotate:bool=posmod(int(piece.get("rotation",0)),2)==1;var cell:int=int(piece.cell)
		var at:=Vector2(float(zone.x)+(cell%int(zone.cols))*float(zone.size),float(zone.y)+floorf(float(cell)/int(zone.cols))*float(zone.size))-Vector2(102,104)
		var size:=Vector2(float(d.get("h" if rotate else "w",1)),float(d.get("w" if rotate else "h",1)))*float(zone.size)
		preview.draw_rect(Rect2(origin+at*scale,size*scale),Color("75664c"))
	for row:Dictionary in preload("res://scripts/house_life.gd").rows(GameState,"building-farm-12",true):
		var r:Rect2=preload("res://scripts/house_life.gd").footprint(row);r.position-=Vector2(102,104)
		preview.draw_rect(Rect2(origin+r.position*scale,r.size*scale),Color("a3b989"))
		var art:Dictionary=preload("res://scripts/world_art.gd").entries().get("interior_props/"+str(row.kind),{})
		var texture:Texture2D=preload("res://scripts/character_art.gd").texture(str(art.get("path","")))
		if texture!=null:preview.draw_texture_rect(texture,Rect2(origin+(Vector2(row.x,row.y)-Vector2(102,104))*scale-Vector2(18,32),Vector2(36,32)),false)
