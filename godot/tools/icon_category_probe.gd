extends SceneTree
func _initialize() -> void:
 var art=load("res://scripts/item_art.gd")
 var failed:=0
 for key in ["archives/photo","furniture/photo"]:
  var actual:String=art.key_for(key)
  print("QUALIFIED_ICON ",key," actual=",actual)
  if actual!=key:failed+=1
 print("QUALIFIED_ICON_PROBE: 2 checks, ",failed," failed")
 quit(1 if failed else 0)
