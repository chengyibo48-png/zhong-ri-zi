extends Node2D
const VISUAL := preload("res://scripts/ranch_visual.gd")
var animal_index := 0
var animal_id:String=""
func _ready()->void:
	if animal_id=="" and animal_index>=0 and animal_index<GameState.animals.size():animal_id=str(GameState.animals[animal_index].id)
var inside_room := ""
var painted_active := false
var visual_stamp:int=-1
func request_visual_update()->void:
	if not is_inside_tree():return
	var sample:Dictionary=GameState.animal_behavior.samples.get(animal_id,{})
	var hz:int=24 if float(sample.get("weight",0))>.01 or str(sample.get("action","idle"))!="idle" else 6
	var screen:Vector2=get_global_transform_with_canvas().origin
	if not get_viewport_rect().grow(120).has_point(screen):hz=2
	var stamp:int=floori(GameState.ranch_actor_clock*hz)
	if visual_stamp==stamp:return
	visual_stamp=stamp;queue_redraw()
func _draw() -> void:
	painted_active = false
	if animal_id!="":animal_index=GameState.ranch_animal_index(animal_id)
	if animal_index<0 or animal_index>=GameState.animals.size(): return
	var a: Dictionary = GameState.animals[animal_index]
	painted_active = VISUAL.animal(self,a,Vector2.ZERO,GameState.system_catalog.get("ranch",{}),GameState.ranch_actor_clock,GameState.ranch_actor_poses.get(str(a.id),{}))
	VISUAL.action(self,a,Vector2.ZERO,GameState.ranch_actor_action,inside_room,GameState.ranch_actor_clock,Vector2(float(a.position.x),float(a.position.y)))
	if (animal_index == FarmWorld.hovered_animal if inside_room=="" else str(get_parent().get("selected_room_target").get("id",""))==str(a.id)):
		draw_string(ThemeDB.fallback_font,Vector2(-36,17),str(a.name),HORIZONTAL_ALIGNMENT_CENTER,72,11,Color("#fff0d2"))
		draw_string(ThemeDB.fallback_font,Vector2(-46,29),"饱%d 心%d 健%d" % [int(a.hunger),int(a.mood),int(a.health)],HORIZONTAL_ALIGNMENT_CENTER,92,9,Color("#e5d5ad"))

func _exit_tree()->void:
	preload("res://scripts/animal_whole_model.gd").release_actor(get_instance_id())
