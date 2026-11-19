extends SceneTree
class AnimalCanvas extends Node2D:
	var animal:Dictionary={}
	var appearance:Dictionary={}
	var clock:float=0
	var painted:=false
	func _draw()->void:painted=load("res://scripts/animal_layers.gd").draw(self,animal,appearance,Vector2.ZERO,clock)
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
	if ok:passed+=1
	else:failed+=1;printerr("FAIL "+text)
func run()->void:
	var s:Node=root.get_node("GameState");s.set_process(false);root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
	var out:String=OS.get_environment("ZRZ_ART_OUTPUT")+"/animals-v2";DirAccess.make_dir_recursive_absolute(out)
	var layer:=CanvasLayer.new();root.add_child(layer);var paper:=ColorRect.new();paper.color=Color("ded5b9");paper.size=Vector2(1280,800);layer.add_child(paper)
	var nodes:Array=[]
	for row:int in 4:
		for col:int in 4:
			var node:=AnimalCanvas.new();node.position=Vector2(160+col*320,180+row*195);layer.add_child(node);nodes.append(node)
	for species:String in load("res://scripts/animal_layers.gd").data():
		for young:bool in ([false] if species in ["cat","dog"] else [false,true]):
			for i:int in nodes.size():
				var node:AnimalCanvas=nodes[i];var direction:String=["down","left","right","up"][i/4];var action:String=["idle","walk","feed","sleep"][i%4];var id:String=species+str(young)+str(i)
				node.animal={"id":id,"type":species,"age":0 if young else 30};node.appearance={"direction":direction,"young":young,"walking":action=="walk","eating":action=="feed","sleepy":action=="sleep"};node.clock=2.5
				node.scale=Vector2.ONE*minf(4.2,160.0/float(load("res://scripts/animal_species.gd").profile(species).height))
				s.animal_behavior.samples[id]={"direction":direction,"phase":.22,"weight":1 if action=="walk" else 0,"action":action,"sleep":1 if action=="sleep" else 0,"seed":i*17,"turn":1}
				node.queue_redraw()
			for frame:int in 4:await process_frame
			RenderingServer.force_draw()
			for node:AnimalCanvas in nodes:
				check(node.painted,"four views and actions "+species)
				var rig:Dictionary=load("res://scripts/animal_layers.gd").rig_samples.get(str(node.animal.id),{})
				for bone:Dictionary in rig.get("joints",[]):
					check(absf(Vector3(bone.root3d).distance_to(Vector3(bone.joint3d))-float(bone.upper))<.01,"fixed upper bone length "+species)
					check(absf(Vector3(bone.joint3d).distance_to(Vector3(bone.foot3d))-float(bone.lower))<.01,"fixed lower bone length "+species)
			check(root.get_texture().get_image().save_png(out+"/"+species+("-young" if young else "-adult")+".png")==OK,"GPU page")
	print("ANIMAL_DEPTH_GPU: %d passed, %d failed"%[passed,failed]);await root.get_node("AudioService").prepare_exit();quit(1 if failed else 0)
