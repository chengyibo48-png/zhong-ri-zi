extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else: failed += 1; if failed <= 12: push_error(label)
func luminance(color: Color) -> float:
 var channels: Array[float] = []
 for value in [color.r,color.g,color.b]:
  channels.append(value/12.92 if value <= 0.04045 else pow((value+0.055)/1.055,2.4))
 return channels[0]*0.2126+channels[1]*0.7152+channels[2]*0.0722
func contrast(ink: Color, background: Color) -> float:
 var a := luminance(ink)
 var b := luminance(background)
 return (maxf(a,b)+0.05)/(minf(a,b)+0.05)
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp == "" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"): quit(1);return
 var state := root.get_node("GameState")
 state.set_process(false)
 var service := root.get_node("UIArtService")
 var container := Control.new()
 root.add_child(container)
 service.register_root(container)
 var prompt = load("res://scripts/interaction_prompt.gd").new()
 prompt.set_process(false)
 container.add_child(prompt)
 await settle()
 for high_contrast in [false,true]:
  state.player_settings.contrast=high_contrast
  for theme_key in ["paper","porcelain","timber"]:
   state.ui_art.theme=theme_key
   state.changed.emit()
   var shared: Theme=service.shared_theme
   var revision: int=service.theme_revision
   for update in range(4):
    var ready: bool=update%2==0
    var info: Dictionary={"verb":"播种" if ready else "浇水","name":"七号田 · 韭菜 "+str(update),"ready":ready,"state":"可以操作","reason":"" if ready else "水壶需要补水","detail":"水分 20 · 肥力 80"}
    prompt.update_content(info,"E" if update<2 else "点按",Vector2(300,240),Vector2(1280,800))
    await settle()
    check(prompt.size.y>=prompt.get_combined_minimum_size().y and prompt.size.y<180,"first content update fits its actual text height")
    # Content update must be readable immediately, without a whole-root refresh.
    var style: StyleBox=prompt.get_theme_stylebox("panel")
    var palette: Dictionary=service._effective_palette(theme_key)
    check(root.get_node("UIArtService").style_background(style).is_equal_approx(Color(str(palette.panel),root.get_node("UIArtService").style_background(style).a)),"dynamic panel follows "+theme_key+"/"+str(high_contrast)+"/"+str(update))
    for label in [prompt.heading,prompt.input_label,prompt.description]:
     var ink: Color=label.get_theme_color("font_color")
     check(ink==Color(str(palette.ink)),"dynamic label follows current palette")
     check(contrast(ink,root.get_node("UIArtService").style_background(style))>=4.5,"legible dynamic interaction text "+theme_key+"/"+str(high_contrast))
    check(style.content_margin_left==7 and style.content_margin_top==4,"current compact prompt geometry preserved")
    check(prompt.available==ready and prompt.input_label.text==("E" if update<2 else "点按"),"availability and device feedback preserved")
    check(service.shared_theme==shared and service.theme_revision==revision,"content change reuses theme")
    var existing: StyleBox=prompt.get_theme_stylebox("panel")
    prompt.update_content(info,"E" if update<2 else "点按",Vector2(300,240),Vector2(1280,800))
    check(prompt.get_theme_stylebox("panel")==existing,"unchanged content reuses panel style")
 container.queue_free()
 await settle()
 await root.get_node("AudioService").prepare_exit()
 print("INTERACTION_THEME_SMOKE: %d passed, %d failed"%[passed,failed])
 quit(1 if failed else 0)
