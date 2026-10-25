extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var entries: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_art_manifest.json")).entries
	var candidates: Dictionary = {}
	for key: String in entries:
		if not key.begins_with("interiors/"):continue
		var row: Dictionary=entries[key]
		for path: Variant in [row.get("path",""),row.get("states",{}).get("night",""),row.get("roomBase",""),row.get("roomBaseNight","")]:
			if str(path).ends_with(".png"): candidates[str(path)]=true
	var changed: Array[String] = []
	var originals := "res://artifacts/quality-20261014/import-settings-before"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(originals))
	for path: String in candidates:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.detect_alpha() != Image.ALPHA_NONE or image.get_width()<512:continue
		var sidecar := path+".import"
		if not FileAccess.file_exists(sidecar): continue
		var config := ConfigFile.new()
		if config.load(sidecar) != OK:continue
		if not FileAccess.file_exists(originals+"/"+path.get_file()+".import"):config.save(originals+"/"+path.get_file()+".import")
		config.set_value("params","compress/mode",2)
		config.set_value("params","compress/high_quality",false)
		if config.save(sidecar) != OK:push_error("Cannot update import "+path);quit(1);return
		changed.append(path)
	var file := FileAccess.open("res://artifacts/quality-20261014/background-imports.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"changed":changed,"count":changed.size(),"policy":"Baseline S3TC/ETC2 for opaque room backdrops; source PNG and transparent art unchanged."},"\t"));file.close()
	print("BACKGROUND_IMPORTS: "+str(changed.size())+" opaque backdrops configured")
	await root.get_node("AudioService").prepare_exit();quit(0)
