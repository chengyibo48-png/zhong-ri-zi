extends RefCounted
## Soft decoded-RGBA budget. Active scene leases always take priority over eviction.
static var records:Dictionary={}
static var bytes:=0
static var last_trim:=0
static var metrics:Dictionary={"hits":0,"loads":0,"evictions":0,"over_budget":0}
static func budget()->int:
	return (128 if preload("res://scripts/performance_policy.gd").touch_device() else 256)*1024*1024
static func touch(cache:Dictionary,path:String,texture:Texture2D)->void:
	var now:=Time.get_ticks_msec()
	if records.has(path):metrics.hits+=1
	else:
		var size:=texture.get_width()*texture.get_height()*4;records[path]={"bytes":size};bytes+=size;metrics.loads+=1
	records[path].used=now
	var tree:=Engine.get_main_loop() as SceneTree
	if tree!=null:
		var owner:Node=tree.current_scene if is_instance_valid(tree.current_scene) else tree.root
		var lease:Dictionary=owner.get_meta("active_texture_lease",{})
		lease[path]=texture;owner.set_meta("active_texture_lease",lease)
	if bytes>budget() and now-last_trim>1000:trim(cache)
static func trim(cache:Dictionary,limit:int=-1)->void:
	last_trim=Time.get_ticks_msec()
	var target:=budget() if limit<0 else limit
	var keys:=records.keys();keys.sort_custom(func(a:String,b:String):return int(records[a].used)<int(records[b].used))
	for path:String in keys:
		if not cache.has(path):bytes-=int(records[path].bytes);records.erase(path);continue
		if bytes<=target:break
		var resource:Texture2D=cache[path]
		# Dictionary + this local reference are the only permitted owners.
		if resource.get_reference_count()>2:continue
		bytes-=int(records[path].bytes);cache.erase(path);records.erase(path);metrics.evictions+=1
	if bytes>target:metrics.over_budget+=1
static func prefetch(paths:Array[String])->void:
	if OS.has_feature("web"):return
	for path:String in paths:
		if ResourceLoader.exists(path) and not ResourceLoader.has_cached(path):ResourceLoader.load_threaded_request(path,"Texture2D")
