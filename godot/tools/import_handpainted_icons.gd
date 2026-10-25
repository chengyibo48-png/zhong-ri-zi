extends SceneTree
## Structurally fit approved masters; validate the whole batch before writing.
static func master_path(key: String) -> String:
 return "res://artifacts/handpainted-masters/"+(key.get_slice("/",1) if key.begins_with("items/") else key)+".png"
static func source_error(image: Image) -> String:
 if image==null or image.is_empty() or image.detect_alpha()==Image.ALPHA_NONE:return "Missing transparent alpha"
 if image.get_width()!=image.get_height():return "Non-square inventory master"
 if image.get_used_rect().size==Vector2i.ZERO:return "Empty illustration master"
 for corner in [Vector2i.ZERO,Vector2i(image.get_width()-1,0),Vector2i(0,image.get_height()-1),image.get_size()-Vector2i.ONE]:
  if image.get_pixelv(corner).a>=0.01:return "Opaque master corner"
 for x in range(image.get_width()):
  if image.get_pixel(x,0).a>0.125 or image.get_pixel(x,image.get_height()-1).a>0.125:return "Clipped illustration at master edge"
 for y in range(image.get_height()):
  if image.get_pixel(0,y).a>0.125 or image.get_pixel(image.get_width()-1,y).a>0.125:return "Clipped illustration at master edge"
 return ""
func _initialize() -> void:
 var freeze_path:="res://artifacts/art-import-frozen-until.txt"
 if FileAccess.file_exists(freeze_path) and Time.get_unix_time_from_system()<float(FileAccess.get_file_as_string(freeze_path)):
  print("ART_IMPORT_DEFERRED: regression is checking a frozen asset set");quit(0);return
 var manifest_path := "res://data/item_art_manifest.json"
 var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 if not value is Dictionary:quit(1);return
 var approved_keys := OS.get_cmdline_user_args()
 for approved in approved_keys:
  if not value.entries.has(approved):printerr("Unknown approved icon key: "+approved);quit(1);return
  if not FileAccess.file_exists(master_path(approved)):printerr("Missing approved icon original: "+approved);quit(1);return
 var packed: Dictionary = {}
 for key in value.entries:
  if not approved_keys.is_empty() and str(key) not in approved_keys:continue
  var master := master_path(str(key))
  if not FileAccess.file_exists(master):continue
  var image := Image.load_from_file(ProjectSettings.globalize_path(master))
  var reason := source_error(image)
  if reason!="":printerr(reason+": "+str(key));quit(1);return
  # Existing 120px fitting and 4px transparent gutter remain pixel-identical.
  image.resize(120,120,Image.INTERPOLATE_LANCZOS)
  var icon := Image.create(128,128,false,Image.FORMAT_RGBA8)
  icon.blit_rect(image,Rect2i(0,0,120,120),Vector2i(4,4))
  packed[key]=icon
 for key in packed:
  var output: String = str(value.entries[key].path)
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
  if packed[key].save_png(output)!=OK:quit(1);return
  value.entries[key].status="ready"
 var file := FileAccess.open(manifest_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(value,"  ")+"\n");file.close()
 print("Hand-painted inventory icons imported: ",packed.size())
 quit(0)
