extends Control
var world:Node
var buttons:Array[Button]=[]
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.color=Color(.08,.13,.09,.8);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var paper:=PanelContainer.new();paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);paper.offset_left=38;paper.offset_right=-38;paper.offset_top=35;paper.offset_bottom=-35;add_child(paper)
	var style:=StyleBoxFlat.new();style.bg_color=Color("ede3c8");style.set_content_margin_all(20);style.set_corner_radius_all(10);paper.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16);paper.add_child(column)
	var title:=Label.new();title.text="东坡大牧野 · 八片活动场地";title.add_theme_font_size_override("font_size",24);title.add_theme_color_override("font_color",Color("354b36"));column.add_child(title)
	var details:=Label.new();details.text="可活动围场 2,880,000 平方世界单位，约原两片围场的 11 倍。\n道路相连、分区放牧；选择场地后沿真实通路走近。";details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_theme_color_override("font_color",Color("526047"));column.add_child(details)
	var grid:=GridContainer.new();grid.columns=4;grid.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(grid)
	for i:int in 8:
		var index:int=i;var button:=Button.new();button.text=str(i+1)+" · "+preload("res://scripts/ranch_meadow.gd").NAMES[i];button.custom_minimum_size=Vector2(150,100);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_child(button);buttons.append(button)
		button.pressed.connect(func():close();var p:Vector2=preload("res://scripts/ranch_meadow.gd").pen(index).get_center();world.player.walk_to({"id":"meadow-field-"+str(index),"kind":"walk","name":preload("res://scripts/ranch_meadow.gd").NAMES[index],"x":p.x,"y":p.y,"world_click":true,"click_room":"ranch-meadow","auto_interact":false}))
	var close_button:=Button.new();close_button.text="收好地图 · Esc / B";close_button.custom_minimum_size.y=48;close_button.pressed.connect(close);column.add_child(close_button);hide()
func open_panel()->void:
	show();GameState.ui_open=true
	if not buttons.is_empty():buttons[0].grab_focus()
func close()->void:hide();GameState.ui_open=false
