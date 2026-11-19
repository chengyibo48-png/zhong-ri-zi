extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	await process_frame
	var model:Script=preload("res://scripts/animal_whole_model.gd")
	var output:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/animal_meshes";DirAccess.make_dir_recursive_absolute(output)
	var count:int=0;var failures:Array=[]
	for species:String in model.data():
		var entry:Dictionary=model.data()[species]
		for key:String in entry.frames:
			var mesh:ArrayMesh=model._mesh(entry,entry.frames[key],1.0,"bake/"+species+"/"+key)
			var path:String=output+"/"+species+"-"+key.replace(":","-")+".res"
			if ResourceSaver.save(mesh,path)!=OK:failures.append(path)
			count+=1
	print("BAKED ",count," exact source meshes / failures ",failures);quit(0 if failures.is_empty() else 1)
