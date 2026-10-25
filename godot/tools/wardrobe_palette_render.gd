extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1
 else:failed+=1;printerr("FAIL: ",label)
func run()->void:
 root.get_node("GameState").set_process(false)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/wardrobe_art_manifest.json"))
 var spec:Dictionary=manifest.packs.apron.parts.down.torso
 var source:=Image.load_from_file(ProjectSettings.globalize_path(str(spec.path)))
 var texture:Texture2D=load(str(spec.path))
 var rig:Script=load("res://scripts/painted_wardrobe.gd")
 var viewport:=SubViewport.new();viewport.size=Vector2i(128,128);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var node:=Sprite2D.new();node.texture=texture;node.centered=false;node.modulate=Color(.3,1,1,1);node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;viewport.add_child(node)
 var palette:=ShaderMaterial.new();palette.shader=load("res://art/characters/player/wardrobe_palette.gdshader");node.material=palette
 var samples:=0
 for shirt in rig.SHIRTS:
  for skin in rig.SKINS:
   palette.set_shader_parameter("shirt_color",Color(shirt));palette.set_shader_parameter("skin_color",Color(skin))
   for i in range(3):await process_frame
   await RenderingServer.frame_post_draw
   var actual:=viewport.get_texture().get_image()
   var cream:=0;var green:=0
   for y in range(30,128):
    for x in range(128):
     var before:=source.get_pixel(x,y)
     if before.a<.99:continue
     if before.r>.7 and before.g>.6 and before.b>.4 and before.r>before.g*1.04 and before.g>before.b*1.04:
      var after:=actual.get_pixel(x,y)
      check(absf(after.r-before.r)<.016 and absf(after.g-before.g)<.016 and absf(after.b-before.b)<.016,"Cream apron remains original painted color across shirt and skin choices")
      cream+=1
     if before.g>before.b*1.11 and before.r<before.g*1.03 and before.g>before.r*.97 and before.g>.15:green+=1
   check(cream>100,"Actual apron contains independently preserved cream paint")
   check(green>100,"Actual apron contains separately selectable sage shirt paint")
   samples+=1
 check(samples==12,"Four shirt and three skin palettes")
 var regression:=Shader.new()
 regression.code=palette.shader.code.replace("rgb.r<rgb.g*1.03 && rgb.g>rgb.r*.97","rgb.r<rgb.g*1.16 && rgb.g>rgb.r*.92").replace("||((part_kind>.25 && part_kind<.35) && UV.y<.22);","||(part_kind>.25 && part_kind<.35);")
 palette.shader=regression;palette.set_shader_parameter("shirt_color",Color(rig.SHIRTS[1]));palette.set_shader_parameter("skin_color",Color(rig.SKINS[2]))
 for i in range(3):await process_frame
 await RenderingServer.frame_post_draw
 var rejected:=viewport.get_texture().get_image();var changed:=0
 for y in range(30,128):
  for x in range(128):
   var before:=source.get_pixel(x,y);var after:=rejected.get_pixel(x,y)
   if before.a>.99 and before.r>.7 and before.g>.6 and before.b>.4 and before.r>before.g*1.04 and before.g>before.b*1.04 and (absf(after.r-before.r)>.016 or absf(after.g-before.g)>.016 or absf(after.b-before.b)>.016):changed+=1
 check(changed>100,"Regression probe reproduces cream recoloring with the former broad masks")
 viewport.queue_free();await process_frame
 print("WARDROBE_PALETTE_RENDER: ",passed," passed, ",failed," failed; 12 actual GPU palette combinations")
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
