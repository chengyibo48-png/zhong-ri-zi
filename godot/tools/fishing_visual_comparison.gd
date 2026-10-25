extends SceneTree
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i: int in range(7):await process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://artifacts/fishing-overhaul-20261017/"+name+".png")!=OK:quit(1)
func run() -> void:
	create_timer(60,true,false,true).timeout.connect(func():push_error("comparison timeout");quit(1))
	var s: Node=root.get_node("GameState");s.set_process(false);s.ui_open=false;s.current_interior="";s.day=0;s.minutes=480;root.size=Vector2i(1280,800)
	var current_catalog: Dictionary=s.system_catalog.duplicate(true);var current_entries: Dictionary=s.museum_entries.duplicate(true)
	var old_catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/fishing-overhaul-20261017/before/data/systems.json"))
	s.system_catalog=old_catalog;s.museum_entries={}
	for entry: Dictionary in old_catalog.museum.entries:s.museum_entries[str(entry.key)]=entry
	for id: String in ["fish","perch","loach"]:s._museum_record("item:"+id,true,false)
	var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string("res://artifacts/fishing-overhaul-20261017/before/scripts/museum_panel.gd").replace("class_name MuseumPanel","")
	if script.reload()!=OK:quit(1);return
	var layer:=CanvasLayer.new();root.add_child(layer)
	var before: Control=script.new();layer.add_child(before);root.get_node("UIArtService").register_root(before)
	before.open_panel("catalog");before.category_option.select(3);before._category_changed(3);before.selected_key="item:fish";before.refresh();await capture("comparison-knowledge-before")
	before.queue_free();await settle()
	s.system_catalog=current_catalog;s.museum_entries=current_entries
	var after: Control=load("res://scripts/museum_panel.gd").new();layer.add_child(after);root.get_node("UIArtService").register_root(after)
	after.open_panel("catalog");after.category_option.select(3);after._category_changed(3);after.selected_key="item:fish";after.refresh();await capture("comparison-knowledge-after")
	after.close()
	var guide: Control=load("res://scripts/item_catalog_panel.gd").new();layer.add_child(guide);root.get_node("UIArtService").register_root(guide);guide.open_panel();guide._select_item("carp");await capture("comparison-portable-after")
	guide.close()
	for key: String in ["npc:granny","animal:goat","wild:egret"]:
		s._museum_record(key,true,true)
		after.open_panel("catalog",key);await capture("knowledge-detail-"+key.replace(":","-"));after.close()
	print("Visual comparison: original source/data and final source/data rendered on actual GPU")
	await root.get_node("AudioService").prepare_exit();quit()
