extends SceneTree
## Technical fitting of inspected portrait masters; no repainting.
func _initialize() -> void:
 var freeze_path := "res://artifacts/art-import-frozen-until.txt"
 if FileAccess.file_exists(freeze_path) and Time.get_unix_time_from_system() < float(FileAccess.get_file_as_string(freeze_path)):
  printerr("Frozen regression: character art import deferred"); quit(1); return
 var args:=OS.get_cmdline_user_args()
 if args.size()!=3:printerr("Usage: -- <actor> <emotion> <absolute-master>");quit(1);return
 var manifest_path:="res://data/character_art_manifest.json"
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 if not data is Dictionary:quit(1);return
 var actor:Dictionary=data.get("actors",{}).get(args[0],{})
 var output:String=str(actor.get("portraits",{}).get(args[1],""))
 if output=="":printerr("Unknown actor or emotion");quit(1);return
 var source:=Image.load_from_file(args[2])
 if source==null or source.is_empty() or source.detect_alpha()==Image.ALPHA_NONE:
  printerr("Portrait requires transparent PNG");quit(1);return
 for corner in [Vector2i.ZERO,Vector2i(source.get_width()-1,0),Vector2i(0,source.get_height()-1),source.get_size()-Vector2i.ONE]:
  if source.get_pixelv(corner).a>=0.01:printerr("Opaque portrait corner");quit(1);return
 var ratio:=minf(256.0/source.get_width(),320.0/source.get_height())
 source.resize(maxi(1,roundi(source.get_width()*ratio)),maxi(1,roundi(source.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
 var image:=Image.create(256,320,false,Image.FORMAT_RGBA8)
 image.blit_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),(Vector2i(256,320)-source.get_size())/2)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
 if image.save_png(output)!=OK:quit(1);return
 if not actor.has("portraitReady"):actor.portraitReady={}
 actor.portraitReady[args[1]]=true
 var file:=FileAccess.open(manifest_path,FileAccess.WRITE)
 if file==null:quit(1);return
 file.store_string(JSON.stringify(data,"  ")+"\n");file.close()
 print("PORTRAIT_IMPORTED: ",args[0],"/",args[1],"; actor remains partial")
 quit(0)
