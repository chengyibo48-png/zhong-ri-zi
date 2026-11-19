extends Node2D
const MEADOW=preload("res://scripts/ranch_meadow.gd")
var player:CharacterBody2D
var hud:CanvasLayer
var ground_layer:TileMapLayer
var selected_room_target:Dictionary={}
var selected_world_target:Dictionary={}
var animal_nodes:Dictionary={}
var goods:Dictionary={}
var meadow_map:Control
var fixtures:Array=[]
class FieldLabel extends Node2D:
	var text:String=""
	func _draw()->void:draw_string(preload("res://art/fonts/NotoSansCJKsc-Regular.otf"),Vector2(-95,-18),text,HORIZONTAL_ALIGNMENT_CENTER,190,17,Color("4c6144"))
class ProductPaint extends Node2D:
	var item:String=""
	func _draw()->void:
		var texture:Texture2D=preload("res://scripts/item_art.gd").texture_for(item,"items")
		if texture!=null:draw_texture_rect(texture,Rect2(-10,-18,20,20),false)
class Scenery extends Node2D:
	var kind:String="plants"
	func _draw()->void:preload("res://scripts/world_art.gd").draw_prop(self,{"kind":kind,"x":0,"y":0,"_visual_rect":[-28,-33,56,33]},GameState.season_index(),GameState.minutes)
func _ready()->void:
	y_sort_enabled=true;MEADOW.ensure(GameState)
	ground_layer=TileMapLayer.new();ground_layer.name="Ground";ground_layer.z_index=-10;ground_layer.tile_set=preload("res://art/ground_tileset.tres");add_child(ground_layer)
	var season:int=GameState.season_index()
	for y:int in 64:
		for x:int in 96:
			var column:int=5
			var at:=Vector2(x*32+16,y*32+16)
			if x%22 in [0,1,2,21] or y in range(22,28) or y>=48:column=6
			if MEADOW.pond().has_point(at):column=8
			ground_layer.set_cell(Vector2i(x,y),0,Vector2i(column,season*4+posmod(x*7+y*13,4)))
	preload("res://scripts/ground_style.gd").apply(ground_layer)
	for i:int in 8:_field(i)
	for i:int in 8:
		var plant:=Scenery.new();plant.position=MEADOW.pen(i).position+Vector2(630,75);add_child(plant)
	var gate:Node2D=load("res://scripts/meadow_gate_visual.gd").new();gate.position=MEADOW.EXIT+Vector2(0,42);add_child(gate)
	player=load("res://scripts/player.gd").new();player.position=GameState.interior_position;add_child(player)
	player.camera.limit_right=int(MEADOW.SIZE.x);player.camera.limit_bottom=int(MEADOW.SIZE.y);player.camera.reset_smoothing()
	hud=load("res://scripts/hud.gd").new();add_child(hud)
	meadow_map=load("res://scripts/meadow_map_panel.gd").new();meadow_map.world=self;hud.add_child(meadow_map)
	hud.ui_stack.panels.append(meadow_map);meadow_map.visibility_changed.connect(hud.ui_stack._visibility.bind(meadow_map));meadow_map.set_meta("ui_shell",true)
	GameState.ranch_positions_changed.connect(_sync_animals);GameState.changed.connect(_refresh);GameState.clock_changed.connect(_clock)
	_sync_animals();_refresh()
func _field(index:int)->void:
	var r:Rect2=MEADOW.pen(index);var gate:Vector2=MEADOW.gate(index)
	var segments:Array=[[r.position,Vector2(r.end.x,r.position.y)],[r.position,Vector2(r.position.x,r.end.y)],[Vector2(r.end.x,r.position.y),r.end],[Vector2(r.position.x,r.end.y),gate-Vector2(56,0)],[gate+Vector2(56,0),r.end]]
	for line:Array in segments:
		var a:Vector2=line[0];var b:Vector2=line[1];var length:float=a.distance_to(b);var count:int=ceili(length/64.0)
		for i:int in count:
			var fence:Node2D=load("res://scripts/ranch_fence_segment.gd").new();fence.vertical=absf(b.y-a.y)>1;fence.span=length/count;fence.position=a.lerp(b,(i+.5)/count);add_child(fence)
	var name:=FieldLabel.new();name.text=MEADOW.NAMES[index];name.position=r.position+Vector2(300,45);add_child(name)
	var species:String=["cow","cow","sheep","goat","hen","duck","pig","rabbit"][index];var home:String=str(GameState.system_catalog.ranch.species[species].home)
	for row:Array in [["trough",MEADOW.feeder(index),Rect2(-31,-34,62,34)],["bed",r.position+Vector2(300,125),Rect2(-45,-32,90,32)]]:
		var prop=load("res://scripts/ranch_fixture_visual.gd").FixturePaint.new();prop.asset=row[0];prop.home=home;prop.position=row[1];prop.rect=row[2];add_child(prop);fixtures.append(prop)
	var water:Node2D=load("res://scripts/ranch_fixture_visual.gd").FixturePaint.new();water.asset="shallow";water.home=home;water.position=MEADOW.water(index);water.rect=Rect2(-25,-29,50,29);add_child(water)
func _sync_animals()->void:
	var living:Dictionary={}
	for index:int in GameState.animals.size():
		var animal:Dictionary=GameState.animals[index]
		if animal.position.get("room")!=MEADOW.ID:continue
		var id:String=str(animal.id);living[id]=true
		var node:Node2D=animal_nodes.get(id)
		if node==null:
			node=load("res://scripts/ranch_animal.gd").new();node.animal_id=id;node.inside_room=MEADOW.ID;animal_nodes[id]=node;add_child(node)
		node.animal_index=index;node.position=Vector2(float(animal.position.inside.x),float(animal.position.inside.y));node.request_visual_update()
	for id:Variant in animal_nodes.keys():
		if not living.has(id):animal_nodes[id].queue_free();animal_nodes.erase(id)
	var products:Dictionary={}
	for row:Dictionary in GameState.ranch.get("products",[]):
		if row.get("room")!=MEADOW.ID or str(row.location) not in ["ground","nest"]:continue
		var id:String=str(row.id);products[id]=true
		if not goods.has(id):var node:=ProductPaint.new();node.item=str(row.item);goods[id]=node;add_child(node)
		goods[id].position=Vector2(float(row.x),float(row.y))
	for id:Variant in goods.keys():
		if not products.has(id):goods[id].queue_free();goods.erase(id)
func _refresh()->void:
	for fixture:Node in fixtures:fixture.queue_redraw()
	_sync_animals()
func _clock()->void:preload("res://scripts/ground_style.gd").update_weather(ground_layer,float(GameState.ground_conditions().get("snow",0)))
func show_meadow_map()->void:meadow_map.open_panel()
func _targets()->Array:
	var result:Array=[{"id":"meadow-exit","kind":"exit","name":"回原牧场","x":MEADOW.EXIT.x,"y":MEADOW.EXIT.y}]
	for id:Variant in animal_nodes:
		var index:int=GameState.ranch_animal_index(str(id))
		if index>=0:result.append({"id":str(id),"kind":"animal","name":str(GameState.animals[index].name),"x":animal_nodes[id].position.x,"y":animal_nodes[id].position.y})
	for i:int in 8:
		var p:Vector2=MEADOW.feeder(i)+Vector2(0,30);result.append({"id":"meadow-feeder-"+str(i),"kind":"meadow-feeder","name":"添满分区料槽","pen":i,"x":p.x,"y":p.y})
	result.append_array(load("res://scripts/ranch_products.gd").points(GameState,MEADOW.ID));return result
func resolve_interaction_target(target:Dictionary)->Dictionary:
	if str(target.get("kind",""))=="walk":return target
	for row:Dictionary in _targets():
		if str(row.id)==str(target.get("id","")) and str(row.kind)==str(target.get("kind","")):return row
	return {}
func _interact()->void:
	if GameState.ui_open or GameState.action_busy():return
	var closest:Dictionary={};var distance:float=76
	for row:Dictionary in _targets():
		var d:float=player.position.distance_to(Vector2(float(row.x),float(row.y)))
		if d<distance:distance=d;closest=row
	if not closest.is_empty():_interact_target(closest)
func interact_from_gamepad()->void:
	var actual:Dictionary=resolve_interaction_target(selected_room_target)
	if not actual.is_empty() and player.position.distance_to(Vector2(float(actual.x),float(actual.y)))<78:_interact_target(actual)
	else:_interact()
func _cycle_room_target(direction:int=1)->void:
	var nearby:Array=[]
	for row:Dictionary in _targets():
		if player.position.distance_to(Vector2(float(row.x),float(row.y)))<220:nearby.append(row)
	nearby.sort_custom(func(a:Dictionary,b:Dictionary):return str(a.id)<str(b.id))
	if nearby.is_empty():selected_room_target={};selected_world_target={};return
	var index:int=-1
	for i:int in nearby.size():
		if str(nearby[i].id)==str(selected_room_target.get("id","")):index=i;break
	selected_room_target=nearby[posmod(index+direction,nearby.size())];selected_world_target=selected_room_target
func _cycle_world_target(direction:int=1)->void:_cycle_room_target(direction)
func _activate_walk_target(target:Dictionary)->void:_interact_target(target)
func _interact_target(target:Dictionary)->void:
	var actual:Dictionary=resolve_interaction_target(target)
	if actual.is_empty() or GameState.ui_open or GameState.action_busy():return
	if player.position.distance_to(Vector2(float(actual.x),float(actual.y)))>78:return
	match str(actual.kind):
		"exit":GameState.leave_interior()
		"animal":GameState.queue_ranch_tasks([{"animalId":str(actual.id),"action":GameState.selected_animal_action,"arg":str(GameState.ranch.feed)}])
		"ranch-product":GameState.confirm_operation(GameState.ranch_fixture_action("ranch-product",str(actual.id)))
		"meadow-feeder":
			var species:String=["cow","cow","sheep","goat","hen","duck","pig","rabbit"][int(actual.pen)];var home:String=str(GameState.system_catalog.ranch.species[species].home)
			var spec:Dictionary=GameState.ACTION_RULES.spec("feed","添满分区料槽")
			GameState.begin_action(spec,actual,func():
				if GameState.current_interior==MEADOW.ID and player.position.distance_to(Vector2(float(actual.x),float(actual.y)))<78:GameState.confirm_operation(GameState.ranch_fill_trough(home)))
func _unhandled_input(event:InputEvent)->void:
	if GameState.ui_open or GameState.action_busy():return
	if event is InputEventScreenTouch and event.pressed:_click_at(event.position);get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:_click_at(event.position);get_viewport().set_input_as_handled()
func _click_at(screen:Vector2)->void:
	var at:Vector2=get_viewport().get_canvas_transform().affine_inverse()*screen;var closest:Dictionary={};var gap:float=35
	for row:Dictionary in _targets():
		var d:float=at.distance_to(Vector2(float(row.x),float(row.y)))
		if d<gap:gap=d;closest=row
	if closest.is_empty():closest={"id":"meadow-ground","kind":"walk","name":"走到草地","x":at.x,"y":at.y}
	closest.world_click=true;closest.click_room=MEADOW.ID;closest.auto_interact=str(closest.kind)!="walk"
	selected_room_target=closest;selected_world_target=closest;player.walk_to(closest)
