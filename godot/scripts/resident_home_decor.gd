extends Node2D
## Authored household detail uses existing painted assets and never adds collision or targets.
var world:Node2D
var owner_id:String=""
func _ready()->void:
	owner_id=str(GameState.interior_house().get("owner",""))
	GameState.clock_changed.connect(queue_redraw)
	GameState.domain_changed.connect(_changed)
func _changed(domain:String)->void:
	if domain in ["relations","progress","world","quests"]:queue_redraw()
func _draw()->void:
	var identity:Dictionary=load("res://scripts/resident_life.gd").profile(owner_id)
	if identity.is_empty():return
	var layout:Dictionary=GameState.system_catalog.interiors.layouts.get("home-"+owner_id,{})
	var night:float=load("res://scripts/world_art.gd").night_factor(GameState.minutes)
	var accent:=Color(str(identity.roomAccent)).lerp(Color("d8c3a2"),.55)
	# Preserve windows, door, all existing furniture footprints and the central walking route.
	var rug:Texture2D=load("res://scripts/character_art.gd").texture("res://art/world/interior_surfaces/bedside-rug-v2.png")
	for row:Dictionary in layout.get("rows",[]):
		if str(identity.floorRug)!="none" and rug!=null and str(row.kind)==str(identity.workStation):
			var width:float=174 if str(identity.floorRug)=="pattern" else 160
			var tint:Color=Color.WHITE.lerp(accent,.30).lerp(Color(.75,.73,.69),night*.25)
			draw_texture_rect(rug,Rect2(float(row.x)-width*.5,float(row.y)-12,width,72 if str(identity.floorRug)=="pattern" else 54),false,tint)
	if owner_id in ["qiao","luo","an","lan"]:
		load("res://scripts/interior_details.gd").draw(self,"herbs",Rect2(620,144,24,48),night)
	set_meta("resident_memorial","")
	var story:Dictionary=GameState.npc_stories.get(owner_id,{})
	var arc:Array=GameState.content.arcs.get(owner_id,[])
	if not arc.is_empty() and int(story.get("step",0))>=arc.size():
		var choices:Array=story.get("choices",[]);var choice:int=int(choices.back()) if not choices.is_empty() else 0
		# Choice changes the keepsake arrangement; neither choice removes a feature or reward.
		var at:=Vector2(330,148) if choice==0 else Vector2(672,148)
		draw_style_box(_frame(accent),Rect2(at,Vector2(30,36)))
		# A handwritten card belongs on the wall; a scaled-down complete workbench does not.
		var title:String=str(arc.back().get("title","留念"))
		draw_string(ThemeDB.fallback_font,at+Vector2(3,10),title.substr(0,4),HORIZONTAL_ALIGNMENT_LEFT,25,6,accent.darkened(.5))
		for line:int in 3:
			draw_line(at+Vector2(4,16+line*5),at+Vector2(25-line*3,16+line*5),accent.darkened(.25),.6)
		set_meta("resident_memorial",str(identity.afterStory));set_meta("resident_memorial_choice",choice)
static func _frame(color:Color)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("e2d0ac");style.border_color=color.darkened(.35);style.set_border_width_all(2);style.set_corner_radius_all(2);return style
