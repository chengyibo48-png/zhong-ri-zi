extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failed+=1;push_error(label)
func settle() -> void:
 for frame in range(5):await process_frame
func run() -> void:
 create_timer(60).timeout.connect(func():quit(1))
 var temp:=OS.get_environment("TEMP").replace("\\","/").trim_suffix("/")
 if temp=="" or not OS.get_user_data_dir().replace("\\","/").begins_with(temp+"/"):quit(1);return
 var state:=root.get_node("GameState");state.set_process(false)
 var art=load("res://scripts/item_art.gd")
 for key in art.manifest():
  var category:String=str(key).get_slice("/",0)
  var id:String=str(key).get_slice("/",1)
  check(art.key_for(key)==key,"qualified identity "+key)
  check(art.key_for(key,category)==key,"matching category "+key)
  check(art.key_for(id,category)==key,"explicit category "+key)
  check(art.key_for(key,"invalid")=="","mismatching category rejects "+key)
  check(art.texture_for(key)==art.texture_for(id,category),"qualified texture identity "+key)
 check(art.key_for("photo")=="furniture/photo","original bare ID precedence preserved")
 check(art.texture_for("archives/photo")!=art.texture_for("photo"),"historical photograph cannot borrow modern furniture art")
 check(art.key_for("invalid/photo")=="" and art.texture_for("invalid/photo")==null,"unknown category has no guessed illustration")
 state.flags.introDone=true
 change_scene_to_file("res://scenes/main.tscn")
 await settle()
 current_scene.set_process(false);current_scene.player.set_physics_process(false)
 var panel=load("res://scripts/community_panel.gd").new()
 current_scene.hud.add_child(panel)
 state.archives.clear()
 panel.open_panel("archives");await settle()
 var found:=0
 for node in panel.find_children("*","TextureRect",true,false):
  var key:String=str(node.get_meta("item_art_key",""))
  check(not key.begins_with("archives/"),"undiscovered archival illustrations remain hidden")
 for entry in state.content.get("archives",[]):state.archives.append(str(entry.id))
 panel.refresh();await settle()
 for node in panel.find_children("*","TextureRect",true,false):
  var key:String=str(node.get_meta("item_art_key",""))
  if key=="":continue
  found+=1
  check(node.texture==art.texture_for(key),"card actually binds correct independent illustration "+key)
 check(found>=9,"six archive and three ready achievement cards display illustrations")
 panel.close();panel.queue_free();await settle()
 print("ICON_CATEGORY_SMOKE: ",passed," passed, ",failed," failed")
 await root.get_node("AudioService").prepare_exit()
 quit(1 if failed else 0)
