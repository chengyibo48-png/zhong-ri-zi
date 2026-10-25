extends SceneTree
func _initialize() -> void:
 var list:=ItemList.new()
 for row in list.get_method_list():
  if str(row.name).contains("current") or str(row.name).contains("visible") or str(row.name).contains("scroll") or str(row.name).contains("select"):print(row.name)
 for row in list.get_property_list():
  if str(row.name).contains("current") or str(row.name).contains("scroll"):print("PROPERTY ",row.name)
 list.free();quit()
