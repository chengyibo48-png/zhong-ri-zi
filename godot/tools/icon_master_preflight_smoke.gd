extends SceneTree
const IMPORTER=preload("res://tools/import_handpainted_icons.gd")
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func run() -> void:
 var temp := OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var good := Image.create(128,128,false,Image.FORMAT_RGBA8)
 good.fill_rect(Rect2i(32,32,64,64),Color("688943"))
 check(IMPORTER.source_error(good)=="","accept complete transparent icon")
 for edge in [Vector2i(0,64),Vector2i(127,64),Vector2i(64,0),Vector2i(64,127)]:
  var cut := good.get_region(Rect2i(Vector2i.ZERO,good.get_size()))
  cut.set_pixelv(edge,Color.RED)
  check(IMPORTER.source_error(cut)=="Clipped illustration at master edge","reject subject touching edge with all four corners transparent")
 var opaque := good.get_region(Rect2i(Vector2i.ZERO,good.get_size()));opaque.fill(Color.GREEN)
 check(IMPORTER.source_error(opaque)=="Missing transparent alpha","reject opaque background")
 var corner := good.get_region(Rect2i(Vector2i.ZERO,good.get_size()));corner.set_pixel(0,0,Color.RED)
 check(IMPORTER.source_error(corner)=="Opaque master corner","reject background corner")
 var blank := Image.create(128,128,false,Image.FORMAT_RGBA8)
 check(IMPORTER.source_error(blank)=="Empty illustration master","reject blank image")
 var nonsquare := good.get_region(Rect2i(0,0,64,128))
 check(IMPORTER.source_error(nonsquare)=="Non-square inventory master","reject non-square")
 var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/item_art_manifest.json"))
 var verified := 0
 for key in manifest.entries:
  if str(manifest.entries[key].get("status","missing"))!="ready":continue
  var image := Image.load_from_file(ProjectSettings.globalize_path(IMPORTER.master_path(str(key))))
  check(IMPORTER.source_error(image)=="","ready actual master preflight "+str(key))
  verified+=1
 check(verified>0,"inspected actual ready masters")
 print("ICON_MASTER_PREFLIGHT_SMOKE: %d passed, %d failed"%[passed,failed])
 await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
