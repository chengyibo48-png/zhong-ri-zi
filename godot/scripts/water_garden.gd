extends Node2D
## Decorative water ecology, reused canopy reflections and bounded shader clocks.
const GEO:=preload("res://scripts/water_geometry.gd")
const ART:=preload("res://scripts/world_art.gd")
const TEXTURES:=preload("res://scripts/character_art.gd")
const SEASONS: Array[String]=["spring","summer","autumn","winter"]
const MAX_REFLECTIONS:=64
class Reflection extends Node2D:
	var texture: Texture2D
	var rectangle:=Rect2()
	func _draw() -> void:
		if texture==null or not rectangle.has_area():return
		var r:=rectangle
		draw_polygon(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]),PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]),texture)

var ground: TileMapLayer
var columns: Dictionary={}
var plants: Array[Dictionary]=[]
var reflection_rows: Array[Dictionary]=[]
var reflection_material: ShaderMaterial
var exclusions: Array[Vector2]=[]
var clock:=0.0
var elapsed:=0.0
var animated:=false
var season:=-1
var cell_texture_id:=0
var environment_stamp:=""
var world: Dictionary={}

func configure(layer: TileMapLayer, source: Dictionary) -> void:
	name="WaterGarden";z_index=-9;ground=layer;world=source
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	columns=ground.get_meta("visual_columns",{})
	var fishing: Dictionary=GameState.system_catalog.get("fishing",{})
	for spot: Dictionary in fishing.get("spots",[]):
		exclusions.append(Vector2(float(spot.waterX),float(spot.waterY)))
		for landing: Dictionary in spot.get("landings",[]):exclusions.append(Vector2(float(landing.x),float(landing.y)))
	for slot: Dictionary in fishing.get("trapSlots",[]):exclusions.append(Vector2(float(slot.waterX),float(slot.waterY)))
	plants=GEO.plant_layout(source,columns,exclusions)
	reflection_material=ShaderMaterial.new();reflection_material.shader=preload("res://art/shaders/water_reflection.gdshader")
	var scenery:=preload("res://scripts/world_layout.gd").ambience_world(source)
	for data: Dictionary in scenery.get("village",{}).get("allProps",[]):
		var kind:=str(data.get("kind",""))
		if kind not in ["tree","willow","bamboo","blossom","orchard"] or reflection_rows.size()>=MAX_REFLECTIONS:continue
		var row: Dictionary=ART.entries().get("props/"+kind,{})
		var texture: Texture2D=TEXTURES.texture(str(row.get("path","")))
		if texture==null:continue
		var rect: Array=ART.prop_rectangle(data,row,Vector2(texture.get_size()))
		if rect.size()!=4:continue
		var mirrored:=GEO.reflected_box(Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])))
		var at:=Vector2(float(data.get("x",0)),float(data.get("y",0)))
		var touches:=false
		for y: int in range(5):
			for x: int in range(5):
				if GEO.is_water(columns,at+mirrored.position+mirrored.size*Vector2((x+.5)/5.0,(y+.5)/5.0)):touches=true
		if not touches:continue
		var visual:=Reflection.new();visual.position=at;visual.material=reflection_material;visual.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;visual.show_behind_parent=true
		add_child(visual);reflection_rows.append({"data":data,"row":row,"node":visual})
	GameState.world_changed.connect(refresh)
	GameState.clock_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if ground==null or reflection_material==null:return
	var cells: Texture2D=ground.get_meta("visual_cell_texture")
	var next_season:=GameState.season_index()
	if cell_texture_id!=cells.get_instance_id():
		cell_texture_id=cells.get_instance_id();columns=ground.get_meta("visual_columns",{})
		reflection_material.set_shader_parameter("water_cells",cells)
		reflection_material.set_shader_parameter("water_depth",ground.get_meta("visual_depth_texture"))
	if next_season!=season:
		season=next_season
		for item: Dictionary in reflection_rows:
			var variants: Array=item.row.get("seasons",[])
			var texture: Texture2D=TEXTURES.texture(str(variants[season]) if variants.size()==4 else str(item.row.get("path","")))
			var rect: Array=ART.prop_rectangle(item.data,item.row,Vector2(texture.get_size()))
			item.node.texture=texture
			item.node.rectangle=GEO.reflected_box(Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])))
			item.node.queue_redraw()
	var night:=ART.night_factor(GameState.minutes)
	reflection_material.set_shader_parameter("night_amount",night)
	var light_mode:=str(GameState.player_settings.get("performance","auto"))=="light"
	for i: int in range(reflection_rows.size()):reflection_rows[i].node.visible=not light_mode or i<12
	queue_redraw()

func _process(delta: float) -> void:
	if ground==null:return
	elapsed+=delta
	if elapsed<1.0/15.0:return
	var step:=elapsed-fmod(elapsed,1.0/15.0)
	elapsed=fmod(elapsed,1.0/15.0)
	animated=preload("res://scripts/life_presentation.gd").animate()
	if animated:clock+=step
	reflection_material.set_shader_parameter("clock",clock)
	reflection_material.set_shader_parameter("motion",1.0 if animated else 0.0)
	ground.material.set_shader_parameter("water_clock",clock)
	ground.material.set_shader_parameter("water_motion",1.0 if animated else 0.0)
	# A deferred refresh observes ground textures replaced by season callbacks.
	var stamp:="%d/%d/%s/%.3f"%[GameState.season_index(),ground.get_meta("visual_cell_texture").get_instance_id(),GameState.player_settings.get("performance","auto"),ART.night_factor(GameState.minutes)]
	if stamp!=environment_stamp:environment_stamp=stamp;refresh()
	if animated:queue_redraw()

func _draw() -> void:
	if season<0:return
	var view:=preload("res://scripts/life_presentation.gd").visible_rect(self,70.0)
	var night:=ART.night_factor(GameState.minutes)
	var tint:=Color.WHITE.lerp(Color(.64,.72,.79),night*.52)
	for plant: Dictionary in plants:
		var at: Vector2=plant.at
		if not view.has_point(at):continue
		var texture: Texture2D=TEXTURES.texture("res://art/world/water-v3/"+str(plant.kind)+"/"+SEASONS[season]+".png")
		if texture==null:continue
		var scale_factor:=.070
		var angle:=sin(clock*.7+float(plant.seed))*.012 if animated else 0.0
		var bob:=Vector2(0,sin(clock*.8+float(plant.seed))*.28) if animated and str(plant.kind)=="lotus" else Vector2.ZERO
		draw_set_transform(at+bob,angle,Vector2.ONE*scale_factor)
		draw_texture_rect(texture,Rect2(-256,-480,512,512),false,tint)
		draw_set_transform(Vector2.ZERO)
