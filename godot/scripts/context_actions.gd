extends Control
const RULES=preload("res://scripts/context_action_rules.gd")
const DESCRIBE=preload("res://scripts/interaction_description.gd")
var rows:HFlowContainer
var progress_label:Label
var last_buttons:Array=[]
var buttons:Array[Button]=[]
func _ready()->void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 rows=HFlowContainer.new()
 rows.alignment=FlowContainer.ALIGNMENT_CENTER
 rows.mouse_filter=Control.MOUSE_FILTER_IGNORE
 rows.add_theme_constant_override("h_separation",6)
 rows.add_theme_constant_override("v_separation",6)
 add_child(rows)
 rows.resized.connect(_place_rows)
 get_viewport().size_changed.connect(_place_rows)
 progress_label=Label.new()
 progress_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 progress_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 add_child(progress_label)
func home_of(npc_id:String)->String:
 for house in GameState.world_village.get("houses",[]):
  if str(house.get("owner",""))==npc_id:return str(house.get("id",""))
 return ""
func refresh_world()->void:
 var world:Node=get_parent().get_parent()
 var outdoor:bool=world.has_method("_world_target_candidates")
 var selected:Variant=world.get("selected_world_target" if outdoor else "selected_room_target")
 if not selected is Dictionary:hide();return
 var near:Dictionary=selected
 var player:Node=world.get("player")
 if not is_instance_valid(player):hide();return
 var path:Array=player.walk_source_path.duplicate()
 if path.is_empty():
  for i in range(player.walk_index,player.walk_path.size()):path.append({"x":player.walk_path[i].x,"y":player.walk_path[i].y})
 var info:Dictionary=DESCRIBE.describe(GameState,near,GameState.selected_tool) if not near.is_empty() else {}
 var model:Dictionary=RULES.describe(near,str(info.get("verb","")),home_of(str(near.get("id",""))),GameState.current_interior,GameState.riding,not path.is_empty(),world.interaction_selection.options.size(),"touch" if preload("res://scripts/input_hints.gd").touch() else GameState.source_input_mode,GameState.ui_open,GameState.action_busy())
 visible=not model.hidden
 if not visible:return
 if last_buttons!=model.buttons:
  last_buttons=model.buttons.duplicate(true)
  for button in buttons:button.hide();button.queue_free()
  buttons.clear()
  for row in model.buttons:
   var button:=Button.new()
   button.set_meta("compact_hud",true)
   button.text=str(row.label)
   button.add_theme_font_size_override("font_size",18 if preload("res://scripts/performance_policy.gd").touch_device() else 11)
   button.pressed.connect(activate.bind(row.duplicate(true),near.duplicate(true)))
   rows.add_child(button)
   buttons.append(button)
 progress_label.text=RULES.progress(GameState,{"x":player.global_position.x,"y":player.global_position.y},path,str(GameState.walking_target.get("name","")),GameState.riding,player.walk_is_exit)
 progress_label.visible=not progress_label.text.is_empty()
 _place_rows()
 call_deferred("_place_rows")
func _place_rows()->void:
 if not is_inside_tree() or is_queued_for_deletion() or rows == null or progress_label == null:return
 var view:Vector2=get_viewport_rect().size
 var reserve:float=preload("res://scripts/hud_dock.gd").reserve(self)
 rows.size.x=maxf(1,view.x-28)
 rows.position=Vector2(14,maxf(0,view.y-reserve-rows.get_combined_minimum_size().y))
 progress_label.position=Vector2(14,maxf(0,rows.position.y-progress_label.size.y-4))
 progress_label.size.x=maxf(1,view.x-28)
func activate(row:Dictionary,target:Dictionary)->void:
 if GameState.ui_open or GameState.action_busy():return
 var hud:Node=get_parent()
 var world:Node=hud.get_parent()
 match str(row.action):
  "fb-interact":world._interact()
  "fb-cycle":
   if world.has_method("_cycle_world_target"):world._cycle_world_target(1)
   else:world._cycle_room_target(1)
  "f-inspect":hud.show_farm_planner(false,int(row.id))
  "farmcare":hud.show_farm_planner(false,int(hud.farm_planner_panel.plot_box.value)-1)
  "r-open":
   hud.ranch_panel.animal_filter.select(0)
   hud.ranch_panel.selected_animal_id=str(row.id)
   hud.show_ranch()
  "r-task":GameState.queue_ranch_tasks([{"animalId":str(row.id),"action":str(row.op),"arg":str(GameState.ranch.get("feed","feed"))}])
  "fishing":hud.show_fishing()
  "forage":hud.show_forage()
  "v-npc-talk":GameState.queue_npc_task(str(row.id),"talk",{"topic":"auto"})
  "v-npc-gift":hud.show_gifts(str(row.id))
  "v-walk-house":
   var house:Dictionary=GameState.house_data(str(row.id))
   if not house.is_empty():
    var door:Dictionary=house.get("door",{})
    world.player.walk_to({"kind":"enter","id":str(row.id),"house":str(row.id),"name":str(house.get("name","")),"x":door.get("x",0),"y":door.get("y",0)})
  "v-bike":
   var at:Vector2=world.player.global_position
   GameState._interrupt_navigation_for_ui()
   GameState.begin_action(GameState.ACTION_RULES.ui("v-bike",str(row.label)),{"x":at.x,"y":at.y},GameState.toggle_bicycle)
  "v-stop":GameState._interrupt_navigation_for_ui()
