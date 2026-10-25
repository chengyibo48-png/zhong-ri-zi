extends "res://scripts/ui_art_service.gd"
var profile_us := 0
var profile_calls := 0
func _apply_control(control: Control, theme_key: String) -> void:
 if not is_instance_valid(control) or not control.is_inside_tree():return
 var started := Time.get_ticks_usec()
 var mode := OS.get_environment("THEME_TIMING_MODE")
 var bulk: bool=mode.ends_with("bulk") and control.has_method("begin_bulk_theme_override")
 if bulk:control.begin_bulk_theme_override()
 super._apply_control(control,theme_key)
 if bulk:control.end_bulk_theme_override()
 profile_us += Time.get_ticks_usec()-started
 profile_calls += 1
func _on_node_added(node: Node) -> void:
 if not OS.get_environment("THEME_TIMING_MODE").begins_with("immediate"):super._on_node_added(node);return
 if not node is Control:return
 var parent := node.get_parent()
 while parent!=null:
  if parent.is_in_group("ui_art_root"):
   node.theme=shared_theme
   call_deferred("_apply_pending_control",weakref(node))
   return
  parent=parent.get_parent()
